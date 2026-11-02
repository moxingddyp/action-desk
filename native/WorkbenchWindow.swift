import AppKit
import SwiftUI

enum WorkbenchStyle {
    static let accent=Color(red:52/255,green:130/255,blue:1)
    static let base=Color(nsColor:NSColor(name:nil){appearance in appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor.black:NSColor(white:0.969,alpha:1)})
    static let card=Color(nsColor:NSColor(name:nil){appearance in appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(white:0.141,alpha:1):NSColor.white})
}

final class WorkbenchAppearance:ObservableObject {
    private let defaults:UserDefaults
    @Published var dockVisible:Bool {didSet {defaults.set(dockVisible,forKey:"workbenchDockVisible");apply?()}}
    @Published var menuVisible:Bool {didSet {defaults.set(menuVisible,forKey:"workbenchMenuVisible");apply?()}}
    var apply:(()->Void)?
    init(defaults:UserDefaults = .standard) {
        self.defaults=defaults
        dockVisible=defaults.object(forKey:"workbenchDockVisible") as? Bool ?? false
        menuVisible=defaults.object(forKey:"workbenchMenuVisible") as? Bool ?? true
    }
}
struct WorkbenchSettings:View {
    @ObservedObject var appearance:WorkbenchAppearance
    var refreshWidgets:()->Void
    var body:some View {
        Form {
            Section("应用显示") {
                Toggle("在 Dock 显示",isOn:$appearance.dockVisible)
                Toggle("在菜单栏显示",isOn:$appearance.menuVisible)
                Button("恢复默认显示") {appearance.dockVisible=false;appearance.menuVisible=true}
                Text("关闭窗口后，采样和同步继续运行。隐藏两个入口后，仍可从访达打开 CXY Workbench OSS，或点击桌面小组件返回。").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            Section("桌面小组件") {
                Button("刷新桌面小组件",action:refreshWidgets)
                Text("向 macOS 请求重新读取当前缓存；实际更新时间由系统调度。").font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(maxWidth:650).padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.top)
    }
}
final class WorkbenchNavigation: ObservableObject {
    @Published var page: String {
        didSet { UserDefaults.standard.set(page,forKey:"workbenchPage") }
    }
    @Published var deviceSelection="all"
    init() {
        let saved=UserDefaults.standard.string(forKey:"workbenchPage") ?? "actions"
        page=["actions","devices","news","settings"].contains(saved) ? saved:"actions"
        let existing=DeviceDisplayPrefs.read().tab
        deviceSelection=["overview":"all","mac":"mac","winpc":"winpc","linux":"linux","phone":"phone","gateway":"network"][existing] ?? "all"
    }
}
struct WorkbenchWindow: View {
    @ObservedObject var navigation:WorkbenchNavigation
    @ObservedObject var monitor:DeviceMonitor
    var refreshActions:()->Void
    @ObservedObject var appearance:WorkbenchAppearance
    var refreshWidgets:()->Void
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:16) {
                HStack(spacing:7) {
                    Image(nsImage:NSApplication.shared.applicationIconImage).resizable().frame(width:25,height:25)
                    Text("CXY Workbench OSS").font(.system(size:15,weight:.semibold))
                }
                Spacer()
                HStack(spacing:6){
                    ForEach([("actions","行动台","checklist"),("devices","设备看板","desktopcomputer"),("news","每日信息","newspaper"),("settings","设置","gearshape")],id:\.0){item in
                        Button {navigation.page=item.0} label:{Label(item.1,systemImage:item.2).font(.system(size:13,weight:navigation.page==item.0 ? .semibold:.regular)).padding(.horizontal,14).padding(.vertical,10).background(navigation.page==item.0 ? WorkbenchStyle.card:.clear,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(navigation.page==item.0 ? .primary:.secondary)}.buttonStyle(.plain)
                    }
                }
                Spacer()
                Button {navigation.page="settings"} label: {Image(systemName:"gearshape")}.help("设置")
                Button {
                    if navigation.page=="actions" {refreshActions()} else if navigation.page=="news" {NotificationCenter.default.post(name:Notification.Name("CXYRefreshReading"),object:nil)} else {monitor.tick()}
                } label: {Image(systemName:"arrow.clockwise")}.help("刷新当前页面")
            }.padding(.horizontal,22).padding(.vertical,13)
            Divider()
            if navigation.page=="settings" {
                WorkbenchSettings(appearance:appearance,refreshWidgets:refreshWidgets)
            } else if navigation.page=="news" {
                WorkbenchReadingPage()
            } else if navigation.page=="actions" {
                WorkbenchActionPage()
            } else {
                DeviceDashboard(monitor:monitor,selection:navigation.deviceSelection)
                    .id(navigation.deviceSelection)
            }
        }.frame(minWidth:1050,minHeight:820).background(WorkbenchStyle.base).tint(WorkbenchStyle.accent)
    }
}
struct WorkbenchActionPage:View {
    var body:some View {
        TimelineView(.periodic(from:.now,by:1)) { context in
            let snapshot=DeskStore.read()
            let prefs=DeskStore.prefs()
            let entry=DeskEntry(date:context.date,snapshot:snapshot,prefs:prefs)
            HStack(alignment:.top,spacing:26) {
                DeskWidgetView(entry:entry)
                    .padding(16).frame(width:376,height:736)
                    .background(WorkbenchStyle.card,in:RoundedRectangle(cornerRadius:16))
                WorkbenchActionDetails(snapshot:snapshot,prefs:prefs)
                    .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            }.padding(24).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                .background(WorkbenchStyle.base)
        }
    }
}
struct WorkbenchActionDetails:View {
    var snapshot:Snapshot?
    var prefs:DisplayPrefs
    var visibleItems:[WorkItem] {
        let items=snapshot?.items.filter{$0.belongs(to:prefs.safeGroup)} ?? []
        if let selected=prefs.selected,let item=items.first(where:{$0.id==selected}) {return [item]}
        return items
    }
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Text(prefs.selected == nil ? prefs.safeGroup:"事项详情").font(.system(size:23,weight:.semibold))
                Spacer()
                if let snapshot {Text("\(snapshot.items.count)项安排").font(.system(size:12)).foregroundStyle(.secondary)}
            }
            if prefs.safeGroup=="日常" {
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        ForEach(snapshot?.calendarEvents ?? []) {event in
                            VStack(alignment:.leading,spacing:7) {
                                Text(event.title).font(.headline)
                                Text(event.date+" "+event.time).font(.subheadline).foregroundStyle(.secondary)
                                if !event.place.isEmpty {Text(event.place).font(.subheadline)}
                                if !event.note.isEmpty {Text(event.note).font(.subheadline).foregroundStyle(.secondary)}
                            }.padding(16).frame(maxWidth:.infinity,alignment:.leading).background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:16))
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:14) {
                        ForEach(visibleItems) {item in
                            VStack(alignment:.leading,spacing:10) {
                                Text(item.label).font(.system(size:15,weight:.semibold))
                                if !item.current.isEmpty {field("当前进度",item.current)}
                                if !item.next.isEmpty {field("下一步",item.next)}
                                if !item.deadline.isEmpty {field("期限/安排",item.deadline)}
                                if let owner=item.owner,!owner.isEmpty {field("执行主体",owner)}
                                if !item.output.isEmpty {field("成果/依赖",item.output)}
                                if let url=URL(string:"cxy-actiondesk-oss://thread/"+item.thread) {
                                    Link("打开原线程",destination:url).font(.system(size:12,weight:.medium))
                                }
                            }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
                                .background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:16))
                        }
                        if visibleItems.isEmpty {Text("暂无该分类事项").foregroundStyle(.secondary).padding(.top,12)}
                    }
                }
            }
            if let snapshot {
                Text("来源更新 "+snapshot.generatedDate.formatted(date:.abbreviated,time:.shortened))
                    .font(.system(size:10)).foregroundStyle(.secondary)
            }
        }
    }
    func field(_ name:String,_ value:String)->some View {
        VStack(alignment:.leading,spacing:4) {
            Text(name).font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
            Text(value).font(.system(size:12)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
        }
    }
}

