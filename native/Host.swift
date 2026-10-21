import AppKit
import Foundation
import WidgetKit

final class Host: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var timer: Timer?
    var busy = false
    var revision: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "circle.grid.2x2", accessibilityDescription: "CXY 行动台")
        let menu = NSMenu()
        menu.addItem(withTitle: "刷新现有安排", action: #selector(refreshClick), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "打开幕僚长", action: #selector(openChief), keyEquivalent: "").target = self
        menu.addItem(withTitle: "如何添加桌面小组件", action: #selector(instructions), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出行动台", action: #selector(quit), keyEquivalent: "q").target = self
        status.menu = menu
        do { try DeskStore.updatePrefs { _ in } }
        catch { status.button?.toolTip = "展示偏好初始化失败；正式安排未修改" }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "cxy-actiondesk-oss", let host = url.host else { continue }
            let value = String(url.path.dropFirst())
            switch host {
            case "thread": openThread(value)
            case "view", "group", "page", "select", "month", "day":
                let knownIDs = Set(DeskStore.read()?.items.map(\.id) ?? [])
                do { try DeskStore.updatePrefs { $0.apply(host, value, knownIDs: knownIDs) }; WidgetCenter.shared.reloadTimelines(ofKind: DeskStore.kind) }
                catch { status.button?.toolTip = "展示偏好保存失败，原安排未修改" }
            case "refresh": refresh(forceReload: true)
            default: break
            }
        }
    }
    func openThread(_ id: String) {
        guard DeskConfiguration.navigable(id) else {
            let alert = NSAlert()
            alert.messageText = "尚未配置自己的工作线程"
            alert.informativeText = "当前为演示UUID或未配置。请在OSS配置与线程映射中填入你有权访问的真实Codex线程；演示数据不会打开不存在的聊天。"
            alert.addButton(withTitle: "知道了")
            alert.runModal()
            return
        }
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
                    self.status.button?.toolTip = "CXY 行动台 · \(snapshot.items.count)条现有安排 · 只读"
                    self.busy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.status.button?.toolTip = "读取失败，保留上次展示缓存；正式安排未修改"
                    self.busy = false
                }
            }
        }
    }
    @objc func refreshClick() { refresh(forceReload: true) }
    @objc func openChief() { openThread(DeskStore.chief) }
    @objc func quit() { NSApplication.shared.terminate(nil) }
    @objc func instructions() {
        let alert = NSAlert()
        alert.messageText = "添加原生桌面小组件"
        alert.informativeText = "在桌面空白处右键 → 编辑小组件 → CXY 行动台，添加唯一的超大竖版。展示内容来自现有 PROJECT.md，不另建任务系统。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}

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
