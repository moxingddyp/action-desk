import Foundation
import CryptoKit

// Native, read-only projection. The Markdown records remain authoritative.
enum DeskProjection {
    static var root: URL { DeskConfiguration.root }
    struct LinkIndex: Decodable { var projects: [String: ThreadLink] }
    struct ThreadLink: Decodable { var id: String; var title: String }
    struct Payload: Encodable { var items: [WorkItem]; var events: [DailyEvent] }
    static func hash(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    static func replace(_ text: String, _ pattern: String, _ template: String) -> String {
        text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
    }
    static func matches(_ text: String, _ pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
    static func plain(_ text: String) -> String {
        replace(text, #"\[([^\]]+)\]\([^)]+\)"#, "$1").replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "**", with: "").replacingOccurrences(of: #"\|"#, with: "|").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func cells(_ text: String) -> [String] {
        let body = text.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        var result = [String](), part = "", previous: Character? = nil
        for ch in body {
            if ch == "|" && previous != "\\" { result.append(plain(part)); part = "" }
            else { part.append(ch) }
            previous = ch
        }
        result.append(plain(part)); return result
    }
    static func stableRead(_ file: URL) throws -> (String, Date) {
        for _ in 0..<3 {
            let a = try FileManager.default.attributesOfItem(atPath: file.path)
            let text = try String(contentsOf: file, encoding: .utf8)
            let b = try FileManager.default.attributesOfItem(atPath: file.path)
            if a[.modificationDate] as? Date == b[.modificationDate] as? Date,
               a[.size] as? Int == b[.size] as? Int { return (text, b[.modificationDate] as? Date ?? .now) }
        }
        throw CocoaError(.fileReadUnknown)
    }
    static func sections(_ text: String) -> [String: [(Int, String)]] {
        var result: [String: [(Int, String)]] = [:], section = ""
        for (n, line) in text.components(separatedBy: .newlines).enumerated() {
            if line.hasPrefix("## ") { section = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces); result[section] = [] }
            else { result[section, default: []].append((n + 1, line)) }
        }
        return result
    }
    static func names(_ index: String) -> [String: String] {
        var result: [String: String] = [:], number = ""
        for line in index.components(separatedBy: .newlines) {
            if line.hasPrefix("## "), let id = matches(line, #"(?<=## )\d{4}(?=-)"#).first { number = id }
            if !number.isEmpty && line.hasPrefix("- 名称：") { result[number] = replace(plain(String(line.dropFirst(5))), #"^\d{4}\s*"#, "") }
        }
        return result
    }
    static func target(_ number: String, _ links: [String: ThreadLink]) -> Target? {
        guard let t = links[number], UUID(uuidString: t.id) != nil else { return nil }
        return Target(id: t.id, title: t.title, project: number)
    }
    static func workRows(_ rows: [(Int, String)]) -> [(Int, String)] {
        rows.filter { _, raw in
            guard raw.hasPrefix("|") else { return false }
            let c = cells(raw)
            if c.allSatisfy({ $0.isEmpty }) || c.first == "事项ID" { return false }
            return !c.allSatisfy { !matches($0, #"^[-: ]+$"#).isEmpty }
        }
    }
    static func validItemID(_ id: String) -> Bool {
        !matches(id, #"^(?:[a-f0-9]{16}|[0-9]{4}-A[0-9]{2,})$"#).isEmpty
    }
    static func parse(_ text: String, names: [String: String], links: [String: ThreadLink]) -> [WorkItem] {
        let all = sections(text)
        if let rows = all["事项安排"] {
            return workRows(rows).compactMap { line, raw in
                guard raw.hasPrefix("|") else { return nil }
                let c = cells(raw)
                guard c.count == 9, validItemID(c[0]) else { return nil }
                let tags = c[2].components(separatedBy: "、")
                guard !tags.isEmpty, tags.allSatisfy({ DeskStore.groups.dropLast().contains($0) }), Set(tags).count == tags.count else { return nil }
                guard tags.filter({ ["正在做", "当前可做", "条件做"].contains($0) }).count == 1 else { return nil }
                let numbers = matches(c[1], #"(?<!\d)\d{4}(?!\d)"#)
                let targets = numbers.compactMap { target($0, links) }
                var item = WorkItem(id: c[0], group: tags[0], groupShort: tags[0], label: c[1], title: names[c[1]] ?? c[1], current: c[3], next: c[4], deadline: c[7], output: c[6], projects: numbers, targets: targets.isEmpty ? [Target(id: DeskStore.chief, title: "幕僚长", project: "0001")] : targets)
                item.owner = c[5]; item.evidence = c[8]; item.sourceLine = line; item.tags = tags
                return item
            }
        }
        var result = [WorkItem]()
        for (group, short) in [("今天优先", "优先"), ("近期必做", "近期"), ("等待与决策", "等待"), ("可推进", "可推进")] {
            let rows = all[group] ?? [], table = (all[group] ?? []).contains { $0.1.hasPrefix("|") }
            for (line, raw) in rows {
                var label = "", current = "", action = "", owner = "", output = "", deadline = "", evidence = ""
                if table {
                    guard raw.hasPrefix("|") else { continue }
                    let c = cells(raw)
                    guard let first = c.first, first != "项目", matches(first, #"^[-: ]+$"#).isEmpty else { continue }
                    label = first
                    if group == "今天优先" && c.count >= 7 {
                        current = c[1]; action = c[2]; owner = c[3]; output = c[4]; deadline = c[5]; evidence = c[6]
                    } else if c.count >= 3 { action = c[1]; output = c[2] }
                    else { continue }
                } else {
                    guard raw.hasPrefix("- ") else { continue }
                    let body = plain(String(raw.dropFirst(2)))
                    if let colon = body.firstIndex(of: "："), body[..<colon].count <= 45 {
                        label = String(body[..<colon]); current = String(body[body.index(after: colon)...])
                    } else { label = String(body.prefix(25)) + (body.count > 25 ? "…" : ""); current = body }
                }
                var numbers = [String]()
                for n in matches(label, #"(?<!\d)\d{4}(?!\d)"#) where !numbers.contains(n) { numbers.append(n) }
                var targets = numbers.compactMap { target($0, links) }
                if targets.isEmpty { targets = [Target(id: DeskStore.chief, title: "幕僚长", project: "0001")] }
                var item = WorkItem(id: String(hash(group + "\0" + label).prefix(16)), group: group, groupShort: short, label: label, title: names[label] ?? label, current: current, next: action, deadline: deadline, output: output, projects: numbers, targets: targets)
                item.owner = owner; item.evidence = evidence; item.sourceLine = line; result.append(item)
            }
        }
        return result
    }
    static func daily(_ text: String, links: [String: ThreadLink]) -> [DailyEvent] {
        (sections(text)["日常安排"] ?? []).compactMap { _, row in
            guard row.hasPrefix("|") else { return nil }
            let c = cells(row)
            guard c.count == 8, DeskCalendar.parse(c[0], "yyyy-MM-dd") != nil else { return nil }
            return DailyEvent(id: String(hash(c[0] + "\0" + c[2]).prefix(16)), date: c[0], time: c[1], title: c[2], place: c[3], status: c[4], project: c[5], source: c[6], note: c[7], thread: target(c[5], links)?.id ?? DeskStore.chief)
        }
    }
    static func build() throws -> Snapshot {
        let (text, modified) = try stableRead(root.appendingPathComponent("PROJECT.md"))
        let (index, _) = try stableRead(root.appendingPathComponent("PROJECTS.md"))
        let linkData = try Data(contentsOf: root.appendingPathComponent("tools/desktop-action-desk/thread-links.json"))
        let links = try JSONDecoder().decode(LinkIndex.self, from: linkData).projects
        let items = parse(text, names: names(index), links: links), events = daily(text, links: links)
        guard items.count < 10000, Set(items.map(\.id)).count == items.count else { throw CocoaError(.fileReadCorruptFile) }
        if sections(text)["事项安排"] != nil {
            let sourceRows = workRows(sections(text)["事项安排"]!)
            guard sourceRows.count == items.count else { throw CocoaError(.fileReadCorruptFile) }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(Payload(items: items, events: events))
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var snapshot = Snapshot(schemaVersion: 1, generatedAt: formatter.string(from: .now), revision: hash(String(decoding: payload, as: UTF8.self)), sourceRevision: hash(text), groups: DeskStore.groups.dropLast().map { name in WorkGroup(name: name, label: name, count: items.filter { $0.belongs(to: name) }.count) }, items: items, calendarEvents: events)
        snapshot.source = root.appendingPathComponent("PROJECT.md").path
        snapshot.sourceModifiedAt = formatter.string(from: modified); snapshot.chiefThread = DeskStore.chief
        snapshot.activityEvidence = Dictionary(uniqueKeysWithValues: (sections(text)["行动活跃依据"] ?? []).compactMap { _, row -> (String, ActivityEvidence)? in
            guard row.hasPrefix("|") else {return nil}
            let values=cells(row)
            guard values.count>=3,validItemID(values[0]) else {return nil}
            return (values[0],ActivityEvidence(lastProgress:values[1],executionState:values[2]))
        })
        return snapshot
    }
}
