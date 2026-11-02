import Foundation
@main enum PrivateLinkChecks {
    static func main() throws {
        let now=Date().timeIntervalSinceReferenceDate
        let data=Data("{\"generatedAt\":\(now),\"devices\":[{\"id\":\"mac\",\"host\":\"mac\",\"privateLink\":{\"kind\":\"unknown\",\"target\":\"家庭网关\",\"observedAt\":\(now)}}],\"phone\":{\"id\":\"phone\",\"host\":\"example-phone\",\"privateLink\":{\"kind\":\"unknown\",\"target\":\"家庭网关\",\"observedAt\":\(now)}}}".utf8)
        let value=try JSONDecoder().decode(TelemetrySnapshot.self,from:data)
        precondition(value.devices.count == 1 && value.phone?.privateLink?.online == nil)
        precondition(value.phone?.privateLink?.label(at:.now) == "路径未知")
        var link=value.phone!.privateLink!
        link.kind="lan-direct";link.online=true
        precondition(link.direct(at:.now))
        link.observedAt=Date().addingTimeInterval(-20)
        precondition(link.label(at:.now) == "路径未更新" && !link.direct(at:.now))
        let withHardware=Data("{\"id\":\"phone\",\"host\":\"phone\",\"hardwareSampleAvailable\":true,\"hardwareFresh\":false,\"receivedAt\":\(now-120),\"batteryPercent\":68,\"memoryUsed\":5000000000,\"memoryTotal\":12000000000,\"networkType\":\"wifi\",\"networkObservedAt\":\(now),\"privateLink\":{\"kind\":\"direct\",\"target\":\"家庭网关\",\"observedAt\":\(now),\"online\":true}}".utf8)
        let hardware=try JSONDecoder().decode(DeviceSample.self,from:withHardware)
        precondition(hardware.hardwareFresh==false && hardware.batteryPercent==68 && hardware.networkType=="wifi")
        precondition(hardware.privateLink?.direct(at:.now)==true,"Old hardware sample must not mark current private link offline")
        var independent=hardware
        independent.lanLink=DeviceLANLink(state:"online",target:"家庭局域网",observedAt:.now,source:"test")
        independent.privateLink?.online=false
        precondition(independent.lanState(at:.now)=="online" && independent.privateState(at:.now)=="offline")
        independent.lanLink?.state="offline";independent.privateLink?.online=true
        precondition(independent.lanState(at:.now)=="offline" && independent.privateState(at:.now)=="online")
        independent.lanLink=nil;independent.networkType="wifi"
        precondition(independent.lanState(at:.now)=="unknown","Wi-Fi alone is not proof of home LAN")
        independent.lanLink=DeviceLANLink(state:"online",target:"家庭局域网",observedAt:Date().addingTimeInterval(-20),source:"test")
        precondition(independent.lanState(at:.now)=="unknown" && independent.privateState(at:.now)=="online")
        independent.privateLink?.kind="unknown"
        precondition(independent.privateState(at:.now)=="online","Gateway membership is independent from a path kind to itself")
        var phone=hardware
        phone.hardwareIssue="采样已暂停"
        precondition(phone.phoneSamplingLabel(at:.now).hasPrefix("采样已暂停 · 上次"))
        precondition(phone.privateState(at:.now)=="online")
        phone.receivedAt=nil
        precondition(phone.phoneSamplingLabel(at:.now)=="等待手机采样")
        phone.receivedAt = .now;phone.hardwareFresh=true;phone.hardwareIssue=nil
        precondition(phone.phoneSamplingLabel(at:.now).hasPrefix("采样 "))
        var presentation=DevicePrivateLink(kind:"direct",target:"家庭网关",observedAt:.now,online:true,transportVersion:"IPv4")
        precondition(presentation.presentation(at:.now) == .direct4)
        presentation.transportVersion="IPv6";precondition(presentation.presentation(at:.now) == .direct6)
        presentation.kind="lan-direct";precondition(presentation.presentation(at:.now) == .direct6)
        for kind in ["derp","peer-relay"] {presentation.kind=kind;precondition(presentation.presentation(at:.now) == .relay)}
        for kind in ["idle","unknown"] {presentation.kind=kind;precondition(presentation.presentation(at:.now) == .unknown)}
        presentation.kind="direct";presentation.online=false;precondition(presentation.presentation(at:.now) == .offline)
        presentation.online=true;presentation.kind="offline";precondition(presentation.presentation(at:.now) == .offline)
        presentation.kind="direct";presentation.observedAt=Date().addingTimeInterval(-20);precondition(presentation.presentation(at:.now) == .unknown)
        var gateway=DevicePrivateLink(kind:"unknown",target:"私网成员",observedAt:.now,online:true)
        precondition(gateway.presentation(at:.now,gatewaySelf:true) == .online)
        precondition(gateway.presentation(at:.now) == .unknown,"Peer control membership is not proof of a direct path")
        gateway.kind="direct";gateway.transportVersion="IPv4"
        precondition(gateway.presentation(at:.now,gatewaySelf:true) == .online,"A gateway cannot have a direct path to itself")
        gateway.online=false;precondition(gateway.presentation(at:.now,gatewaySelf:true) == .offline)
        gateway.online=true;gateway.observedAt=Date().addingTimeInterval(-20)
        precondition(gateway.presentation(at:.now,gatewaySelf:true) == .unknown)
        print("PASS: gateway own membership online/offline/expiry without fabricated self path; peers still require actual path")
        print("PASS: direct IPv4/IPv6, both relay types, explicit offline, no-path and expired evidence labels")
        print("PASS: missing optional online/active do not discard telemetry; path unknown and expiry remain distinct; optional phone hardware and network decoded independently; LAN/private states and expiry independent")
    }
}
