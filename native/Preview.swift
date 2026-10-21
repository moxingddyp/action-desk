// Local layout QA only; not included in either installed executable.
import SwiftUI
import AppKit

@main
enum LayoutPreview {
    @MainActor static func main() throws {
        let sourceFile = DeskProjection.root.appendingPathComponent("PROJECT.md")
        let sourceBefore = try Data(contentsOf: sourceFile)
        let native = try DeskProjection.build()
        let sourceAfter = try Data(contentsOf: sourceFile)
        precondition(sourceAfter == sourceBefore, "Projection may not write the formal source")
        let snapshot = native
        for a in native.items {
            precondition(!a.categories.isEmpty && Set(a.categories).count == a.categories.count)
            precondition(a.categories.allSatisfy { DeskStore.groups.dropLast().contains($0) })
            precondition(a.targets.allSatisfy { UUID(uuidString: $0.id) != nil })
            for group in a.categories {
                precondition(native.items.filter { $0.belongs(to: group) }.first { $0.id == a.id }?.current == a.current)
            }
        }
        precondition(Set(native.items.map(\.id)).count == native.items.count)
        for group in native.groups { precondition(group.count == native.items.filter { $0.belongs(to: group.name) }.count) }
        precondition((native.calendarEvents ?? []).allSatisfy { DeskCalendar.parse($0.date, "yyyy-MM-dd") != nil })
        precondition(native.sourceRevision == DeskProjection.hash(String(decoding: sourceAfter, as: UTF8.self)))
        let fixture = "## 事项安排\n| 事项ID | 事项/项目 | 分类 | 当前情况 | 下一行动 | 执行主体 | 交付物/依赖 | 真实期限/安排 | 来源 |\n| 0123456789abcdef | 测试 | 正在做、优先做 | 同一进度 | 下一步 | 用户 | 成果 | 合成期限 | 合成证据 |\n"
        let a = DeskProjection.parse(fixture, names: [:], links: [:])
        let b = DeskProjection.parse(fixture.replacingOccurrences(of: "正在做、优先做", with: "条件做"), names: [:], links: [:])
        precondition(a.count == 1 && a[0].belongs(to: "正在做") && a[0].belongs(to: "优先做") && a[0].id == b[0].id)
        precondition(a[0].current == b[0].current && a[0].deadline == b[0].deadline && a[0].output == b[0].output && a[0].targets.map(\.id) == b[0].targets.map(\.id))
        precondition(DeskProjection.parse("## 事项安排\n", names: [:], links: [:]).isEmpty)
        let single = DeskProjection.parse(fixture.replacingOccurrences(of: "正在做、优先做", with: "当前可做"), names: [:], links: [:])
        precondition(single.count == 1 && single[0].categories.count == 1)
        precondition(DeskProjection.daily("## 日常安排\n| 2026-02-30 | | 无效 | | | | | |", links: [:]).isEmpty)
        precondition(DeskProjection.cells(#"| 未归属 | A\|B | 资料 |"#) == ["未归属", "A|B", "资料"])
        precondition(DeskProjection.plain("**[标题](https://example.com)**") == "标题")
        print("Native current-projection invariants passed: \(native.items.count) items, \(native.calendarEvents?.count ?? 0) daily events; sources unchanged")
        precondition(snapshot.generatedDate > Date(timeIntervalSince1970: 1_700_000_000), "Fractional ISO timestamp must parse")
        let rect = CGRect(x: 0, y: 0, width: 268, height: 268)
        for count in 1...34 {
            let slots = RingPosition.slots(count)
            let colors = RingColors.assign(count)
            let regions = RingHitMap.rectangles(count: count, side: 268)
            let centerButton = CGRect(x: 90, y: 90, width: 88, height: 88)
            for a in regions {
                let centerOverlap = a.rect.intersection(centerButton)
                precondition(centerOverlap.isNull || centerOverlap.width < 0.001 || centerOverlap.height < 0.001, "Center button cannot overlap ring controls")
                for b in regions where a.id < b.id {
                    let overlap = a.rect.intersection(b.rect)
                    precondition(overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001, "Archived rectangular controls may not overlap")
                }
            }
            for slot in slots {
                for fraction in [0.2,0.5,0.8] { for inset in [8.0,17.0,26.0] {
                    let angle = (-90 + (Double(slot.index)+fraction)*360/Double(slot.count)) * .pi/180
                    let radius = 134-Double(slot.ring)*36-inset
                    let point = CGPoint(x:134+radius*cos(angle),y:134+radius*sin(angle))
                    let hits = regions.filter { $0.rect.contains(point) }
                    precondition(hits.count == 1 && hits[0].owner == slot.id, "Every tested colored-sector point must reach exactly its own item")
                } }
            }
            precondition(colors.count == count)
            for a in slots { for b in slots where a.id != b.id && RingColors.adjacent(a,b) {
                precondition(RingColors.distinct(colors[a.id],colors[b.id]), "All adjacent sectors must contrast, including the closing seam and both rings")
            } }
            precondition(slots.count == count && Set(slots.map(\.ring)).count <= 2)
            let sectors = slots.map { slot in RingSector(start: -90 + Double(slot.index) * 360 / Double(slot.count), end: -90 + Double(slot.index + 1) * 360 / Double(slot.count), ring: slot.ring).path(in: rect) }
            precondition(sectors.allSatisfy { !$0.contains(CGPoint(x: 134, y: 134)) })
            for slot in slots {
                let angle = (-90 + (Double(slot.index) + 0.5) * 360 / Double(slot.count)) * .pi / 180
                let radius = 117.0 - Double(slot.ring) * 36
                let point = CGPoint(x: 134 + radius * cos(angle), y: 134 + radius * sin(angle))
                precondition(sectors.filter { $0.contains(point) }.count == 1, "Each project label must hit exactly one sector")
                precondition(slot.count == 1 || 2 * radius * sin(.pi / Double(slot.count)) >= 30, "Two digits must retain side margins")
            }
        }
        for count in [4,14,34] {
            let start = Date()
            for _ in 0..<1000 { _ = RingHitMap.rectangles(count: count, side: 268); _ = RingColors.assign(count) }
            print("Cached ring count=\(count), controls=\(RingHitMap.rectangles(count: count, side: 268).count), 1000 lookupsMs=\(Date().timeIntervalSince(start)*1000)")
        }
        var p = DisplayPrefs()
        let known: Set<String> = ["known"]
        p.apply("toggleView", "", knownIDs: known); precondition(p.safeMode == "list")
        p.apply("toggleView", "", knownIDs: known); precondition(p.safeMode == "ring")
        p.apply("select", "known", knownIDs: known); precondition(p.selected == "known")
        p.apply("select", "other", knownIDs: ["known", "other"]); precondition(p.selected == "other")
        p.apply("select", "known", knownIDs: known); precondition(p.selected == "known")
        p.apply("select", "known", knownIDs: known); precondition(p.selected == nil)
        p.apply("select", "unknown", knownIDs: known); precondition(p.selected == nil)
        p.apply("group", "日常", knownIDs: known); precondition(p.safeGroup == "日常")
        p.apply("day", "2026-02-30", knownIDs: known); precondition(p.calendarDay == nil)
        p.apply("day", "2026-10-23", knownIDs: known); precondition(p.calendarDay == "2026-10-23")
        let legacy = try JSONDecoder().decode(DisplayPrefs.self, from: Data("{\"mode\":\"ring\",\"group\":\"今天优先\",\"page\":0}".utf8))
        precondition(legacy.selected == nil)
        precondition(legacy.safeGroup == "优先做")
        print("Native checks passed: timestamp, 1–34 sector hit areas/margins, selection toggle, invalid inputs, legacy preferences")
        if CommandLine.arguments.contains("--check-only") { return }
        guard CommandLine.arguments.count > 1 else { fatalError("Pass an output directory or --check-only") }
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, mode, group, expanded, dark) in [
            ("ring", "ring", "优先做", false, false),
            ("detail", "ring", "优先做", true, false),
            ("dense", "ring", "条件做", false, false),
            ("list-dark", "list", "正在做", false, true),
            ("detail-long", "ring", "当前可做", true, false),
            ("calendar", "ring", "日常", false, false),
            ("calendar-dark", "ring", "日常", false, true),
            ("double-ring", "ring", "测试预览", false, false)
        ] {
            var prefs = DisplayPrefs()
            prefs.mode = mode; prefs.group = group
            if group == "日常" { prefs.calendarMonth = "2030-05"; prefs.calendarDay = "2030-05-20" }
            var sample = snapshot
            if name == "double-ring" {
                sample.items = (1...34).map { n in
                    var item = a[0]; item.id = "preview-\(n)"; item.projects = [String(format: "%04d", n)]; return item
                }
                prefs.group = "优先做"
                for i in sample.items.indices { sample.items[i].tags = ["优先做", "正在做"] }
            }
            sample.groups = DeskStore.groups.dropLast().map { name in WorkGroup(name: name, label: name, count: sample.items.filter { $0.belongs(to: name) }.count) }
            if expanded { prefs.selected = sample.items.first { $0.belongs(to: group) }?.id }
            NSApplication.shared.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let view = DeskWidgetView(entry: DeskEntry(date: .now, snapshot: sample, prefs: prefs))
                .padding(16).frame(width: 344, height: 704)
                .background(Color(nsColor: .windowBackgroundColor))
                .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let renderStart = Date()
            guard let cg = renderer.cgImage else { fatalError("Preview render failed") }
            print("Render \(name) ms=\(Date().timeIntervalSince(renderStart)*1000)")
            let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
            try data.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}
