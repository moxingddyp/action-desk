import SwiftUI
import AppIntents

extension DeskWidgetView {
    var dailyCalendar: some View {
        DailyCalendarView(events: entry.snapshot?.calendarEvents ?? [], prefs: prefs)
    }
}
struct DailyCalendarView: View {
    var events: [DailyEvent]
    var prefs: DisplayPrefs
    var month: Date { prefs.calendarMonth.flatMap { DeskCalendar.parse($0, "yyyy-MM") } ?? DeskCalendar.calendar.dateInterval(of: .month, for: .now)!.start }
    var monthKey: String { DeskCalendar.format(month, "yyyy-MM") }
    var monthEvents: [DailyEvent] { events.filter { $0.date.hasPrefix(monthKey) }.sorted { ($0.date, $0.time, $0.id) < ($1.date, $1.time, $1.id) } }
    var shownEvents: [DailyEvent] { prefs.calendarDay.map { day in monthEvents.filter { $0.date == day } } ?? monthEvents }
    var offset: Int { (DeskCalendar.calendar.component(.weekday, from: month) + 5) % 7 }
    var dayCount: Int { DeskCalendar.calendar.range(of: .day, in: .month, for: month)!.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(intent: DisplayAction("month", adjacent(-1))) { Image(systemName: "chevron.left").frame(width: 30, height: 30) }
                Spacer()
                Text(DeskCalendar.format(month, "yyyy年M月")).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button(intent: DisplayAction("month", adjacent(1))) { Image(systemName: "chevron.right").frame(width: 30, height: 30) }
            }.foregroundStyle(.primary).buttonStyle(.plain)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary) }
                ForEach(0..<42, id: \.self) { n in
                    let day = n - offset + 1
                    if day > 0 && day <= dayCount {
                        let key = monthKey + String(format: "-%02d", day)
                        let hasEvent = monthEvents.contains { $0.date == key }
                        let selected = prefs.calendarDay == key
                        Button(intent: DisplayAction("day", key)) {
                            VStack(spacing: 2) {
                                Text("\(day)").font(.system(size: 12, weight: key == DeskCalendar.format(.now, "yyyy-MM-dd") ? .bold : .regular)).monospacedDigit()
                                Circle().fill(hasEvent ? freshDaily : .clear).frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity).frame(height: 27)
                            .foregroundStyle(selected ? Color.white : .primary)
                            .background(selected ? freshDaily : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("\(key)，\(hasEvent ? "有安排" : "无安排")")
                    } else { Color.clear.frame(height: 27) }
                }
            }
            HStack {
                Text(prefs.calendarDay ?? "本月日常安排").font(.system(size: 12, weight: .semibold))
                Spacer()
                if prefs.calendarDay != nil { Button("整月", intent: DisplayAction("month", monthKey)).font(.system(size: 11)).buttonStyle(.plain) }
            }
            if shownEvents.isEmpty {
                Text("暂无已记录的日程").font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 12)
            }
            ForEach(Array(shownEvents.dropFirst(min(max(prefs.page, 0), max(0, (shownEvents.count - 1) / 3)) * 3).prefix(3))) { event in
                Link(destination: DeskStore.link("thread", event.thread)) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(event.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Spacer(minLength: 3)
                            Text(event.status).font(.system(size: 9, weight: .medium)).foregroundStyle(event.status == "待确认" ? deskColors[1] : freshDaily)
                        }
                        Text("\(event.date.suffix(5))  \(event.time)").font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        Text(event.place).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6).contentShape(Rectangle()).foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
        }
    }
    func adjacent(_ delta: Int) -> String { DeskCalendar.format(DeskCalendar.calendar.date(byAdding: .month, value: delta, to: month)!, "yyyy-MM") }
}
