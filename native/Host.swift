import AppKit
import Foundation
import WidgetKit
import SwiftUI

final class Host: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var timer: Timer?
    var busy = false
    var revision: String?
    let service = WorkbenchClient()
    var publishedRevision: String?
    var publishing = false
    var syncIssue: String?
    let devices=DeviceMonitor()
    let navigation=WorkbenchNavigation()
    let appearance=WorkbenchAppearance()
    var window:NSWindow?
    var pendingReopen: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let url=Bundle.main.url(forResource:"Workbench",withExtension:"icns"),let image=NSImage(contentsOf:url) {
            image.size=NSSize(width:20,height:20);image.isTemplate=false;status.button?.image=image
        } else {status.button?.image=NSImage(systemSymbolName:"circle.grid.2x2",accessibilityDescription:"CXY Workbench OSS")}
        let menu = NSMenu()
        menu.addItem(withTitle:"打开工作台",action:#selector(openWorkbench),keyEquivalent:"o").target=self
        menu.addItem(withTitle:"行动台",action:#selector(openActions),keyEquivalent:"a").target=self
        menu.addItem(withTitle:"设备看板",action:#selector(openDevices),keyEquivalent:"d").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle: "刷新现有安排", action: #selector(refreshClick), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "打开幕僚长", action: #selector(openChief), keyEquivalent: "").target = self
        menu.addItem(withTitle: "如何添加桌面小组件", action: #selector(instructions), keyEquivalent: "").target = self
        menu.addItem(withTitle:"设置…",action:#selector(openSettings),keyEquivalent:",").target=self
        menu.addItem(withTitle:"刷新桌面小组件",action:#selector(reloadWidgets),keyEquivalent:"").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出工作台", action: #selector(quit), keyEquivalent: "q").target = self
        status.menu = menu
        appearance.apply = {[weak self] in self?.applyAppearance()}
        installMainMenu()
        applyAppearance()
        reloadWidgets()
        do { try DeskStore.updatePrefs { _ in } }
        catch { status.button?.toolTip = "展示偏好初始化失败；正式安排未修改" }
        refresh()
        devices.start()
        if CommandLine.arguments.contains("--devices") {navigation.page="devices"}
        if !CommandLine.arguments.contains("--background") {openWorkbench()}
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        // A URL open may also deliver a reopen event. Only explicit navigation
        // below may show a window; refresh and preference intents stay silent.
        pendingReopen?.cancel()
        pendingReopen = nil
        for url in urls {
            if url.scheme=="cxy-devices-oss" {
                let pages=["overview":"all","mac":"mac","winpc":"winpc","linux":"linux","phone":"phone","gateway":"network"]
                navigation.deviceSelection=pages[url.host ?? "overview"] ?? "all"
                navigation.page="devices";openWorkbench();continue
            }
            guard url.scheme == "cxy-actiondesk-oss", let host = url.host else { continue }
            let value = String(url.path.dropFirst())
            switch host {
            case "thread": openThread(value)
            case "view", "group", "page", "select", "month", "day":
                let knownIDs = Set(DeskStore.read()?.items.map(\.id) ?? [])
                do { try DeskStore.updatePrefs { $0.apply(host, value, knownIDs: knownIDs) }; WidgetCenter.shared.reloadTimelines(ofKind: DeskStore.kind) }
                catch { status.button?.toolTip = "展示偏好保存失败，原安排未修改" }
            case "devices": openDevices()
            case "settings": openSettings()
            case "news": navigation.page="news";openWorkbench()
            case "widgets-reload": reloadWidgets()
            case "actions", "overview": openActions()
            case "devices-status":
                WidgetCenter.shared.getCurrentConfigurations { result in
                    if case .success(let configs)=result {
                        let rows=configs.map {["kind":$0.kind,"family":String(describing:$0.family)]}
                        if let data=try? JSONSerialization.data(withJSONObject:rows) {try? self.write(data,to:DeskStore.directory.appendingPathComponent("widget-configurations.json"))}
                    }
                }
            case "refresh": refresh(forceReload: true)
            default: break
            }
        }
    }
    func openThread(_ id: String) {
        guard DeskConfiguration.navigable(id) else { return }
        let snapshot = DeskStore.read()
        let known = Set((snapshot?.items.flatMap { $0.targets.map(\.id) } ?? []) + (snapshot?.calendarEvents?.map(\.thread) ?? []) + [DeskStore.chief])
        guard known.contains(id), let url = URL(string: "codex://threads/" + id) else { return }
        NSWorkspace.shared.open(url)
    }
    func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: DeskStore.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    func refresh(forceReload: Bool = false) {
        guard !busy else { return }; busy = true
        DispatchQueue.global(qos: .utility).async {
            do {
                let snapshot = try DeskProjection.build()
                let data = try JSONEncoder().encode(snapshot)
                guard snapshot.schemaVersion == 1, snapshot.items.count < 10000 else { throw CocoaError(.fileReadCorruptFile) }
                try self.write(data, to: DeskStore.snapshot)
                DispatchQueue.main.async {
                    if self.revision != snapshot.revision || forceReload {
                        self.revision = snapshot.revision
                        WidgetCenter.shared.reloadTimelines(ofKind: DeskStore.kind)
                    }
                    self.status.button?.toolTip = "CXY Workbench OSS · \(snapshot.items.count)条现有安排" + (self.syncIssue.map { " · " + $0 } ?? " · 已同步")
                    self.busy = false
                    self.publish(snapshot)
                }
            } catch {
                DispatchQueue.main.async {
                    self.status.button?.toolTip = "读取失败，保留上次展示缓存；正式安排未修改"
                    self.busy = false
                    self.loadRemoteIfNeeded()
                }
            }
        }
    }
    func publish(_ snapshot: Snapshot) {
        let identity=snapshot.sourceRevision+":"+snapshot.revision
        guard !publishing, publishedRevision != identity else { return }
        publishing=true
        service.put("/v1/actions", value: snapshot, role: .actions) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else{return};self.publishing=false
                if ok {
                    self.publishedRevision=identity;self.syncIssue=nil
                    self.status.button?.toolTip="CXY Workbench OSS · \(snapshot.items.count)条现有安排 · 已同步Linux"
                } else {
                    self.syncIssue="尚未同步Linux，将自动重试"
                    self.status.button?.toolTip="CXY Workbench OSS · 本地安排可用 · \(self.syncIssue!)"
                    NSLog("Action snapshot publish failed; retaining source and pending retry")
                }
            }
        }
    }
    func loadRemoteIfNeeded() {
        service.get("/v1/actions", as: Snapshot.self) { [weak self] result in
            guard case .success(let snapshot)=result, let data=try? JSONEncoder().encode(snapshot) else { return }
            do { try self?.write(data,to:DeskStore.snapshot)
                DispatchQueue.main.async { WidgetCenter.shared.reloadTimelines(ofKind:DeskStore.kind) }
            } catch { NSLog("Action remote cache write failed") }
        }
    }
    @objc func openWorkbench() {
        if window==nil {
            let value=NSWindow(contentRect:NSRect(x:0,y:0,width:1180,height:870),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
            value.title="CXY Workbench OSS";value.titlebarAppearsTransparent=true;value.isReleasedWhenClosed=false
            value.contentMinSize=NSSize(width:1050,height:850)
            value.contentView=NSHostingView(rootView:WorkbenchWindow(navigation:navigation,monitor:devices,refreshActions:{[weak self] in self?.refresh(forceReload:true)},appearance:appearance,refreshWidgets:{[weak self] in self?.reloadWidgets()}))
            value.center();window=value
        }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        NSApplication.shared.activate(ignoringOtherApps:true);window?.makeKeyAndOrderFront(nil)
    }
    func applyAppearance() {
        let policy: NSApplication.ActivationPolicy = appearance.dockVisible ? .regular:.accessory
        if NSApplication.shared.activationPolicy() != policy {
            NSApplication.shared.setActivationPolicy(policy)
        }
        status.isVisible=appearance.menuVisible
    }
    func installMainMenu() {
        let main=NSMenu()
        func submenu(_ title:String)->NSMenu {
            let item=NSMenuItem();let menu=NSMenu(title:title)
            item.submenu=menu;main.addItem(item);return menu
        }
        let menu=submenu("CXY Workbench OSS")
        menu.addItem(withTitle:"设置…",action:#selector(openSettings),keyEquivalent:",").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle:"隐藏工作台",action:#selector(NSApplication.hide(_:)),keyEquivalent:"h")
        let hideOthers=menu.addItem(withTitle:"隐藏其他",action:#selector(NSApplication.hideOtherApplications(_:)),keyEquivalent:"h")
        hideOthers.keyEquivalentModifierMask=[.command,.option]
        menu.addItem(withTitle:"显示全部",action:#selector(NSApplication.unhideAllApplications(_:)),keyEquivalent:"")
        menu.addItem(.separator());menu.addItem(withTitle:"退出工作台",action:#selector(quit),keyEquivalent:"q").target=self
        let file=submenu("文件")
        file.addItem(withTitle:"打开工作台",action:#selector(openWorkbench),keyEquivalent:"o").target=self
        file.addItem(withTitle:"关闭窗口",action:#selector(NSWindow.performClose(_:)),keyEquivalent:"w")
        let edit=submenu("编辑")
        edit.addItem(withTitle:"撤销",action:NSSelectorFromString("undo:"),keyEquivalent:"z")
        let redo=edit.addItem(withTitle:"重做",action:NSSelectorFromString("redo:"),keyEquivalent:"z")
        redo.keyEquivalentModifierMask=[.command,.shift]
        edit.addItem(.separator())
        for (title,action,key) in [("剪切","cut:","x"),("拷贝","copy:","c"),("粘贴","paste:","v"),("全选","selectAll:","a")] {
            edit.addItem(withTitle:title,action:NSSelectorFromString(action),keyEquivalent:key)
        }
        let windows=submenu("窗口")
        windows.addItem(withTitle:"最小化",action:#selector(NSWindow.performMiniaturize(_:)),keyEquivalent:"m")
        windows.addItem(withTitle:"缩放",action:#selector(NSWindow.performZoom(_:)),keyEquivalent:"")
        windows.addItem(.separator())
        windows.addItem(withTitle:"前置所有窗口",action:#selector(NSApplication.arrangeInFront(_:)),keyEquivalent:"")
        NSApplication.shared.windowsMenu=windows
        NSApplication.shared.mainMenu=main
    }
    @objc func openSettings(){navigation.page="settings";openWorkbench()}
    @objc func reloadWidgets() {
        let kinds=[DeskStore.kind]+TelemetryStore.deviceKinds
        for kind in kinds {WidgetCenter.shared.reloadTimelines(ofKind:kind)}
        WidgetCenter.shared.getCurrentConfigurations {[weak self] result in
            var report:[String:Any]=["requestedAt":Date().timeIntervalSince1970,"hostBuild":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown","hostPath":Bundle.main.bundlePath,"requestedKinds":kinds]
            switch result {
            case .success(let values):report["configurations"]=values.map {["kind":$0.kind,"family":String(describing:$0.family)]}
            case .failure(let error):report["error"]=error.localizedDescription
            }
            do {let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try self?.write(data,to:DeskStore.directory.appendingPathComponent("widget-reload-report.json"))}
            catch {NSLog("Widget reload diagnostics could not be saved: %@",error.localizedDescription)}
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}
    @objc func openActions(){navigation.page="actions";openWorkbench()}
    @objc func openDevices(){navigation.page="devices";openWorkbench()}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
        pendingReopen?.cancel()
        let request=DispatchWorkItem { [weak self, weak sender] in
            guard let self, let sender, sender.isActive else { return }
            self.openWorkbench()
        }
        pendingReopen=request
        DispatchQueue.main.async(execute:request)
        return false
    }
    func applicationWillTerminate(_ notification:Notification){timer?.invalidate();devices.stop()}
    @objc func refreshClick() { refresh(forceReload: true) }
    @objc func openChief() { openThread(DeskStore.chief) }
    @objc func quit() { NSApplication.shared.terminate(nil) }
    @objc func instructions() {
        let alert = NSAlert()
        alert.messageText = "添加原生桌面小组件"
        alert.informativeText = "在桌面空白处右键 → 编辑小组件 → CXY Workbench OSS。行动台与Mac、WinPC、Linux、手机和网关可分别添加。原行动台保留；原独立设备App的组件需重新添加一次。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}

#if !WINDOW_COMMAND_CHECKS
@main
enum ActionDeskMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = Host()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
#endif
