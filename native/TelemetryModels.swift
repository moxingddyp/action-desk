import Foundation
import Darwin

struct DeviceDisk: Codable, Identifiable {
    var name: String; var total: Double; var used: Double
    var id: String { name }
    var fraction: Double { total > 0 ? min(1,max(0,used/total)) : 0 }
}
struct DeviceService: Codable, Identifiable {
    var name: String; var state: String
    var id: String { name }
    var label: String {
        ["cxy-gateway-links.service":"网关接口", "cxy-uplink-isolation.service":"WAN 隔离", "cxy-openwrt.service":"OpenWrt", "openwrt-mihomo":"代理核心", "openwrt-dnsmasq":"DNS 服务", "openwrt-tailscale":"远程出口"][name] ?? name
    }
}
enum DevicePrivatePresentation:Equatable {
    case direct4,direct6,direct,relay,online,offline,unknown
    var label:String {
        switch self {
        case .direct4:return "私网直连 · IPv4"
        case .direct6:return "私网直连 · IPv6"
        case .direct:return "私网直连"
        case .relay:return "私网中继"
        case .online:return "私网在线"
        case .offline:return "私网未连接"
        case .unknown:return "私网状态未知"
        }
    }
    var connected:Bool {self != .offline && self != .unknown}
}
struct DevicePrivateLink: Codable {
    var kind: String
    var target: String
    var observedAt: Date
    var online: Bool?
    var active: Bool?
    var endpoint: String?
    var relay: String?
    var source: String?
    var transportVersion: String?
    var tailnetAddress: String?
    var gatewayRxBytesPerSecond: Double?
    var gatewayTxBytesPerSecond: Double?
    func current(at date: Date) -> Bool { date.timeIntervalSince(observedAt) >= -2 && date.timeIntervalSince(observedAt) < 12 }
    func label(at date: Date) -> String {
        guard current(at:date) else {return "路径未更新"}
        if online == true && ["idle","unknown"].contains(kind) {return "私网成员在线，当前传输路径未确认"}
        return ["lan-direct":"局域网直连", "direct":"跨网直连", "derp":"中继", "peer-relay":"设备中继", "idle":"空闲待连接", "offline":"未连接", "unknown":"路径未知"][kind] ?? "路径未知"
    }
    func presentation(at date:Date,gatewaySelf:Bool=false)->DevicePrivatePresentation {
        guard current(at:date) else {return .unknown}
        if gatewaySelf {
            guard target == "私网成员",let online else {return .unknown}
            return online ? .online:.offline
        }
        if online == false || kind == "offline" {return .offline}
        guard online == true else {return .unknown}
        switch kind {
        case "lan-direct","direct":
            switch transportVersion?.lowercased() {
            case "ipv4":return .direct4
            case "ipv6":return .direct6
            default:return .direct
            }
        case "derp","peer-relay":return .relay
        default:return .unknown
        }
    }
    var icon: String {
        ["lan-direct":"cable.connector", "direct":"point.3.connected.trianglepath.dotted", "derp":"arrow.triangle.branch", "peer-relay":"arrow.triangle.branch", "idle":"pause.circle", "offline":"wifi.slash"][kind] ?? "questionmark.circle"
    }
    func direct(at date: Date) -> Bool { current(at:date) && online == true && ["lan-direct","direct"].contains(kind) }
}
struct DeviceLANLink: Codable {
    var state: String
    var target: String
    var observedAt: Date
    var source: String?
    var address: String?
    func current(at date:Date)->Bool {date.timeIntervalSince(observedAt)>=(-2) && date.timeIntervalSince(observedAt)<12}
}
struct DeviceSample: Codable, Identifiable {
    var id: String; var host: String
    var cpu: Double?; var gpu: Double?
    var gpuMemoryUsed: Double?; var gpuMemoryTotal: Double?
    var batteryPercent: Double?; var batteryCharging: Bool?; var onACPower: Bool?
    var networkType: String?; var networkObservedAt: Date?
    var hardwareSampleAvailable: Bool?; var hardwareFresh: Bool?; var hardwareIssue:String?
    var memoryUsed: Double?; var memoryTotal: Double?
    var download: Double?; var upload: Double?
    var interfaces: String?; var disks: [DeviceDisk]?
    var services: [DeviceService]?
    var dnsListening: Bool?; var proxyListening: Bool?
    var uptime: Double?; var error: String?
    var proxy: ProxySnapshot?
    var privateLink: DevicePrivateLink?
    var lanLink: DeviceLANLink?
    var receivedAt: Date?; var issue: String?
    var title: String { ["mac":"Mac", "winpc":"WinPC", "linux":"Linux 主机", "phone":"手机"][id] ?? id }
    func fresh(at date: Date = .now) -> Bool { issue == nil && error == nil && receivedAt.map { date.timeIntervalSince($0) < 12 } == true }
    func lanState(at date:Date)->String {
        guard let link=lanLink,link.current(at:date) else {return "unknown"}
        return ["online","offline"].contains(link.state) ? link.state:"unknown"
    }
    func privateState(at date:Date)->String {
        guard let link=privateLink,link.current(at:date),let online=link.online else {return "unknown"}
        return online ? "online":"offline"
    }
    func phoneSamplingLabel(at date:Date)->String {
        guard hardwareSampleAvailable != false,let sampled=receivedAt else {return "等待手机采样"}
        if fresh(at:date) && hardwareFresh != false && hardwareIssue == nil {return "采样 "+sampled.formatted(date:.omitted,time:.standard)}
        return "采样已暂停 · 上次 "+sampled.formatted(date:.omitted,time:.shortened)
    }
    static func waiting(_ id: String) -> DeviceSample { DeviceSample(id:id,host: "",issue:"等待局域网采样") }
}
struct TelemetrySnapshot: Codable { var generatedAt: Date; var devices: [DeviceSample]; var phone: DeviceSample? = nil; var gateway: DeviceSample? = nil }
enum TelemetryStore {
    static let kind = "CXYDeviceDashboardOSS"
    static let deviceKinds=["mac","winpc","linux","phone","gateway"].map {"CXYDeviceDashboardOSS."+$0}
    static let url = DeviceStore.directory.appendingPathComponent("devices.json")
    static func load() -> Result<TelemetrySnapshot,Error> {
        do {
            let data=try Data(contentsOf:url)
            guard data.count<4_000_000 else {throw CocoaError(.fileReadCorruptFile)}
            return .success(try JSONDecoder().decode(TelemetrySnapshot.self,from:data))
        } catch {
            let e=error as NSError
            NSLog("Device telemetry cache read failed: domain=%@ code=%ld path=%@",e.domain,e.code,url.path)
            return .failure(error)
        }
    }
    static func read() -> TelemetrySnapshot? {
        if case .success(let value)=load(){return value};return nil
    }
    static func write(_ devices: [DeviceSample], phone: DeviceSample? = nil, gateway: DeviceSample? = nil) throws {
        try FileManager.default.createDirectory(at: DeviceStore.directory, withIntermediateDirectories:true, attributes:[.posixPermissions:0o700])
        try JSONEncoder().encode(TelemetrySnapshot(generatedAt:.now,devices:devices,phone:phone,gateway:gateway)).write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
}
func deviceBytes(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    let units=["B","KB","MB","GB","TB"];var n=max(0,value);var i=0
    while n>=1024 && i<units.count-1 {n/=1024;i+=1}
    return String(format:i==0 ? "%.0f %@":"%.1f %@",n,units[i])
}
func devicePercent(_ value: Double?) -> String { value.map { String(format:"%.0f%%",max(0,min(100,$0))) } ?? "—" }

struct ProxyNode: Codable, Identifiable {
    var id:String;var name:String;var type:String?;var selected:Bool
    var health:String;var latencyMs:Double?;var latencyKind:String?
    var probeAt:String?;var ageSeconds:Double?
    var probeDate:Date? {
        guard let probeAt else{return nil}
        let formatter=ISO8601DateFormatter();formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        if let date=formatter.date(from:probeAt){return date}
        formatter.formatOptions=[.withInternetDateTime];return formatter.date(from:probeAt)
    }
    var healthLabel:String { ["healthy":"可用","unhealthy":"不可用","stale":"探测已过期","unknown":"待探测"][health] ?? "未知" }
}
struct ProxySnapshot: Codable {
    var group:String?;var groupType:String?;var selected:String?;var nodes:[ProxyNode]
    var source:String?;var sampledAtUnix:Double?;var error:String?
}
struct DeviceDisplayPrefs:Codable {
    var tab="overview";var nodePage=0
    static let tabs=["overview","mac","winpc","linux"]
    static let url=DeviceStore.preferenceDirectory.appendingPathComponent("devices-display.json")
    static func read()->DeviceDisplayPrefs {guard let d=try? Data(contentsOf:url),let p=try? JSONDecoder().decode(Self.self,from:d),tabs.contains(p.tab) else{return Self()};return p}
    static func change(_ action:String,_ value:String)throws {
        try FileManager.default.createDirectory(at:DeviceStore.preferenceDirectory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let fd=Darwin.open(DeviceStore.preferenceDirectory.appendingPathComponent("devices-display.lock").path,O_CREAT|O_RDWR,0o600)
        guard fd>=0 else{throw CocoaError(.fileWriteNoPermission)}
        defer{flock(fd,LOCK_UN);Darwin.close(fd)}
        guard flock(fd,LOCK_EX)==0 else{throw CocoaError(.fileLocking)}
        var p=read()
        if action=="tab",tabs.contains(value){p.tab=value}
        else if action=="page",let n=Int(value),n>=0{p.nodePage=n}
        else{return}
        try JSONEncoder().encode(p).write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
}
struct DeviceMonitorConfig:Codable {
    var schema=1
    var widgetRequestSeconds:Double=5
    static let url=DeviceStore.directory.appendingPathComponent("monitor-config.json")
    static func read()throws->Self {
        if FileManager.default.fileExists(atPath:url.path){return try JSONDecoder().decode(Self.self,from:Data(contentsOf:url))}
        return Self()
    }
}
