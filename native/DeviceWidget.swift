import SwiftUI
import WidgetKit
import OSLog

struct DeviceWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: TelemetrySnapshot?
    var readIssue: String? = nil
}
struct DeviceWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeviceWidgetEntry { DeviceWidgetEntry(date: .now, snapshot: nil) }
    func currentEntry() -> DeviceWidgetEntry {
        switch TelemetryStore.load() {
        case .success(let snapshot):
            Logger(subsystem: "local.cxy.devices", category: "widget-cache").notice("loaded devices=\(snapshot.devices.count, privacy: .public) cache=\(TelemetryStore.url.path, privacy: .public)")
            return DeviceWidgetEntry(date: .now, snapshot: snapshot)
        case .failure:
            return DeviceWidgetEntry(date: .now, snapshot: nil, readIssue: "缓存暂不可读，打开设备看板查看")
        }
    }
    func getSnapshot(in context: Context, completion: @escaping (DeviceWidgetEntry) -> Void) { completion(currentEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DeviceWidgetEntry>) -> Void) {
        let entry = currentEntry()
        var entries = [entry]
        let samples=(entry.snapshot?.devices ?? []) + [entry.snapshot?.phone,entry.snapshot?.gateway].compactMap { $0 }
        let timestamps=samples.compactMap(\.receivedAt) + samples.compactMap { $0.privateLink?.observedAt } + samples.compactMap { $0.lanLink?.observedAt }
        for expiry in Set(timestamps.map { $0.addingTimeInterval(12.1) }).sorted() where expiry > entry.date {
            entries.append(DeviceWidgetEntry(date: expiry, snapshot: entry.snapshot, readIssue: entry.readIssue))
        }
        completion(Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(300))))
    }
}
enum DeviceCardIdentity: String, CaseIterable {
    case overview, mac, winpc, linux, gateway, phone
    var title: String { ["overview":"设备总览", "mac":"Mac", "winpc":"WinPC", "linux":"Linux", "gateway":"家庭网关", "phone":"手机"][rawValue]! }
    var icon: String { ["overview":"square.grid.2x2", "mac":"laptopcomputer", "winpc":"pc", "linux":"server.rack", "gateway":"network", "phone":"iphone"][rawValue]! }
    var kind: String { self == .overview ? TelemetryStore.kind : "CXYDeviceDashboardOSS." + rawValue }
    var destination: URL { URL(string: "cxy-devices-oss://" + rawValue)! }
}
struct DeviceCardBackground: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        ZStack(alignment: .topTrailing) {
            (scheme == .dark ? Color(red:0.075,green:0.09,blue:0.13) : Color(red:0.96,green:0.96,blue:0.975))
            Ellipse().fill(Color.blue.opacity(scheme == .dark ? 0.13 : 0.065))
                .frame(width:240,height:210).offset(x:100,y:-80).blur(radius:16)
        }
    }
}
struct DeviceWidgetView: View {
    let entry: DeviceWidgetEntry
    var identity: DeviceCardIdentity = .mac
    var previewFamily: WidgetFamily? = nil
    @Environment(\.colorScheme) private var scheme
    private let blue = Color(red:0.02,green:0.46,blue:1)
    private var panel: Color { scheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.86) }
    private var sample: DeviceSample? { identity == .phone ? entry.snapshot?.phone : entry.snapshot?.devices.first { $0.id == identity.rawValue } }
    private var networkSample: DeviceSample? {identity == .gateway ? entry.snapshot?.gateway:sample}
    private var link: DevicePrivateLink? { networkSample?.privateLink }
    private var linux: DeviceSample? { entry.snapshot?.devices.first { $0.id == "linux" } }
    private var fresh: Bool { sample?.fresh(at:entry.date) == true && (identity != .phone || sample?.hardwareFresh != false) }
    private var proxy: ProxySnapshot? { linux?.proxy }
    private var gatewayFresh: Bool { linux?.fresh(at:entry.date) == true && proxy?.sampledAtUnix.map { entry.date.timeIntervalSince1970 - $0 < 18 } == true }
    private var services: [DeviceService] { linux?.services ?? [] }
    private var healthy: Bool { gatewayFresh && ["openwrt-mihomo","openwrt-dnsmasq","openwrt-tailscale"].allSatisfy { n in services.contains { $0.name == n && $0.state == "active" } } }
    private var nodes: [ProxyNode] { (proxy?.nodes ?? []).sorted { $0.selected && !$1.selected } }
    private var stamp: Date? { identity == .gateway ? linux?.receivedAt : sample?.receivedAt }
    private var batteryIcon: String {
        guard let value=sample?.batteryPercent else {return "battery.0percent"}
        if sample?.batteryCharging == true {return "battery.100percent.bolt"}
        return value>=90 ? "battery.100percent" : value>=65 ? "battery.75percent" : value>=40 ? "battery.50percent" : value>=15 ? "battery.25percent":"battery.0percent"
    }
    var body: some View {
        VStack(alignment:.leading,spacing:7) {
            header
            if identity == .gateway { gatewayContent }
            else if identity == .phone {phoneHardwareContent}
            else { deviceContent }
            footer
        }
        .padding(12)
        .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        .widgetURL(identity.destination)
        .containerBackground(for:.widget) { DeviceCardBackground() }
    }
    var header: some View {
        HStack(spacing:6) {
            Image(systemName:identity.icon).font(.system(size:12,weight:.semibold)).foregroundStyle(blue)
                .frame(width:23,height:23).background(blue.opacity(0.09),in:RoundedRectangle(cornerRadius:8))
            Text(identity.title).font(.system(size:13,weight:.bold)).lineLimit(1)
            if identity == .mac,let charge=sample?.batteryPercent {
                HStack(spacing:3) {
                    Image(systemName:batteryIcon)
                    Text(String(format:"%.0f%%",charge)).monospacedDigit()
                    if sample?.onACPower == true {Image(systemName:"powerplug.fill").font(.system(size:7))}
                }.font(.system(size:9,weight:.medium)).foregroundStyle(charge<20 ? Color.orange : Color.secondary)
            }
            Spacer(minLength:3)
            networkChips
        }.frame(height:23)
    }
    private var lanState:String {networkSample?.lanState(at:entry.date) ?? "unknown"}
    private var privatePresentation:DevicePrivatePresentation {link?.presentation(at:entry.date,gatewaySelf:identity == .gateway) ?? .unknown}
    var networkChips:some View {
        HStack(spacing:4) {
            if lanState == "online" {networkChip("局域网直连",color:.blue)}
            networkChip(privatePresentation.label,color:privatePresentation.connected ? .green:.secondary)
        }
    }
    func networkChip(_ label:String,color:Color)->some View {
        HStack(spacing:3) {
            Circle().fill(color).frame(width:4,height:4)
            Text(label).font(.system(size:7.5,weight:.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }.padding(.horizontal,5).padding(.vertical,4).background(color.opacity(0.09),in:Capsule())
    }
    func metric(_ title:String,_ percent:Double?,_ tint:Color) -> some View {
        VStack(alignment:.leading,spacing:2) {
            HStack(spacing:3) {
                Image(systemName:["CPU":"cpu","GPU":"square.stack.3d.up.fill","内存":"memorychip","电量":"battery.75percent","存储":"internaldrive"][title] ?? "gauge.with.dots.needle.33percent")
                    .foregroundStyle(tint).font(.system(size:8))
                Text(title).font(.system(size:8)).foregroundStyle(.secondary)
            }.lineLimit(1).minimumScaleFactor(0.8)
            Text(devicePercent(percent)).font(.system(size:15,weight:.bold,design:.rounded)).monospacedDigit().lineLimit(1)
        }.padding(5).frame(maxWidth:.infinity,alignment:.leading).background(panel,in:RoundedRectangle(cornerRadius:9))
    }
    func bar(_ fraction:Double,tint:Color = .blue) -> some View {
        GeometryReader { g in
            ZStack(alignment:.leading) {
                Capsule().fill(tint.opacity(0.12))
                Capsule().fill(tint).frame(width:g.size.width*min(1,max(0,fraction)))
            }
        }.frame(height:3)
    }
    private var memoryPercent:Double? {
        guard let used=sample?.memoryUsed,let total=sample?.memoryTotal,total>0 else {return nil}
        return used/total*100
    }
    private var phoneStoragePercent:Double? {
        let disks=sample?.disks ?? [];let total=disks.reduce(0) {$0+$1.total}
        return total>0 ? disks.reduce(0) {$0+$1.used}/total*100:nil
    }
    var phoneHardwareContent:some View {
        VStack(alignment:.leading,spacing:6) {
            HStack(spacing:7) {
                metric("电量",sample?.batteryPercent,blue)
                metric("内存",memoryPercent,Color(red:0.52,green:0.57,blue:0.85))
                metric("存储",phoneStoragePercent,Color(red:0.2,green:0.65,blue:0.60))
            }.opacity(fresh ? 1:0.65)
            Text("内存 "+deviceBytes(sample?.memoryUsed)+" / "+deviceBytes(sample?.memoryTotal))
                .font(.system(size:7)).foregroundStyle(.secondary).lineLimit(1)
            let disks=sample?.disks ?? []
            if disks.isEmpty {
                Text("等待手机存储数据").font(.system(size:9)).foregroundStyle(.secondary).frame(maxHeight:.infinity)
            } else {
                LazyVGrid(columns:[GridItem(.flexible(),spacing:9),GridItem(.flexible(),spacing:9)],alignment:.leading,spacing:5) {
                    ForEach(disks) {disk in diskTile(disk)}
                }.opacity(fresh ? 1:0.65).frame(maxHeight:.infinity,alignment:.center)
            }
        }.frame(maxHeight:.infinity,alignment:.top)
    }
    var deviceContent: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack(alignment:.top,spacing:7) {
                VStack(alignment:.leading,spacing:4) {
                    HStack(spacing:4) {
                        metric("CPU",sample?.cpu,blue)
                        metric("GPU",sample?.gpu,Color(red:0.2,green:0.65,blue:0.60))
                        metric("内存",memoryPercent,Color(red:0.52,green:0.57,blue:0.85))
                    }
                    HStack(spacing:3) {
                        Text(deviceBytes(sample?.memoryUsed)+" / "+deviceBytes(sample?.memoryTotal))
                        if let used=sample?.gpuMemoryUsed,let total=sample?.gpuMemoryTotal {Text("· 显存 "+deviceBytes(used)+"/"+deviceBytes(total))}
                    }.font(.system(size:7)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                }.frame(maxWidth:.infinity)
                VStack(alignment:.leading,spacing:5) {
                    speed("↓",fresh ? sample?.download : nil)
                    speed("↑",fresh ? sample?.upload : nil)
                }.padding(.horizontal,8).padding(.vertical,5).frame(width:98).background(panel,in:RoundedRectangle(cornerRadius:10))
            }
            let disks=sample?.disks ?? []
            if disks.isEmpty {
                Text(entry.readIssue ?? "磁盘数据待更新").font(.system(size:9)).foregroundStyle(.secondary).frame(maxHeight:.infinity,alignment:.center)
            } else {
                LazyVGrid(columns:[GridItem(.flexible(),spacing:9),GridItem(.flexible(),spacing:9)],alignment:.leading,spacing:5) {
                    ForEach(disks) { disk in diskTile(disk) }
                }.frame(maxHeight:.infinity,alignment:.center)
            }
        }.frame(maxHeight:.infinity,alignment:.top)
    }
    func speed(_ arrow:String,_ value:Double?) -> some View {
        HStack(alignment:.firstTextBaseline,spacing:3) {
            Text(arrow).foregroundStyle(blue).font(.system(size:10,weight:.semibold))
            Text(value.map {deviceBytes($0)+"/s"} ?? "—").font(.system(size:11,weight:.bold,design:.rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
        }
    }
    func diskTile(_ disk:DeviceDisk) -> some View {
        VStack(alignment:.leading,spacing:3) {
            HStack(spacing:3) {
                Image(systemName:disk.name == "/" || disk.name == "Macintosh HD" || disk.name == "C:" ? "internaldrive" : "externaldrive")
                    .font(.system(size:7)).foregroundStyle(blue)
                Text(disk.name == "/" || disk.name == "Macintosh HD" ? "系统盘" : disk.name == "/mnt/moyue-archive" ? "机械盘" : disk.name)
                    .font(.system(size:8,weight:.medium)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength:1)
                Text(deviceBytes(disk.used)+" / "+deviceBytes(disk.total)).font(.system(size:7.5,design:.rounded)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            }
            bar(disk.fraction,tint:blue.opacity(0.75))
        }
    }
    var serviceChips: some View {
        HStack(spacing:6) {
            ForEach([("openwrt-mihomo","代理"),("openwrt-dnsmasq","DNS"),("openwrt-tailscale","私网")],id:\.0) { key,label in
                HStack(spacing:3) {
                    Circle().fill(gatewayFresh && services.contains { $0.name == key && $0.state == "active" } ? Color.green : Color.orange).frame(width:4,height:4)
                    Label(label,systemImage:["openwrt-mihomo":"network","openwrt-dnsmasq":"globe","openwrt-tailscale":"lock.shield"][key] ?? "network")
                        .font(.system(size:8)).foregroundStyle(.secondary)
                }
            }
        }
    }
    func latency(_ node:ProxyNode)->Double? {
        guard gatewayFresh,node.health == "healthy",let date=node.probeDate,entry.date.timeIntervalSince(date)<75,entry.date.timeIntervalSince(date)>=(-2) else {return nil}
        return node.latencyMs
    }
    var gatewayContent: some View {
        VStack(alignment:.leading,spacing:7) {
            HStack(spacing:5) {
                Text(gatewayFresh ? "当前出口" : "上次出口").font(.system(size:8)).foregroundStyle(.secondary)
                Text(proxy?.selected ?? "等待出口信息").font(.system(size:11,weight:.semibold)).lineLimit(1).truncationMode(.middle)
                Spacer(minLength:2)
                serviceChips
            }
            if nodes.isEmpty {
                Text("节点状态待更新").font(.system(size:10)).foregroundStyle(.secondary).frame(maxHeight:.infinity)
            } else {
                LazyVGrid(columns:[GridItem(.flexible(),spacing:7),GridItem(.flexible(),spacing:7)],spacing:5) {
                    ForEach(Array(nodes.prefix(2))) { node in
                        VStack(alignment:.leading,spacing:5) {
                            HStack(spacing:3) {
                                Image(systemName:"server.rack").font(.system(size:8)).foregroundStyle(blue)
                                Text(node.selected ? "当前" : "备用").font(.system(size:7,weight:.medium)).foregroundStyle(node.selected ? blue : .secondary)
                                Text(node.name).font(.system(size:9,weight:.semibold)).lineLimit(1).truncationMode(.middle)
                            }
                            HStack(alignment:.firstTextBaseline,spacing:3) {
                                Text(latency(node).map {String(format:"%.0f",$0)} ?? "—").font(.system(size:20,weight:.bold,design:.rounded)).foregroundStyle(blue).monospacedDigit()
                                Text("ms").font(.system(size:8)).foregroundStyle(.secondary)
                                Spacer(minLength:0)
                                Circle().fill(latency(node) != nil ? Color.green : Color.orange).frame(width:4,height:4)
                            }
                            Text(node.probeDate.map {"探测 "+$0.formatted(date:.omitted,time:.standard)} ?? "等待探测").font(.system(size:7)).foregroundStyle(.secondary).lineLimit(1)
                        }.padding(9).frame(maxWidth:.infinity,alignment:.leading).background(panel,in:RoundedRectangle(cornerRadius:12))
                    }
                }.frame(maxHeight:.infinity,alignment:.center)
            }
        }.frame(maxHeight:.infinity,alignment:.top)
    }
    var footer:some View {
        HStack(spacing:4) {
            Text(identity == .phone ? (sample?.phoneSamplingLabel(at:entry.date) ?? "等待手机采样") : (stamp.map {"采样 "+$0.formatted(date:.omitted,time:.standard)} ?? "等待采样"))
            if identity != .phone && identity != .gateway && sample?.gpu == nil {Text("· GPU未提供")}
            Spacer(minLength:1)
            Image(systemName:"arrow.up.right").font(.system(size:7))
        }.font(.system(size:7.5)).foregroundStyle(.secondary).lineLimit(1)
    }
}

#if !DEVICE_CARD_PREVIEW
struct MacDeviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:DeviceCardIdentity.mac.kind,provider:DeviceWidgetProvider()) {DeviceWidgetView(entry:$0,identity:.mac)}
            .configurationDisplayName("Mac").description("CPU、GPU、内存、网速与全部磁盘。")
            .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}
struct WindowsDeviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:DeviceCardIdentity.winpc.kind,provider:DeviceWidgetProvider()) {DeviceWidgetView(entry:$0,identity:.winpc)}
            .configurationDisplayName("WinPC").description("CPU、GPU、内存、网速与全部磁盘。")
            .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}
struct LinuxDeviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:DeviceCardIdentity.linux.kind,provider:DeviceWidgetProvider()) {DeviceWidgetView(entry:$0,identity:.linux)}
            .configurationDisplayName("Linux").description("CPU、GPU、内存、网速与全部磁盘。")
            .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}
struct GatewayDeviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:DeviceCardIdentity.gateway.kind,provider:DeviceWidgetProvider()) {DeviceWidgetView(entry:$0,identity:.gateway)}
            .configurationDisplayName("家庭网关").description("当前出口、服务状态与各VPS代理HTTP探测。")
            .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}
struct PhoneDeviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:DeviceCardIdentity.phone.kind,provider:DeviceWidgetProvider()) {DeviceWidgetView(entry:$0,identity:.phone)}
            .configurationDisplayName("手机").description("电量、内存、存储与独立局域网/私网状态，暂停采样时明确保留上次值。")
            .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}
#if DEVICE_WIDGET
@main struct DeviceWidgets: WidgetBundle {
    var body: some Widget {MacDeviceWidget();WindowsDeviceWidget();LinuxDeviceWidget();GatewayDeviceWidget();PhoneDeviceWidget()}
}
#endif
#endif
