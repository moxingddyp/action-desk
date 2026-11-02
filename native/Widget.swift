import SwiftUI
import WidgetKit
import AppKit
import AppIntents
import OSLog

struct DeskEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
    let prefs: DisplayPrefs
}
struct DeskProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeskEntry { DeskEntry(date: .now, snapshot: nil, prefs: DisplayPrefs()) }
    func getSnapshot(in context: Context, completion: @escaping (DeskEntry) -> Void) {
        completion(DeskEntry(date: .now, snapshot: DeskStore.read(), prefs: DeskStore.prefs()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DeskEntry>) -> Void) {
        let start = ProcessInfo.processInfo.systemUptime
        let snapshot = DeskStore.read(), prefs = DeskStore.prefs()
        completion(Timeline(entries: [DeskEntry(date: .now, snapshot: snapshot, prefs: prefs)], policy: .after(.now.addingTimeInterval(900))))
        Logger(subsystem: "local.cxy.actiondesk", category: "interaction").notice("v15 timeline group=\(prefs.safeGroup, privacy: .public) selected=\(prefs.selected ?? "none", privacy: .public) providerMs=\((ProcessInfo.processInfo.systemUptime-start)*1000, privacy: .public)")
    }
}
let deskColors: [Color] = [Color(red: 0.25, green: 0.60, blue: 0.80), Color(red: 0.27, green: 0.65, blue: 0.58), Color(red: 0.48, green: 0.59, blue: 0.78), Color(red: 0.32, green: 0.65, blue: 0.56)]
let freshDaily = Color(red: 0.27, green: 0.63, blue: 0.69)
let ringInk = Color(red: 0.18, green: 0.25, blue: 0.31)
func itemColor(_ item: WorkItem) -> Color { deskColors[DeskStore.groups.firstIndex(of: DeskStore.normalizedGroup(item.group)) ?? 0] }
struct SegmentControlStyle: ButtonStyle {
    var selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? deskColors[0] : .secondary)
            .frame(width: 42, height: 38)
            .background(selected ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .overlay { if configuration.isPressed { RoundedRectangle(cornerRadius: 9).fill(deskColors[0].opacity(0.10)) } }
            .contentShape(Rectangle())
    }
}

