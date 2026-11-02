import Foundation
import Combine
import Darwin
import IOKit
import IOKit.ps
import WidgetKit

final class MacDeviceSampler {
    var previousCPU: (Double,Double)?
    var previousNetwork: (Double,Double,TimeInterval)?
    func sample() -> DeviceSample {
        var result = DeviceSample(id:"mac",host:Foundation.Host.current().localizedName ?? "Mac")
        if let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources=IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let details=IOPSGetPowerSourceDescription(info,source)?.takeUnretainedValue() as? [String:Any],
                      details[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      let current=details[kIOPSCurrentCapacityKey] as? NSNumber,
                      let maximum=details[kIOPSMaxCapacityKey] as? NSNumber,maximum.doubleValue>0 else {continue}
                result.batteryPercent=max(0,min(100,current.doubleValue/maximum.doubleValue*100))
                result.batteryCharging=details[kIOPSIsChargingKey] as? Bool
                result.onACPower=(details[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
                break
            }
        }
        var cpu = host_cpu_load_info(); var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size/MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to:&cpu) { pointer in pointer.withMemoryRebound(to:integer_t.self,capacity:Int(size)) { host_statistics(mach_host_self(),HOST_CPU_LOAD_INFO,$0,&size) } }
        if status == KERN_SUCCESS {
            let values = withUnsafeBytes(of:cpu.cpu_ticks) { Array($0.bindMemory(to:UInt32.self)).map(Double.init) }
            let total=values.reduce(0,+), idle=values[Int(CPU_STATE_IDLE)]
            if let old=previousCPU, total > old.0 { result.cpu = max(0,min(100,100*(1-(idle-old.1)/(total-old.0)))) }
            previousCPU=(total,idle)
        }
        var memory = vm_statistics64(); var memorySize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size/MemoryLayout<integer_t>.size)
        let memStatus=withUnsafeMutablePointer(to:&memory) { p in p.withMemoryRebound(to:integer_t.self,capacity:Int(memorySize)) { host_statistics64(mach_host_self(),HOST_VM_INFO64,$0,&memorySize) } }
        result.memoryTotal=Double(ProcessInfo.processInfo.physicalMemory)
        if memStatus == KERN_SUCCESS { result.memoryUsed=Double(UInt64(memory.active_count)+UInt64(memory.wire_count)+UInt64(memory.compressor_page_count))*Double(vm_kernel_page_size) }
        var addresses: UnsafeMutablePointer<ifaddrs>?
        var rx=0.0, tx=0.0, names=Set<String>()
        if getifaddrs(&addresses)==0 {
            var next=addresses
            while let pointer=next {
                let entry=pointer.pointee;let name=String(cString:entry.ifa_name)
                if entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), name.hasPrefix("en"), entry.ifa_flags & UInt32(IFF_UP|IFF_RUNNING) == UInt32(IFF_UP|IFF_RUNNING),let raw=entry.ifa_data {
                    let data=raw.assumingMemoryBound(to:if_data.self).pointee
                    rx+=Double(data.ifi_ibytes);tx+=Double(data.ifi_obytes);names.insert(name)
                }
                next=entry.ifa_next
            }
            freeifaddrs(addresses)
            let now=ProcessInfo.processInfo.systemUptime
            if let old=previousNetwork, now>old.2 { result.download=max(0,(rx-old.0)/(now-old.2));result.upload=max(0,(tx-old.1)/(now-old.2)) }
            previousNetwork=(rx,tx,now);result.interfaces=names.sorted().joined(separator:", ")
        }
        let gpu=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("AGXAccelerator"))
        if gpu != 0 {
            if let props=IORegistryEntryCreateCFProperty(gpu,"PerformanceStatistics" as CFString,kCFAllocatorDefault,0)?.takeRetainedValue() as? [String:Any] {
                result.gpu=(props["Device Utilization %"] as? NSNumber)?.doubleValue
            }
            IOObjectRelease(gpu)
        }
        let volumes=FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys:[.volumeIsLocalKey,.volumeIsBrowsableKey,.volumeTotalCapacityKey,.volumeAvailableCapacityKey,.volumeNameKey],options:[.skipHiddenVolumes]) ?? []
        result.disks=volumes.compactMap { url in
            guard url.path=="/" || url.path.hasPrefix("/Volumes/"),let v=try? url.resourceValues(forKeys:[.volumeIsLocalKey,.volumeTotalCapacityKey,.volumeAvailableCapacityKey,.volumeNameKey]),v.volumeIsLocal==true,let total=v.volumeTotalCapacity,let available=v.volumeAvailableCapacity else {return nil}
            return DeviceDisk(name:v.volumeName ?? url.lastPathComponent,total:Double(total),used:Double(total-available))
        }
        result.uptime=ProcessInfo.processInfo.systemUptime;result.receivedAt = .now
        return result
    }
}

final class DeviceMonitor: ObservableObject {
    @Published var samples=["mac","winpc","linux"].map(DeviceSample.waiting)
    @Published var history: [String:[DeviceSample]]=[:]
    @Published var connectionIssue: String?
    @Published var phoneSample: DeviceSample?
    @Published var gatewaySample: DeviceSample?
    let local=MacDeviceSampler()
    let service=WorkbenchClient()
    var timer:Timer?; var sampling=false;var fetching=false
    var lastWidget=Date.distantPast
    var config=DeviceMonitorConfig()
    func start() {
        guard timer==nil else{return}
        config=(try? DeviceMonitorConfig.read()) ?? DeviceMonitorConfig()
        if let saved=TelemetryStore.read() {samples=saved.devices;phoneSample=saved.phone;gatewaySample=saved.gateway}
        tick();timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true){[weak self] _ in self?.tick()}
    }
    func tick() {
        if !sampling {
            sampling=true
            DispatchQueue.global(qos:.utility).async {[weak self] in
                guard let self else{return};let sample=self.local.sample()
                self.service.put("/v1/mac",value:sample,role:.mac){[weak self] _ in
                    DispatchQueue.main.async {self?.sampling=false}
                }
            }
        }
        guard !fetching else{return};fetching=true
        service.get("/v1/telemetry",as:TelemetrySnapshot.self){[weak self] result in
            DispatchQueue.main.async {
                guard let self else{return};self.fetching=false
                switch result {
                case .success(let value):
                    self.connectionIssue=nil
                    self.samples=value.devices
                    self.phoneSample=value.phone
                    self.gatewaySample=value.gateway
                    for sample in value.devices {
                        if self.history[sample.id]?.last?.receivedAt != sample.receivedAt {
                            self.history[sample.id,default:[]].append(sample)
                            if self.history[sample.id]!.count>60 {self.history[sample.id]!.removeFirst()}
                        }
                    }
                    self.save()
                case .failure:
                    self.connectionIssue="私网服务暂不可达，保留上次采样"
                    for i in self.samples.indices {self.samples[i].issue=self.connectionIssue}
                    self.phoneSample?.issue=self.connectionIssue
                    self.gatewaySample?.issue=self.connectionIssue
                    self.save()
                }
            }
        }
    }
    func save() {
        do {try TelemetryStore.write(samples,phone:phoneSample,gateway:gatewaySample)} catch {NSLog("Device cache could not be written")}
        if Date().timeIntervalSince(lastWidget)>=max(5,config.widgetRequestSeconds) {
            lastWidget = .now
            for kind in TelemetryStore.deviceKinds {WidgetCenter.shared.reloadTimelines(ofKind:kind)}
        }
    }
    func stop(){timer?.invalidate();timer=nil}
}
