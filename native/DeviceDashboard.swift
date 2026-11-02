import SwiftUI
import AppKit

private let boardBlue=WorkbenchStyle.accent
private let boardBase=WorkbenchStyle.base
private let boardInk=Color.primary
struct DeviceSparkline: View {
    var values:[Double];var color:Color=boardBlue
    var body: some View {
        GeometryReader { proxy in
            let maxValue=max(values.max() ?? 0,1)
            Path { p in
                for (i,value) in values.enumerated() {
                    let point=CGPoint(x:proxy.size.width*Double(i)/Double(max(1,values.count-1)),y:proxy.size.height*(1-min(1,max(0,value/maxValue))))
                    if i==0 {p.move(to:point)} else {p.addLine(to:point)}
                }
            }.stroke(color,style:StrokeStyle(lineWidth:2,lineCap:.round,lineJoin:.round))
        }.frame(height:35)
    }
}
struct DeviceCard<Content:View>: View {
    var title:String;var icon:String;@ViewBuilder var content:Content
    var body: some View {
        VStack(alignment:.leading,spacing:17) {
            Label(title,systemImage:icon).font(.system(size:12,weight:.medium)).foregroundStyle(.secondary)
            content
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
        .background(WorkbenchStyle.card,in:RoundedRectangle(cornerRadius:16))
    }
}
struct DeviceDashboard: View {
    @ObservedObject var monitor:DeviceMonitor
    @State var selection="all"
    var primary:DeviceSample { monitor.samples.first{$0.id==(selection=="all" ? "mac":selection=="network" ? "linux":selection)} ?? .waiting("mac") }
    var body:some View {
        TimelineView(.periodic(from:.now,by:1)) { context in
            HStack(spacing:0) {
                sidebar
                ScrollView {
                    if selection == "phone" { phoneDetail.padding(26) } else {
                    VStack(alignment:.leading,spacing:18) {
                        header(at:context.date)
                        HStack(alignment:.top,spacing:16) {
                            hero(at:context.date).frame(maxWidth:.infinity)
                            speedCard(upload:true).frame(width:190)
                            speedCard(upload:false).frame(width:190)
                        }
                        HStack(spacing:16) {
                            ForEach(selection=="all" ? monitor.samples : [primary]) { sample in
                                deviceCard(sample,at:context.date)
                            }
                        }
                        HStack(alignment:.top,spacing:16) {
                            disks.frame(maxWidth:.infinity)
                            proxyCard(at:context.date).frame(width:300)
                        }
                        HStack {
                            Text("私网服务 · 只读采样 · 每秒").font(.system(size:11)).foregroundStyle(.secondary)
                            Spacer()
                            Text("网速为所列网卡的实际收发流量").font(.system(size:11)).foregroundStyle(.secondary)
                        }.padding(.horizontal,5)
                    }.padding(26)
                    }
                }.background(boardBase)
            }.foregroundStyle(boardInk)
        }.frame(minWidth:1050,minHeight:740)
    }
    var phoneDetail:some View {
        VStack(alignment:.leading,spacing:20) {
            Label("手机",systemImage:"iphone").font(.system(size:27,weight:.regular))
            networkBadges(monitor.phoneSample,at:.now)
            let phone=monitor.phoneSample
            let link=phone?.privateLink
            HStack(spacing:20) {
                DeviceCard(title:"手机 ↔ 家庭网关",icon:link?.icon ?? "network") {
                    Text(link?.label(at:.now) ?? "路径待获取").font(.system(size:30,weight:.bold))
                    Text("观察端：家庭网关").foregroundStyle(.secondary)
                    Text(link?.endpoint ?? link?.relay ?? "尚无活动连接").font(.system(size:15,design:.monospaced))
                }
                DeviceCard(title:"手机私网身份",icon:"lock.shield.fill") {
                    Text(link?.tailnetAddress ?? "地址待获取").font(.system(size:24,weight:.semibold,design:.rounded))
                    Text(link?.transportVersion ?? "等待连接数据").foregroundStyle(.secondary)
                    Text(link?.online == true ? "私网在线" : "未确认在线").foregroundStyle(link?.online == true ? Color.green : Color.orange)
                }
            }
            HStack(spacing:20) {
                DeviceCard(title:"私网下载",icon:"arrow.down") { Text(deviceBytes(link?.gatewayTxBytesPerSecond)+"/s").font(.system(size:28,weight:.bold,design:.rounded)) }
                DeviceCard(title:"私网上传",icon:"arrow.up") { Text(deviceBytes(link?.gatewayRxBytesPerSecond)+"/s").font(.system(size:28,weight:.bold,design:.rounded)) }
            }
            Text("流量仅指手机与家庭网关之间的私网连接，不代表手机全部上网流量。").font(.system(size:12)).foregroundStyle(.secondary)
            if let observed=link?.observedAt { Text("路径采样："+observed.formatted(date:.omitted,time:.standard)).font(.system(size:12)).foregroundStyle(.secondary) }
            phoneHardware(phone)

        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func phoneHardware(_ phone:DeviceSample?)->some View {
        let available=phone?.hardwareSampleAvailable == true
        let fresh=available && phone?.hardwareFresh == true && phone?.receivedAt.map {Date().timeIntervalSince($0)<12} == true
        let state = phone?.phoneSamplingLabel(at:.now) ?? "等待手机采样"
        return VStack(alignment:.leading,spacing:14) {
            HStack {
                Label("手机本机采样",systemImage:"iphone").font(.system(size:19,weight:.semibold))
                Spacer()
                Text(state).font(.system(size:12)).foregroundStyle(fresh ? Color.green:Color.orange)
            }
            if available {
                HStack(alignment:.top,spacing:16) {
                    DeviceCard(title:"电量",icon:phone?.batteryCharging == true ? "battery.100percent.bolt":"battery.100percent") {
                        Text(phone?.batteryPercent.map {String(format:"%.0f%%",$0)} ?? "—").font(.system(size:28,weight:.bold,design:.rounded))
                        Text(phone?.batteryCharging == true ? "正在充电" : phone?.onACPower == true ? "已接电源":"使用电池").font(.system(size:12)).foregroundStyle(.secondary)
                    }
                    DeviceCard(title:"内存",icon:"memorychip") {
                        Text(deviceBytes(phone?.memoryUsed)).font(.system(size:25,weight:.bold,design:.rounded))
                        Text("总量 "+deviceBytes(phone?.memoryTotal)).font(.system(size:12)).foregroundStyle(.secondary)
                    }
                    DeviceCard(title:"当前网络",icon:"network") {
                        Text(["wifi":"Wi-Fi","mobile":"移动数据","ethernet":"有线网络","vpn":"VPN","none":"无网络","unknown":"未知"][phone?.networkType ?? ""] ?? "未上报").font(.system(size:23,weight:.semibold))
                        if let date=phone?.networkObservedAt {Text(date.formatted(date:.omitted,time:.standard)).font(.system(size:12)).foregroundStyle(.secondary)}
                    }
                }
                DeviceCard(title:"存储",icon:"internaldrive") {
                    if phone?.disks?.isEmpty != false {Text("未提供存储数据").font(.system(size:12)).foregroundStyle(.secondary)}
                    ForEach(phone?.disks ?? []) {disk in
                        VStack(alignment:.leading,spacing:6) {
                            HStack {Text(disk.name);Spacer();Text(deviceBytes(disk.used)+" / "+deviceBytes(disk.total)).monospacedDigit()}.font(.system(size:12))
                            ProgressView(value:disk.fraction).tint(disk.fraction>0.9 ? .orange:boardBlue)
                        }
                    }
                }
                if let date=phone?.receivedAt {Text("硬件采样："+date.formatted(date:.omitted,time:.standard)).font(.system(size:11)).foregroundStyle(.secondary)}
            } else {
                Text("手机采样客户端首次上报后显示电量、内存和存储；私网连接状态仍由上方网关观测独立提供。").font(.system(size:12)).foregroundStyle(.secondary)
            }
        }
    }
    var sidebar:some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {Image(systemName:"square.grid.2x2.fill").foregroundStyle(boardBlue);Text("设备看板").fontWeight(.semibold)}.padding(.bottom,25).padding(.top,14)
            sideButton("总览","square.grid.2x2","all")
            sideButton("Mac","laptopcomputer","mac")
            sideButton("WinPC","pc","winpc")
            sideButton("Linux 主机","server.rack","linux")
            sideButton("手机","iphone","phone")
            sideButton("旁路由","network","network")
            Spacer()
            Button {NSWorkspace.shared.open(DeskStore.link("thread",DeskStore.chief))} label:{Label("打开幕僚长",systemImage:"arrow.up.right.square").font(.system(size:12))}.buttonStyle(.plain).foregroundStyle(.secondary)
            Text("私网 / 1s").font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary).padding(.top,8)
        }.padding(18).frame(width:150).frame(maxHeight:.infinity).background(Color(nsColor:.controlBackgroundColor))
    }
    func sideButton(_ name:String,_ symbol:String,_ id:String)->some View {
        Button {withAnimation(.easeOut(duration:0.15)){selection=id}} label:{
            Label(name,systemImage:symbol).font(.system(size:13,weight:selection==id ? .semibold:.regular)).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,11).padding(.horizontal,12)
                .background(selection==id ? boardBlue.opacity(0.10):.clear,in:RoundedRectangle(cornerRadius:11))
                .foregroundStyle(selection==id ? boardBlue:boardInk)
        }.buttonStyle(.plain)
    }
    func header(at date:Date)->some View {
        HStack {
            Text(selection=="all" ? "设备看板":selection=="network" ? "旁路由":primary.title).font(.system(size:27,weight:.regular))
            Spacer()
            if let at=monitor.samples.compactMap(\.receivedAt).max(){ Text("更新 \(at.formatted(date:.omitted,time:.standard))").font(.system(size:12)).foregroundStyle(.secondary) }
            Image(systemName:"checkmark.circle.fill").font(.system(size:31)).foregroundStyle(monitor.samples.allSatisfy{$0.fresh(at:date)} ? Color.green:Color.orange)
        }.padding(.bottom,3)
    }
    func hero(at date:Date)->some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Label("当前设备",systemImage:"waveform.path.ecg").font(.system(size:12));Spacer();networkBadges(primary,at:date)}
            HStack {
                VStack(alignment:.leading,spacing:8) {
                    Text(primary.title).font(.system(size:31,weight:.bold))
                    Text(primary.host.isEmpty ? "等待设备连接":primary.host).font(.system(size:12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName:primary.id=="mac" ? "laptopcomputer":primary.id=="winpc" ? "pc":"server.rack").font(.system(size:40,weight:.light)).foregroundStyle(boardBlue).padding(12).background(WorkbenchStyle.accent.opacity(0.08),in:RoundedRectangle(cornerRadius:16))
            }
            HStack {Text(primary.interfaces.map{"网卡 · "+$0} ?? "网卡信息待采样");Spacer();Text(primary.uptime.map{"已运行 "+uptime($0)} ?? "—")}.font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(22).frame(height:174)
            .background(WorkbenchStyle.card,in:RoundedRectangle(cornerRadius:16))
            .shadow(color:.black.opacity(0.035),radius:9,y:5)
    }
    func networkBadges(_ sample:DeviceSample?,at date:Date)->some View {
        HStack(spacing:8) {
            if sample?.lanState(at:date) == "online" {networkBadge("局域网",state:"online")}
            networkBadge("私网",state:sample?.privateState(at:date) ?? "unknown")
        }
    }
    func networkBadge(_ title:String,state:String)->some View {
        let color:Color=state == "online" ? (title == "局域网" ? .blue:.green):state == "offline" ? .orange:.secondary
        return HStack(spacing:4) {
            Circle().fill(color).frame(width:5,height:5)
            Text(title+(state == "online" ? "在线":state == "offline" ? "离线":"未知")).font(.system(size:10,weight:.medium))
        }.padding(.horizontal,8).padding(.vertical,5).background(color.opacity(0.10),in:Capsule())
    }
    func status(_ sample:DeviceSample,at date:Date)->some View {
        HStack(spacing:5){Circle().fill(sample.fresh(at:date) ? .green:.orange).frame(width:6,height:6);Text(sample.fresh(at:date) ? "在线":sample.receivedAt==nil ? "未连接":"数据已过期")}
            .font(.system(size:11,weight:.medium)).padding(.horizontal,10).padding(.vertical,5).background(sample.fresh(at:date) ? Color.green.opacity(0.13):Color.orange.opacity(0.13),in:Capsule())
    }
    func speedCard(upload:Bool)->some View {
        let value=upload ? primary.upload:primary.download
        let values=(monitor.history[primary.id] ?? []).compactMap{upload ? $0.upload:$0.download}
        return DeviceCard(title:upload ? "上传":"下载",icon:upload ? "arrow.up":"arrow.down") {
            VStack(alignment:.leading,spacing:10) {
                Text(deviceBytes(value)+"/s").font(.system(size:27,weight:.bold,design:.rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                Text(primary.title+" · 峰值 "+deviceBytes(values.max())+"/s").font(.system(size:10)).foregroundStyle(.secondary)
                Spacer(minLength:10)
                DeviceSparkline(values:values,color:upload ? boardBlue.opacity(0.5):boardBlue)
            }.frame(height:103)
        }
    }
    func deviceCard(_ sample:DeviceSample,at date:Date)->some View {
        DeviceCard(title:sample.title,icon:sample.id=="mac" ? "laptopcomputer":sample.id=="winpc" ? "pc":"server.rack") {
            VStack(spacing:13) {
                metric("CPU",value:sample.cpu,color:boardBlue)
                metric("GPU",value:sample.gpu,color:Color(red:0.31,green:0.72,blue:0.66))
                metric("内存",value:sample.memoryTotal.flatMap{$0>0 ? (sample.memoryUsed ?? 0)/$0*100:nil},color:Color(red:0.56,green:0.65,blue:0.94))
                HStack {Text(deviceBytes(sample.memoryUsed)+" / "+deviceBytes(sample.memoryTotal));Spacer();Text(sample.fresh(at:date) ? "实时":"未更新")}.font(.system(size:10)).foregroundStyle(.secondary).monospacedDigit()
                if sample.gpu == nil {Text("GPU计数器未提供").font(.system(size:10)).foregroundStyle(.tertiary).frame(maxWidth:.infinity,alignment:.leading)}
                if let used=sample.gpuMemoryUsed,let total=sample.gpuMemoryTotal {Text("显存 "+deviceBytes(used)+" / "+deviceBytes(total)).font(.system(size:10)).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)}
                networkBadges(sample,at:date).frame(maxWidth:.infinity,alignment:.leading)
                if let issue=sample.issue {Text(issue).font(.system(size:10)).foregroundStyle(.orange).frame(maxWidth:.infinity,alignment:.leading)}
            }.frame(minHeight:122,alignment:.top)
        }
    }
    func metric(_ title:String,value:Double?,color:Color)->some View {
        HStack(spacing:10) {
            Text(title).font(.system(size:11)).frame(width:30,alignment:.leading)
            GeometryReader { p in ZStack(alignment:.leading){Capsule().fill(color.opacity(0.14));Capsule().fill(color).frame(width:p.size.width*min(1,max(0,(value ?? 0)/100)))}}.frame(height:7)
            Text(devicePercent(value)).font(.system(size:12,weight:.semibold,design:.rounded)).monospacedDigit().frame(width:40,alignment:.trailing)
        }
    }
    var disks:some View {
        DeviceCard(title:primary.title+" · 存储",icon:"internaldrive") {
            VStack(spacing:16) {
                if primary.disks?.isEmpty != false { Text("等待磁盘采样").font(.system(size:12)).foregroundStyle(.secondary) }
                ForEach(primary.disks ?? []) { disk in
                    VStack(spacing:7){HStack{Text(disk.name).font(.system(size:12,weight:.medium));Spacer();Text(deviceBytes(disk.used)+" / "+deviceBytes(disk.total)).font(.system(size:11)).foregroundStyle(.secondary)};ProgressView(value:disk.fraction).tint(disk.fraction>0.9 ? .orange:boardBlue)}
                }
            }.frame(minHeight:112,alignment:.top)
        }
    }
    func network(at date:Date)->some View {
        let linux=monitor.samples.first{$0.id=="linux"} ?? .waiting("linux")
        return DeviceCard(title:"旁路由",icon:"network") {
            VStack(spacing:12) {
                ForEach(linux.services ?? []) { service in
                    HStack{Text(service.label);Spacer();Circle().fill(linux.fresh(at:date) && service.state=="active" ? Color.green:Color.orange).frame(width:7,height:7);Text(linux.fresh(at:date) ? service.state:"未更新").foregroundStyle(.secondary)}.font(.system(size:11))
                }
                if linux.services?.isEmpty != false {Text("等待 Linux 采样").font(.system(size:12)).foregroundStyle(.secondary)}
                HStack {Text("DNS 53 · "+listening(linux.dnsListening));Spacer();Text("代理 7890 · "+listening(linux.proxyListening))}.font(.system(size:10)).foregroundStyle(.secondary)
                Text("OpenWrt 家庭网关").font(.system(size:10)).foregroundStyle(.tertiary).frame(maxWidth:.infinity,alignment:.leading)
            }.frame(minHeight:112,alignment:.top)
        }
    }
    func proxyCard(at date:Date)->some View {
        let sample=monitor.samples.first{$0.id=="linux"}
        let proxy=sample?.proxy
        return DeviceCard(title:"旁路与 VPS",icon:"globe") {
            VStack(alignment:.leading,spacing:14) {
                networkBadges(monitor.gatewaySample,at:date)
                if let current=proxy?.selected {HStack {Text(sample?.fresh(at:date)==true ? "当前":"上次选用").font(.system(size:11)).foregroundStyle(.secondary);Text(current).font(.system(size:13,weight:.semibold)).foregroundStyle(boardBlue).lineLimit(1).truncationMode(.middle)}}
                if let proxy,proxy.error==nil,!proxy.nodes.isEmpty {
                    ForEach(proxy.nodes) {node in
                        HStack(spacing:8) {
                            Circle().fill(sample?.fresh(at:date)==true && node.health=="healthy" ? Color.green:node.health=="unhealthy" ? Color.red:Color.orange).frame(width:7,height:7)
                            VStack(alignment:.leading,spacing:4) {
                                Text(node.name).font(.system(size:12,weight:.medium)).lineLimit(1).truncationMode(.middle)
                                Text((sample?.fresh(at:date)==true ? node.healthLabel:"状态未更新")+(node.selected ? (sample?.fresh(at:date)==true ? " · 当前":" · 上次选用"):"")).font(.system(size:10)).foregroundStyle(.secondary)
                                if let time=node.probeDate {Text("探测 "+time.formatted(date:.omitted,time:.standard)).font(.system(size:9)).foregroundStyle(.tertiary)}
                            }
                            Spacer(minLength:4)
                            Text((sample?.fresh(at:date)==true ? node.latencyMs:nil).map{String(format:"%.0f ms",$0)} ?? "—").font(.system(size:17,weight:.semibold,design:.rounded)).monospacedDigit().lineLimit(1)
                        }
                    }
                    Text("HTTP代理链路 · 沿用旁路约30秒探测").font(.system(size:10)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                } else {Text("节点状态暂不可读").font(.system(size:12)).foregroundStyle(.secondary)}
                Divider().opacity(0.4)
                LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],alignment:.leading,spacing:8) {
                    ForEach(sample?.services ?? []) {service in
                        HStack(spacing:5) {Circle().fill(sample?.fresh(at:date)==true && service.state=="active" ? Color.green:Color.orange).frame(width:6,height:6);Text(service.label).font(.system(size:10)).lineLimit(1)}
                    }
                }
            }
        }
    }
    func listening(_ value:Bool?)->String {value.map{$0 ? "监听":"未监听"} ?? "—"}
    func uptime(_ value:Double)->String {let h=Int(value)/3600;return h>=24 ? "\(h/24)天\(h%24)小时":"\(h)小时\(Int(value)/60%60)分"}
}
