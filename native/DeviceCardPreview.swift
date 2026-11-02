// Offline rendering only. Not a member of either installed App target.
import AppKit
import SwiftUI
import WidgetKit

@main enum DeviceCardPreview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {fatalError("Pass output directory")}
        let output=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let now=Date()
        let live:TelemetrySnapshot? = CommandLine.arguments.count == 3 ? try JSONDecoder().decode(TelemetrySnapshot.self,from:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))) : TelemetryStore.read()
        let baseline=live ?? fixture(now:now,stress:false)
        let stress=fixture(now:now,stress:true)
        var cases:[(String,DeviceCardIdentity,WidgetFamily,CGSize,TelemetrySnapshot?,Bool)] = []
        for device in [DeviceCardIdentity.mac,.winpc,.linux,.gateway,.phone] {
            cases.append((device.rawValue+"-medium-live",device,.systemMedium,CGSize(width:360,height:170),baseline,false))
            cases.append((device.rawValue+"-medium-dark",device,.systemMedium,CGSize(width:360,height:170),baseline,true))
        }
        cases += [
            ("winpc-four-disks",.winpc,.systemMedium,CGSize(width:360,height:170),fixture(now:now,stress:false),false),
            ("gateway-long-name-dark",.gateway,.systemMedium,CGSize(width:360,height:170),stress,true),
            ("linux-no-data",.linux,.systemMedium,CGSize(width:360,height:170),nil,false),
            ("gateway-stale",.gateway,.systemMedium,CGSize(width:360,height:170),stale(stress,now:now),false),
            ("phone-offline",.phone,.systemMedium,CGSize(width:360,height:170),withPath(stress,kind:"offline",now:now),false),
            ("phone-relay",.phone,.systemMedium,CGSize(width:360,height:170),withPath(stress,kind:"derp",now:now),false),
            ("mac-relay",.mac,.systemMedium,CGSize(width:360,height:170),withPath(stress,kind:"derp",now:now),false),
            ("phone-idle",.phone,.systemMedium,CGSize(width:360,height:170),withPath(stress,kind:"idle",now:now),true),
            ("phone-hardware-fixture",.phone,.systemMedium,CGSize(width:360,height:170),hardwarePhone(now:now),false),
            ("phone-paused-hardware-fixture",.phone,.systemMedium,CGSize(width:360,height:170),pausedPhone(now:now),false),
            ("phone-hardware-dark-fixture",.phone,.systemMedium,CGSize(width:360,height:170),hardwarePhone(now:now),true),
            ("phone-lan-only-fixture",.phone,.systemMedium,CGSize(width:360,height:170),withStates(hardwarePhone(now:now),lan:"online",privateOnline:false,now:now),false),
            ("mac-private-only-fixture",.mac,.systemMedium,CGSize(width:360,height:170),withStates(fixture(now:now,stress:false),lan:"offline",privateOnline:true,now:now),false)
        ]
        for mode in ["direct4","direct6","relay","offline","unknown","lan-private"] {
            cases.append(("phone-label-"+mode,.phone,.systemMedium,CGSize(width:360,height:170),networkFixture(mode:mode,now:now),false))
        }
        var manifest=[[String:Any]]()
        for (name,identity,family,size,snapshot,dark) in cases {
            let view=DeviceWidgetView(entry:DeviceWidgetEntry(date:now,snapshot:snapshot,readIssue:snapshot == nil ? "缓存暂不可读，打开设备看板查看":nil),identity:identity,previewFamily:family)
            let rendering=view.background(DeviceCardBackground()).environment(\.colorScheme,dark ? .dark:.light).frame(width:size.width,height:size.height)
            let renderer=ImageRenderer(content:rendering);renderer.scale=2
            guard let tiff=renderer.nsImage?.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else {throw CocoaError(.fileWriteUnknown)}
            try png.write(to:output.appendingPathComponent(name+".png"))
            manifest.append(["file":name+".png","kind":identity.kind,"width":size.width,"height":size.height,"dark":dark,"source":snapshot == nil ? "missing-cache fixture" : name.contains("-medium-live") || name.contains("-medium-dark") ? (live == nil ? "synthetic fallback":"live API/cache snapshot") : "synthetic layout fixture"])
        }
        let data=try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys])
        try data.write(to:output.appendingPathComponent("manifest.json"))
        print("Rendered \(cases.count) native SwiftUI previews; no App install or service changes")
    }
    static func networkFixture(mode:String,now:Date)->TelemetrySnapshot {
        var value=hardwarePhone(now:now)
        value.phone?.lanLink=DeviceLANLink(state:mode == "lan-private" ? "online":"unknown",target:"家庭局域网",observedAt:now,source:"synthetic-preview")
        let kind=mode == "relay" ? "derp":mode == "offline" ? "offline":mode == "unknown" ? "idle":"direct"
        value.phone?.privateLink=DevicePrivateLink(kind:kind,target:"家庭网关",observedAt:now,online:mode != "offline",transportVersion:mode == "direct6" ? "IPv6":"IPv4")
        return value
    }
    static func hardwarePhone(now:Date)->TelemetrySnapshot {
        var value=fixture(now:now,stress:false)
        value.phone?.batteryPercent=68;value.phone?.hardwareSampleAvailable=true;value.phone?.hardwareFresh=true
        value.phone?.memoryUsed=7_500_000_000;value.phone?.memoryTotal=12_000_000_000
        value.phone?.disks=[DeviceDisk(name:"内部存储",total:512_000_000_000,used:234_000_000_000)]
        return value
    }
    static func withStates(_ input:TelemetrySnapshot,lan:String,privateOnline:Bool,now:Date)->TelemetrySnapshot {
        var value=input
        for i in value.devices.indices {
            value.devices[i].lanLink=DeviceLANLink(state:lan,target:"家庭局域网",observedAt:now,source:"synthetic-preview")
            value.devices[i].privateLink?.online=privateOnline
            value.devices[i].privateLink?.kind=privateOnline ? "direct":"offline"
        }
        value.phone?.lanLink=DeviceLANLink(state:lan,target:"家庭局域网",observedAt:now,source:"synthetic-preview")
        value.phone?.privateLink?.online=privateOnline
        value.phone?.privateLink?.kind=privateOnline ? "direct":"offline"
        return value
    }
    static func withPath(_ input:TelemetrySnapshot,kind:String,now:Date)->TelemetrySnapshot {
        var result=input
        let online=kind != "offline"
        let link=DevicePrivateLink(kind:kind,target:"家庭网关",observedAt:now,online:online,active:kind == "derp",relay:kind == "derp" ? "hkg":nil,source:"synthetic-preview",tailnetAddress:"100.64.0.4")
        result.phone?.privateLink=link
        if !online {result.phone?.issue="私网离线"}
        for i in result.devices.indices where result.devices[i].id == "mac" {result.devices[i].privateLink=link}
        return result
    }
    static func pausedPhone(now:Date)->TelemetrySnapshot {
        var value=hardwarePhone(now:now);value.phone?.receivedAt=now.addingTimeInterval(-960);value.phone?.hardwareFresh=false;value.phone?.hardwareIssue="采样已暂停"
        return value
    }
    static func stale(_ input:TelemetrySnapshot,now:Date)->TelemetrySnapshot {
        var value=input
        for i in value.devices.indices {value.devices[i].receivedAt=now.addingTimeInterval(-120);value.devices[i].issue="私网服务暂不可达"}
        return value
    }
    static func fixture(now:Date,stress:Bool)->TelemetrySnapshot {
        let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        var nodes=[ProxyNode]()
        for i in 0..<2 {
            let name=stress ? "压力测试用长名称节点-\(i)-跨地区备用出口-名称继续延伸到这里":"示例节点-\(i)"
            let health=i==2 ? "stale":"healthy"
            let latency:Double? = i==2 ? nil:Double(180+i*12)
            let date=formatter.string(from:now.addingTimeInterval(i==2 ? -100:-20))
            nodes.append(ProxyNode(id:"qa-\(i)",name:name,type:"demo",selected:i==0,health:health,latencyMs:latency,latencyKind:"HTTP",probeAt:date,ageSeconds:20))
        }
        let proxy=ProxySnapshot(group:"WAN",groupType:"Fallback",selected:nodes[0].name,nodes:nodes,source:"offline-layout-fixture",sampledAtUnix:now.timeIntervalSince1970,error:nil)
        var samples=[DeviceSample]()
        let disks=[DeviceDisk(name:"系统盘",total:200_000_000_000,used:155_000_000_000),DeviceDisk(name:"长名称数据磁盘-用于压力测试",total:500_000_000_000,used:300_000_000_000)]
        let services=[DeviceService(name:"openwrt-mihomo",state:"active"),DeviceService(name:"openwrt-dnsmasq",state:"active"),DeviceService(name:"openwrt-tailscale",state:"active")]
        for id in ["mac","winpc","linux"] {
            var sample=DeviceSample(id:id,host:"offline-preview")
            sample.cpu=id=="mac" ? 34:78;sample.gpu=id=="linux" ? nil:12
            sample.memoryUsed=12_000_000_000;sample.memoryTotal=16_000_000_000
            sample.download=123_450_000;sample.upload=12_340_000;sample.disks=disks
            if id == "winpc" {
                var pcDisks=[DeviceDisk]()
                for (index,name) in ["C:","D:","E:","F:"].enumerated() {
                    let total=Double(200+index*100)*1_000_000_000.0
                    let used=Double(87+index*23)*1_000_000_000.0
                    pcDisks.append(DeviceDisk(name:name,total:total,used:used))
                }
                sample.disks=pcDisks
            }
            if id=="linux" {sample.services=services;sample.proxy=proxy}
            sample.receivedAt=now;samples.append(sample)
        }
        var phone=DeviceSample(id:"phone",host:"cxy-phone")
        phone.receivedAt=now
        phone.privateLink=DevicePrivateLink(kind:"lan-direct",target:"家庭网关",observedAt:now,online:true,active:true,endpoint:"192.0.2.4:41642",source:"synthetic-preview",transportVersion:"IPv4",tailnetAddress:"100.64.0.4",gatewayRxBytesPerSecond:24000,gatewayTxBytesPerSecond:52000)
        phone.lanLink=DeviceLANLink(state:"online",target:"家庭局域网",observedAt:now,source:"synthetic-preview")
        for index in samples.indices { samples[index].privateLink=phone.privateLink;samples[index].lanLink=phone.lanLink }
        var gateway=DeviceSample(id:"gateway",host:"offline-preview")
        gateway.receivedAt=now;gateway.privateLink=phone.privateLink;gateway.lanLink=phone.lanLink
        return TelemetrySnapshot(generatedAt:now,devices:samples,phone:phone,gateway:gateway)
    }
}
