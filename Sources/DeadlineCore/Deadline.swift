import Foundation

public struct Conference: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var title: String
    public var deadline: Date
    public var timeZoneID: String
    public var kind: String
    public var website: String
    public var notes: String
    public var isPinned: Bool
    public var isCompleted: Bool
    public var source: SourceReference?

    public init(id: UUID = UUID(), name: String, title: String = "", deadline: Date,
                timeZoneID: String = "Etc/GMT+12", kind: String = "全文截稿",
                website: String = "", notes: String = "", isPinned: Bool = false,
                isCompleted: Bool = false, source: SourceReference? = nil) {
        self.id = id; self.name = name; self.title = title; self.deadline = deadline
        self.timeZoneID = timeZoneID; self.kind = kind; self.website = website
        self.notes = notes; self.isPinned = isPinned; self.isCompleted = isCompleted
        self.source = source
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: -43200)! }
    public var timeZoneLabel: String { timeZoneID == "Etc/GMT+12" ? "AoE · UTC−12" : timeZoneID }

    public static func featured(in conferences: [Conference], now: Date) -> Conference? {
        let upcoming = conferences.filter { !$0.isCompleted && $0.deadline > now }
        return upcoming.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.deadline < $1.deadline
        }.first
    }
}

public struct Countdown: Equatable {
    public let seconds: Int
    public init(deadline: Date, now: Date) {
        seconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }
    public var days: Int { seconds / 86400 }
    public var hours: Int { (seconds % 86400) / 3600 }
    public var minutes: Int { (seconds % 3600) / 60 }
    public var isExpired: Bool { seconds == 0 }
    public var compact: String {
        if isExpired { return "已截稿" }
        if days > 0 { return "\(days)天 \(hours)时" }
        if seconds >= 3600 { return "\(hours)时 \(minutes)分" }
        if seconds >= 60 { return "\(minutes)分" }
        return "<1分"
    }
}

public enum DeadlineClock {
    // A UTC date is used as a timezone-neutral wall-clock value by the editor.
    public static func wallTime(for date: Date, in zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: components)!
    }

    public static func instant(from wallTime: Date, in zone: TimeZone) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = utc.dateComponents([.year, .month, .day, .hour, .minute], from: wallTime)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let date = calendar.date(from: components) else { return nil }
        // Reject wall times skipped by daylight saving time instead of silently changing the DDL.
        let roundTrip = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard roundTrip == components else { return nil }
        return date.addingTimeInterval(59)
    }
}

public struct Preferences: Codable, Equatable {
    public var notificationsEnabled = false
    public var reminderHours: [Int] = [168, 72, 24, 1, 0]
    public var ccfAutoSync: Bool?
    public var autoSyncEnabled: Bool { ccfAutoSync ?? true }
    public init() {}
}

public struct Archive: Codable, Equatable {
    public var version: Int = 1
    public var conferences: [Conference]
    public var preferences: Preferences
    public var ccfLastSync: Date?
    public init(conferences: [Conference] = [], preferences: Preferences = Preferences()) {
        self.conferences = conferences; self.preferences = preferences
    }

    public static func decode(_ data: Data) throws -> Archive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(Archive.self, from: data)
        guard archive.version == 1 else { throw ValidationError("不支持此备份的版本。") }
        guard archive.conferences.count <= 2000 else { throw ValidationError("单个备份最多支持 2000 条会议。") }
        guard Set(archive.conferences.map(\.id)).count == archive.conferences.count else {
            throw ValidationError("备份包含重复的会议 ID。")
        }
        for conference in archive.conferences {
            guard !conference.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  conference.name.count <= 60, conference.title.count <= 200,
                  TimeZone(identifier: conference.timeZoneID) != nil,
                  conference.deadline.timeIntervalSince1970.isFinite,
                  conference.website.count <= 2000, conference.notes.count <= 10000 else {
                throw ValidationError("备份包含无效的会议信息。")
            }
            if let source = conference.source {
                guard !source.key.isEmpty, source.key.count <= 4000, source.lastSyncedAt.timeIntervalSince1970.isFinite else {
                    throw ValidationError("备份包含无效的会议来源。")
                }
            }
        }
        guard archive.preferences.reminderHours.allSatisfy({ [168, 72, 24, 1, 0].contains($0) }) else {
            throw ValidationError("备份包含不支持的提醒时间。")
        }
        return archive
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

public struct ValidationError: LocalizedError {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct Reminder: Equatable {
    public var id: String
    public var conferenceName: String
    public var kind: String
    public var date: Date
    public var hoursBefore: Int

    public static func planned(for conferences: [Conference], hours: [Int], now: Date) -> [Reminder] {
        conferences.filter { !$0.isCompleted }.flatMap { conference in
            Set(hours).compactMap { hours -> Reminder? in
                guard hours >= 0 else { return nil }
                let date = conference.deadline.addingTimeInterval(-Double(hours) * 3600)
                guard date > now else { return nil }
                return Reminder(id: "\(conference.id.uuidString)-\(hours)", conferenceName: conference.name,
                                kind: conference.kind, date: date, hoursBefore: hours)
            }
        }.sorted { $0.date < $1.date }.prefix(60).map { $0 }
    }
}
