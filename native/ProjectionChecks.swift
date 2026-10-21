// Standalone regression checks; not part of the installed app targets.
import Foundation

@main
enum ProjectionChecks {
    static func main() throws {
        precondition(DeskConfiguration.accountHome.path.hasPrefix("/"))
        precondition(!DeskConfiguration.accountHome.path.contains("/Containers/"))
        if let container = ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"] {
            precondition(DeskConfiguration.accountHome.path != container)
            precondition(!DeskStore.directory.path.hasPrefix(container + "/"))
            print("PASS: account-home cache remains independent of Foundation container-home override")
        }
        precondition(DeskStore.directory.deletingLastPathComponent().lastPathComponent == "Application Support")
        precondition(!DeskConfiguration.navigable("00000000-0000-0000-0000-000000000001"))
        precondition(!DeskConfiguration.navigable("invalid"))
        let fixture = """
        ## 事项安排
        | 事项ID | 事项/项目 | 分类 | 当前情况 | 下一行动 | 执行主体 | 交付物/依赖 | 真实期限/安排 | 来源 |
        | --- | --- | --- | --- | --- | --- | --- | --- | --- |
        | 0123456789abcdef | 旧事项 | 当前可做 | 原进度 | 下一步 | 用户 | 成果 | | 来源 |
         |
        |
        | | | |
        | 0011-A07 | 0011 测试 | 优先做、正在做 | 单一进度 | 接入 | 项目 | 交付 | | 授权 |
        """
        let rows = DeskProjection.workRows(DeskProjection.sections(fixture)["事项安排"]!)
        let items = DeskProjection.parse(fixture, names: [:], links: [:])
        precondition(rows.count == 2 && items.count == 2)
        precondition(items.map(\.id) == ["0123456789abcdef", "0011-A07"])
        precondition(items[1].categories == ["优先做", "正在做"])
        let conflict = fixture.replacingOccurrences(of: "优先做、正在做", with: "正在做、当前可做")
        precondition(DeskProjection.parse(conflict, names: [:], links: [:]).count == 1)
        var oldPrefs = DisplayPrefs(); oldPrefs.group = "继续做"
        precondition(oldPrefs.safeGroup == "正在做")
        for group in DeskStore.groups {
            var p = DisplayPrefs(); p.selected = "old"; p.page = 2
            p.apply("group", group, knownIDs: [])
            precondition(p.safeGroup == group && p.selected == nil && p.page == 0)
        }
        var p = DisplayPrefs()
        let start = ProcessInfo.processInfo.systemUptime
        for _ in 0..<1000 {
            p.apply("group", "正在做", knownIDs: [])
            p.apply("group", "条件做", knownIDs: [])
            p.apply("select", "0123456789abcdef", knownIDs: ["0123456789abcdef"])
            p.apply("select", "0123456789abcdef", knownIDs: ["0123456789abcdef"])
            precondition(p.safeGroup == "条件做" && p.selected == nil)
        }
        print("4000 display-state transitions ms=\((ProcessInfo.processInfo.systemUptime-start)*1000)")
        precondition(!DeskProjection.validItemID("0011 A07"))
        precondition(!DeskProjection.validItemID("../0011-A07"))
        let bad = fixture + "\n| bad-id | 不可丢弃 | 错标签 | 内容 | 下一步 | 人 | 成果 | | 来源 |"
        precondition(DeskProjection.workRows(DeskProjection.sections(bad)["事项安排"]!).count == 3)
        precondition(DeskProjection.parse(bad, names: [:], links: [:]).count == 2)
        let file = DeskProjection.root.appendingPathComponent("PROJECT.md")
        let before = try Data(contentsOf: file)
        let result = try DeskProjection.build()
        let after = try Data(contentsOf: file)
        precondition(after == before)
        precondition(Set(result.items.map(\.id)).count == result.items.count)
        print("PASS: mixed stable IDs, blank rows, malformed-row detection, tags, read-only fixture projection")
        print("items=\(result.items.count), calendar=\(result.calendarEvents?.count ?? 0), sourceRevision=\(result.sourceRevision)")
    }
}
