import AppIntents
import Foundation
import OSLog

// Runs in the WidgetKit extension; changes display preferences only.
struct DisplayAction: AppIntent {
    static var title: LocalizedStringResource = "切换行动台展示"
    static var description = IntentDescription("切换视图、事项详情或日历日期，不修改工作安排。")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    @Parameter(title: "操作") var action: String
    @Parameter(title: "选项") var value: String
    init() {}
    init(_ action: String, _ value: String) { self.action = action; self.value = value }
    func perform() async throws -> some IntentResult {
        let start = ProcessInfo.processInfo.systemUptime
        // Only item selection needs the work cache. Category, view and calendar
        // controls must not decode every task merely to change a display value.
        let knownIDs: Set<String> = action == "select" ? Set(DeskStore.read()?.items.map(\.id) ?? []) : []
        var result = ""
        let changed = try DeskStore.updatePrefs { p in
            p.apply(action, value, knownIDs: knownIDs)
            result = action == "select" ? (p.selected ?? "none") : p.safeGroup + ":" + p.safeMode
        }
        let elapsed = (ProcessInfo.processInfo.systemUptime - start) * 1000
        Logger(subsystem: "local.cxy.actiondesk", category: "interaction").notice("v15 action=\(action, privacy: .public) target=\(value, privacy: .public) result=\(result, privacy: .public) changed=\(changed, privacy: .public) handlerMs=\(elapsed, privacy: .public)")
        // WidgetKit automatically reloads the timeline after a button intent completes.
        return .result()
    }
}