private struct ReadingItem:Codable,Identifiable {
    var headline:String;var summary:String;var sources:[String];var category:String?;var tags:[String]?;var publishedAt:String?;var why:String?;var verificationLinks:[String]?
    var id:String {headline}
}
private struct ReadingEdition:Codable {
    var title:String;var coverageNote:String;var highlights:[ReadingItem];var otherItems:[ReadingItem]
    var items:[ReadingItem] {highlights+otherItems}
}
private final class ReadingModel:ObservableObject {
    @Published var edition:ReadingEdition?
    @Published var error=""
    @Published var loading=false
    private let client=WorkbenchClient()
    private var cache:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CXY Action Desk OSS/information.json")}
    init(){if let data=try? Data(contentsOf:cache){edition=try? JSONDecoder().decode(ReadingEdition.self,from:data)}}
    func refresh(){guard !loading else{return};loading=true
        client.get("/v1/information",as:ReadingEdition.self){[weak self] result in DispatchQueue.main.async {
            guard let self else{return};self.loading=false
            switch result {case .success(let value):self.edition=value;self.error=""
                do {let data=try JSONEncoder().encode(value);try data.write(to:self.cache,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:self.cache.path)}catch {self.error="已读取，但离线缓存保存失败："+error.localizedDescription}
            case .failure(let e):self.error="每日信息读取失败："+e.localizedDescription}
        }}
    }
}
private struct WorkbenchReadingPage:View {
    @StateObject private var model=ReadingModel()
    @State private var topic="全部"
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:8){Text("每日信息").font(.system(size:30,weight:.regular));Text(model.edition?.title ?? "尚未同步每日整理").foregroundStyle(.secondary)}
                    Spacer()
                    Button {model.refresh()} label:{Label(model.loading ? "读取中":"刷新",systemImage:"arrow.clockwise")}.disabled(model.loading)
                }
                if !model.error.isEmpty {Text(model.error).foregroundStyle(.orange)}
                if let edition=model.edition {
                    DisclosureGroup("采集范围与缺口"){Text(edition.coverageNote).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).padding(.top,8)}
                    let topics=["全部","AI 与 Agent","科研与医学","独立事业","自由生活"]
                    ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){ForEach(topics,id:\.self){tag in Button {topic=tag} label:{Text(tag).padding(.horizontal,12).padding(.vertical,7).background(topic==tag ? WorkbenchStyle.accent.opacity(0.13):WorkbenchStyle.card,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(topic==tag ? .blue:.secondary)}.buttonStyle(.plain)}}}
                    if topic != "全部" && !edition.items.contains(where:{$0.category==topic}) {Text("本期暂无该类信息").foregroundStyle(.secondary)}
                    LazyVStack(alignment:.leading,spacing:16){ForEach(edition.items.filter{topic=="全部" || $0.category==topic}) {item in
                        VStack(alignment:.leading,spacing:14){
                            HStack {Text(item.category ?? "待分类").foregroundStyle(.blue);Spacer();if let date=item.publishedAt {Text(date).foregroundStyle(.secondary)}}.font(.caption)
                            Text(item.headline).font(.system(size:21,weight:.semibold))
                            Text(item.summary).font(.system(size:16)).lineSpacing(7).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                            if let tags=item.tags,!tags.isEmpty {Text(tags.joined(separator:" · ")).font(.caption).foregroundStyle(.secondary)}
                            if let why=item.why,!why.isEmpty {Text(why).foregroundStyle(.secondary)}
                            FlowSourceLinks(sources:item.sources)
                            if let links=item.verificationLinks,!links.isEmpty {FlowSourceLinks(sources:links)}
                        }.padding(24).frame(maxWidth:.infinity,alignment:.leading).background(WorkbenchStyle.card,in:RoundedRectangle(cornerRadius:16))
                    }}
                } else if !model.loading {Button("获取每日信息"){model.refresh()}}
            }.frame(maxWidth:860).padding(28).frame(maxWidth:.infinity)
        }.background(WorkbenchStyle.base).task {model.refresh()}.onReceive(NotificationCenter.default.publisher(for:Notification.Name("CXYRefreshReading"))){_ in model.refresh()}
    }
}
private struct FlowSourceLinks:View {
    var sources:[String]
    var body:some View {
        VStack(alignment:.leading,spacing:10){ForEach(Array(sources.enumerated()),id:\.offset){index,source in
            if let url=URL(string:source),["https","http"].contains(url.scheme ?? "") {Link(destination:url){Label((url.host ?? "原文")+(sources.count>1 ? " · \(index+1)":""),systemImage:"arrow.up.right")}.font(.callout)}
        }}
}

}