// A closed sector gives every ring link a non-overlapping, annular hit area.
struct RingSector: Shape {
    var start: Double
    var end: Double
    var ring = 0
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 - Double(ring) * 36
        var p = Path()
        p.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
        p.addArc(center: c, radius: r - 34, startAngle: .degrees(end), endAngle: .degrees(start), clockwise: true)
        p.closeSubpath()
        return p
    }
}
struct RingPosition: Identifiable {
    var id: Int
    var ring: Int
    var index: Int
    var count: Int
    static func slots(_ total: Int) -> [RingPosition] {
        let n = min(max(0, total), 34)
        let outer = n <= 20 ? n : Int(ceil(Double(n) * 20 / 34))
        let inner = n - outer
        return (0..<n).map { i in
            RingPosition(id: i, ring: i < outer ? 0 : 1, index: i < outer ? i : i - outer, count: i < outer ? outer : inner)
        }
    }
}
struct TaskRing: View {
    var items: [WorkItem]
    var total: Int
    var selected: String?
    var colors: [Color] {
        RingColors.assign(items.count).map { RingColors.color($0) }
    }
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let ringColors = colors
            ZStack {
                Circle().stroke(.primary.opacity(0.045), lineWidth: 34).padding(17)
                ForEach(RingPosition.slots(items.count)) { slot in
                    let item = items[slot.id]
                    let step = 360.0 / Double(slot.count)
                    let sector = RingSector(start: -90 + Double(slot.index) * step, end: -90 + Double(slot.index + 1) * step, ring: slot.ring)
                    let angle = (-90 + (Double(slot.index) + 0.5) * step) * .pi / 180
                    let radius = side / 2 - Double(slot.ring) * 36 - 17
                    Group {
                        sector.fill(ringColors[slot.id])
                            .overlay {
                                Text(item.ringLabel).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                                    .foregroundStyle(ringInk).contentTransition(.identity)
                                    .position(x: side / 2 + radius * cos(angle), y: side / 2 + radius * sin(angle))
                            }
                    }.allowsHitTesting(false).accessibilityHidden(true)
                }
                // One identity-replaced overlay, rather than per-sector fading
                // overlays: the previous selection must not linger after a swap.
                if let selected, let slot = RingPosition.slots(items.count).first(where: { items[$0.id].id == selected }) {
                    let step = 360.0 / Double(slot.count)
                    RingSector(start: -90 + Double(slot.index)*step, end: -90 + Double(slot.index+1)*step, ring: slot.ring)
                        .stroke(ringInk.opacity(0.35), lineWidth: 1)
                        .id("selection-" + selected)
                        .transition(.identity)
                        .animation(nil, value: selected)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                ForEach(RingHitMap.rectangles(count: items.count, side: side)) { region in
                    let item = items[region.owner]
                    Button(intent: DisplayAction("select", item.id)) {
                        Rectangle().fill(Color.black.opacity(0.001))
                            .frame(width: region.rect.width, height: region.rect.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: region.rect.width, height: region.rect.height)
                    .position(x: region.rect.midX, y: region.rect.midY)
                    .accessibilityLabel("\(item.projectLabel)，\(item.title)，展开或收起")
                }
                Link(destination: DeskStore.link("thread", DeskStore.chief)) {
                    Text("\(total)").font(.system(size: 42, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.primary).frame(width: 88, height: 88).contentShape(Circle())
                }.buttonStyle(.plain).accessibilityLabel("全部\(total)项，打开幕僚长")
            }.frame(width: side, height: side)
                .animation(nil, value: selected)
        }
    }
}
struct DeskWidgetView: View {
    let entry: DeskEntry
    var prefs: DisplayPrefs { entry.prefs }
    var items: [WorkItem] { entry.snapshot?.items.filter { $0.belongs(to: prefs.safeGroup) } ?? [] }
    var capacity: Int { prefs.safeGroup == "日常" ? 3 : (prefs.safeMode == "list" ? 7 : 34) }
    var pages: Int {
        let count = prefs.safeGroup == "日常" ? DailyCalendarView(events: entry.snapshot?.calendarEvents ?? [], prefs: prefs).shownEvents.count : items.count
        return max(1, Int(ceil(Double(count) / Double(capacity))))
    }
    var page: Int { min(max(prefs.page, 0), pages - 1) }
    var visibleItems: [WorkItem] { Array(items.dropFirst(page * capacity).prefix(capacity)) }
    var selected: WorkItem? { visibleItems.first { $0.id == prefs.selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            groups
            VStack(alignment: .leading, spacing: 14) {
            if entry.snapshot == nil {
                Spacer()
                Text("打开行动台加载现有工作安排").font(.callout).foregroundStyle(.secondary)
                Link("加载安排", destination: DeskStore.link("refresh", "now"))
                Spacer()
            } else if prefs.safeGroup == "日常" {
                dailyCalendar
                Spacer(minLength: 0)
            } else if prefs.safeMode == "ring" {
                TaskRing(items: visibleItems, total: Set(entry.snapshot?.items.map(\.id) ?? []).count, selected: selected?.id)
                    .frame(width: 268, height: 268).frame(maxWidth: .infinity)
                if let item = selected { detail(item) }
                else {
                    compactRows
                }
                Spacer(minLength: 0)
            } else {
                listRows
                Spacer(minLength: 0)
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .id(prefs.safeGroup == "日常" ? "daily" : prefs.safeMode)
            .transition(.opacity)
            footer
        }
        .containerBackground(for: .widget) { Color(nsColor: .windowBackgroundColor) }
        .privacySensitive()
        .animation(.easeOut(duration: 0.12), value: prefs.safeGroup)
        .animation(.easeOut(duration: 0.14), value: prefs.safeMode)
        .animation(nil, value: prefs.selected)
    }
    var header: some View {
        HStack {
            Text("行动台").font(.system(size: 22, weight: .bold))
            Spacer()
            HStack(spacing: 3) {
                modeToggle("ring", "circle.dotted.circle.fill", "圆环")
                modeToggle("list", "list.bullet", "列表")
            }.padding(3).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    func modeToggle(_ mode: String, _ icon: String, _ name: String) -> some View {
        Toggle(isOn: prefs.safeMode == mode, intent: DisplayAction("view", mode)) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium))
        }.toggleStyle(.button).buttonStyle(SegmentControlStyle(selected: prefs.safeMode == mode))
            .accessibilityLabel(name)
    }
    var groups: some View {
        HStack(spacing: 4) {
            ForEach(Array(((entry.snapshot?.groups ?? []) + [WorkGroup(name: "日常", label: "日常", count: entry.snapshot?.calendarEvents?.count ?? 0)]).enumerated()), id: \.offset) { n, group in
                Button(intent: DisplayAction("group", group.name)) {
                    VStack(spacing: 4) {
                        Text(group.label).font(.system(size: 10, weight: .medium))
                        Text("\(group.count)").font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(group.name == prefs.safeGroup ? (n == 4 ? freshDaily : deskColors[n % 4]) : .secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(group.name == prefs.safeGroup ? (n == 4 ? freshDaily : deskColors[n % 4]).opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }
    var compactRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleItems.prefix(5))) { item in
                Button(intent: DisplayAction("select", item.id)) {
                    HStack(spacing: 8) {
                        Text(item.projectLabel).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(itemColor(item)).frame(width: 34, alignment: .leading)
                        Text(item.title).font(.system(size: 12)).lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
                    }.foregroundStyle(.primary).frame(height: 27).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            if items.isEmpty { Text("暂无该分类事项").font(.callout).foregroundStyle(.secondary) }
        }
    }
    func detail(_ item: WorkItem) -> some View {
        Link(destination: DeskStore.link("thread", item.thread)) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(item.projectLabel).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(itemColor(item))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }
                Text(item.title).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                if !item.next.isEmpty { detailField("下一步", item.next, lines: 3) }
                if !item.current.isEmpty { detailField("进展", item.current, lines: 3) }
                if !item.deadline.isEmpty { detailField("期限／安排", item.deadline, lines: 2) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(13)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle()).foregroundStyle(.primary)
        }.buttonStyle(.plain)
    }
    func detailField(_ label: String, _ value: String, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(lines)
        }
    }
    var listRows: some View {
        VStack(spacing: 0) {
            ForEach(visibleItems) { item in
                Link(destination: DeskStore.link("thread", item.thread)) {
                    HStack(alignment: .top, spacing: 9) {
                        Circle().fill(itemColor(item)).frame(width: 7, height: 7).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(item.next.isEmpty ? item.current : item.next).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(.tertiary).padding(.top, 5)
                    }.foregroundStyle(.primary).padding(.vertical, 10).contentShape(Rectangle())
                }.buttonStyle(.plain)
                if item.id != visibleItems.last?.id { Divider().opacity(0.5) }
            }
            if items.isEmpty { Text("暂无该分类事项").font(.callout).foregroundStyle(.secondary) }
        }
    }
    var footer: some View {
        HStack(spacing: 8) {
            if let snapshot = entry.snapshot {
                Text("更新").font(.system(size: 9))
                Text(snapshot.generatedDate, style: .time).font(.system(size: 9))
            }
            Spacer(minLength: 0)
            if pages > 1 {
                Button(intent: DisplayAction("page", String(max(0, page - 1)))) { Image(systemName: "chevron.left").frame(width: 26, height: 26) }
                Text("\(page + 1)/\(pages)").monospacedDigit()
                Button(intent: DisplayAction("page", String(min(pages - 1, page + 1)))) { Image(systemName: "chevron.right").frame(width: 26, height: 26) }
            }
            Link(destination: DeskStore.link("refresh", "now")) { Image(systemName: "arrow.clockwise").frame(width: 26, height: 26) }
        }.font(.system(size: 11)).foregroundStyle(.secondary).buttonStyle(.plain)
    }
}

#if !DESIGN_PREVIEW && !WORKBENCH_HOST
struct ActionDeskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DeskStore.kind, provider: DeskProvider()) { DeskWidgetView(entry: $0) }
            .configurationDisplayName("CXY 行动台")
            .description("现有工作安排。点击环段展开事项，点击详情进入原线程；圆心打开幕僚长。")
            .supportedFamilies([.systemExtraLargePortrait])
    }
}
@main
struct WorkspaceWidgets: WidgetBundle {
    var body: some Widget { ActionDeskWidget() }
}
#endif
