import Foundation
import Darwin

// Host reads config.json; extension reads only the projection and preferences.
enum DeskConfiguration {
    // Foundation's home can be an extension container. POSIX account home keeps
    // Host and sandboxed Widget on the same explicit home-relative exception.
    static var accountHome: URL {
        guard let account = getpwuid(getuid()), let home = account.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
    }
    static let applicationSupport = accountHome.appendingPathComponent("Library/Application Support/CXY Action Desk OSS", isDirectory: true)
    static var values: [String: String] {
        guard let data = try? Data(contentsOf: applicationSupport.appendingPathComponent("config.json")),
              let result = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return result
    }
    static var root: URL {
        let path = ProcessInfo.processInfo.environment["ACTION_DESK_SOURCE"] ?? values["sourceDirectory"] ?? accountHome.appendingPathComponent("Documents/ActionDesk").path
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    static var chief: String { values["chiefThread"] ?? "00000000-0000-0000-0000-000000000001" }
    static func navigable(_ id: String) -> Bool {
        UUID(uuidString: id) != nil && !id.hasPrefix("00000000-0000-0000-0000-")
    }
}

enum DeskStore {
    // Read-only projection cache, never an independent task database.
    static let directory = DeskConfiguration.applicationSupport
    static let snapshot = directory.appendingPathComponent("widget.json")
    static let preferenceDirectory = directory.appendingPathComponent("Preferences", isDirectory: true)
    static let preferences = preferenceDirectory.appendingPathComponent("display.json")
    static let legacyPreferences = directory.appendingPathComponent("display.json")
    static let kind = "CXYActionDeskOSS"
    static var chief: String { DeskConfiguration.chief }
    static let groups = ["优先做", "正在做", "当前可做", "条件做", "日常"]
    static func normalizedGroup(_ value: String) -> String {
        ["今天优先":"优先做", "近期必做":"正在做", "继续做":"正在做", "等待与决策":"条件做", "可推进":"当前可做"][value] ?? value
    }
    static func link(_ action: String, _ value: String) -> URL {
        var url = URLComponents()
        url.scheme = "cxy-actiondesk-oss"; url.host = action; url.path = "/" + value
        return url.url!
    }
    static func read() -> Snapshot? {
        do {
            let data = try Data(contentsOf: snapshot)
            guard data.count < 2_000_000 else { return nil }
            let value = try JSONDecoder().decode(Snapshot.self, from: data)
            NSLog("CXY projection loaded: %d items", value.items.count)
            return value
        } catch {
            let e = error as NSError
            NSLog("CXY projection read failed: domain=%@ code=%d", e.domain, e.code)
            return nil
        }
    }
    static func prefs() -> DisplayPrefs {
        guard let data = (try? Data(contentsOf: preferences)) ?? (try? Data(contentsOf: legacyPreferences)), let p = try? JSONDecoder().decode(DisplayPrefs.self, from: data) else { return DisplayPrefs() }
        return p
    }
    @discardableResult static func updatePrefs(_ change: (inout DisplayPrefs) -> Void) throws -> Bool {
        try FileManager.default.createDirectory(at: preferenceDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = Darwin.open(preferenceDirectory.appendingPathComponent("display.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        defer { flock(fd, LOCK_UN); Darwin.close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileLocking) }
        var p = prefs()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(p)
        change(&p)
        let after = try encoder.encode(p)
        if before == after && FileManager.default.fileExists(atPath: preferences.path) { return false }
        try after.write(to: preferences, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: preferences.path)
        return true
    }
}

struct Target: Codable { var id: String; var title: String; var project: String }
struct WorkItem: Codable, Identifiable {
    var id: String; var group: String; var groupShort: String; var label: String; var title: String
    var current: String; var next: String; var deadline: String; var output: String
    var projects: [String]; var targets: [Target]
    var owner: String? = nil
    var evidence: String? = nil
    var sourceLine: Int? = nil
    var tags: [String]? = nil
    var categories: [String] { (tags ?? [group]).map(DeskStore.normalizedGroup) }
    func belongs(to category: String) -> Bool { categories.contains(category) }
    var thread: String { targets.first?.id ?? DeskStore.chief }
    var projectLabel: String { projects.first ?? "待定" }
    var ringLabel: String { projects.first.map { String($0.suffix(2)) } ?? "·" }
}
struct WorkGroup: Codable { var name: String; var label: String; var count: Int }
struct Snapshot: Codable {
    var schemaVersion: Int; var generatedAt: String; var revision: String
    var sourceRevision: String; var groups: [WorkGroup]; var items: [WorkItem]
    var calendarEvents: [DailyEvent]? = nil
    var source: String? = nil
    var sourceModifiedAt: String? = nil
    var chiefThread: String? = nil
    var generatedDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: generatedAt) ?? ISO8601DateFormatter().date(from: generatedAt) ?? .distantPast
    }
}
struct DisplayPrefs: Codable {
    var mode = "ring"
    var group = "优先做"
    var page = 0
    var selected: String? = nil
    var calendarMonth: String? = nil
    var calendarDay: String? = nil
    var safeMode: String { mode == "list" ? "list" : "ring" }
    var safeGroup: String { let value = DeskStore.normalizedGroup(group); return DeskStore.groups.contains(value) ? value : DeskStore.groups[0] }
    mutating func apply(_ action: String, _ value: String, knownIDs: Set<String>) {
        switch action {
        case "toggleView": mode = safeMode == "list" ? "ring" : "list"; page = 0; selected = nil
        case "view" where ["ring", "list"].contains(value): mode = value; page = 0; selected = nil
        case "group" where DeskStore.groups.contains(value): group = value; page = 0; selected = nil
        case "page": if let n = Int(value), (0...100).contains(n) { page = n; selected = nil }
        case "select" where knownIDs.contains(value): selected = selected == value ? nil : value
        case "month" where DeskCalendar.parse(value, "yyyy-MM") != nil: calendarMonth = value; calendarDay = nil; page = 0
        case "day" where DeskCalendar.parse(value, "yyyy-MM-dd") != nil: calendarDay = value; page = 0
        default: break
        }
    }
}

struct DailyEvent: Codable, Identifiable {
    var id: String; var date: String; var time: String; var title: String
    var place: String; var status: String; var project: String; var source: String; var note: String; var thread: String
}

enum DeskCalendar {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!; c.firstWeekday = 2
        return c
    }
    static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = pattern
        return f.string(from: date)
    }
    static func parse(_ value: String, _ pattern: String) -> Date? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.dateFormat = pattern; f.isLenient = false
        guard let d = f.date(from: value), f.string(from: d) == value else { return nil }; return d
    }
}
