import Foundation
import DeadlineCore

final class DeadlineCoreChecks {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCountdownBoundaries() throws {
        try checkEqual(Countdown(deadline: now.addingTimeInterval(90061), now: now).compact, "1天 1时")
        try checkEqual(Countdown(deadline: now.addingTimeInterval(3660), now: now).compact, "1时 1分")
        try checkEqual(Countdown(deadline: now.addingTimeInterval(60), now: now).compact, "1分")
        try checkEqual(Countdown(deadline: now.addingTimeInterval(0.1), now: now).compact, "<1分")
        try checkEqual(Countdown(deadline: now, now: now).compact, "已截稿")
        try checkTrue(Countdown(deadline: now.addingTimeInterval(-100), now: now).isExpired)
    }

    func testPinnedDeadlineAndExpiredFallback() throws {
        let nearest = Conference(name: "Nearest", deadline: now.addingTimeInterval(100))
        var pinned = Conference(name: "Pinned", deadline: now.addingTimeInterval(200), isPinned: true)
        let expired = Conference(name: "Expired", deadline: now.addingTimeInterval(-10), isPinned: true)
        try checkEqual(Conference.featured(in: [nearest, pinned, expired], now: now)?.id, pinned.id)
        pinned.isCompleted = true
        try checkEqual(Conference.featured(in: [nearest, pinned, expired], now: now)?.id, nearest.id)
        try checkNil(Conference.featured(in: [pinned, expired], now: now))
    }

    func testAoEConversionToBeijingCrossesDate() throws {
        let utc = TimeZone(secondsFromGMT: 0)!
        let aoe = TimeZone(identifier: "Etc/GMT+12")!
        let beijing = TimeZone(identifier: "Asia/Shanghai")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let wall = try unwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 23, minute: 59)))
        let instant = try unwrap(DeadlineClock.instant(from: wall, in: aoe))
        calendar.timeZone = beijing
        let result = calendar.dateComponents([.day, .hour, .minute, .second], from: instant)
        try checkEqual(result.day, 21)
        try checkEqual(result.hour, 19)
        try checkEqual(result.minute, 59)
        try checkEqual(result.second, 59)
        let roundTrip = DeadlineClock.wallTime(for: instant, in: aoe)
        try checkEqual(roundTrip.timeIntervalSince(wall), 59)
    }

    func testDSTGapIsRejected() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let skipped = try unwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 2, minute: 30)))
        try checkNil(DeadlineClock.instant(from: skipped, in: TimeZone(identifier: "America/Los_Angeles")!))
    }

    func testDSTUsesCorrectSeasonOffset() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let la = TimeZone(identifier: "America/Los_Angeles")!
        for (month, expectedHour) in [(1, 20), (7, 19)] {
            let wall = try unwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: 15, hour: 12, minute: 0)))
            let instant = try unwrap(DeadlineClock.instant(from: wall, in: la))
            try checkEqual(calendar.component(.hour, from: instant), expectedHour)
        }
    }

    func testArchiveRoundTrip() throws {
        let conference = Conference(name: "会议", deadline: now, notes: "备注", isPinned: true)
        let archive = Archive(conferences: [conference])
        try checkEqual(try Archive.decode(archive.encoded()), archive)
    }

    func testCorruptAndUnsupportedBackupsRejected() throws {
        try checkThrows(try Archive.decode(Data("{}".utf8)))
        var value = Archive()
        value.version = 2
        try checkThrows(try Archive.decode(value.encoded()))
        let conference = Conference(name: "Test", deadline: now)
        value = Archive(conferences: [conference, conference])
        try checkThrows(try Archive.decode(value.encoded()))
        value = Archive(conferences: [Conference(name: " ", deadline: now)])
        try checkThrows(try Archive.decode(value.encoded()))
        value = Archive(conferences: [Conference(name: "Test", deadline: now, timeZoneID: "invalid")])
        try checkThrows(try Archive.decode(value.encoded()))
    }

    func testRemindersIgnoreCompletedPastAndDuplicateOffsets() throws {
        let future = Conference(name: "Future", deadline: now.addingTimeInterval(7200))
        let done = Conference(name: "Done", deadline: now.addingTimeInterval(3600), isCompleted: true)
        let past = Conference(name: "Past", deadline: now.addingTimeInterval(-10))
        let reminders = Reminder.planned(for: [future, done, past], hours: [168, 1, 1, 0], now: now)
        try checkEqual(reminders.count, 2)
        try checkEqual(reminders.map(\.hoursBefore), [1, 0])
        try checkEqual(reminders[0].date, now.addingTimeInterval(3600))
    }

    func testNotificationBudgetKeepsNearestSixty() throws {
        let conferences = (1...100).map { Conference(name: "Meeting \($0)", deadline: now.addingTimeInterval(Double($0) * 3600)) }
        let reminders = Reminder.planned(for: conferences, hours: [0], now: now)
        try checkEqual(reminders.count, 60)
        try checkEqual(reminders.last?.date, now.addingTimeInterval(60 * 3600))
    }
}

struct CheckFailure: Error, CustomStringConvertible { let description: String }
func checkEqual<T: Equatable>(_ lhs: T, _ rhs: T, file: String = #fileID, line: Int = #line) throws {
    guard lhs == rhs else { throw CheckFailure(description: "\(file):\(line) Expected \(rhs), got \(lhs)") }
}
func checkTrue(_ value: Bool, file: String = #fileID, line: Int = #line) throws {
    guard value else { throw CheckFailure(description: "\(file):\(line) Expected true") }
}
func checkNil<T>(_ value: T?, file: String = #fileID, line: Int = #line) throws {
    guard value == nil else { throw CheckFailure(description: "\(file):\(line) Expected nil") }
}
func unwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw CheckFailure(description: "Unexpected nil") }; return value
}
func checkThrows<T>(_ expression: @autoclosure () throws -> T) throws {
    do { _ = try expression() } catch { return }
    throw CheckFailure(description: "Expected an error")
}
@main struct RunChecks {
    static func main() async throws {
        let checks = DeadlineCoreChecks()
        try checks.testCountdownBoundaries()
        print("PASS testCountdownBoundaries")
        try checks.testPinnedDeadlineAndExpiredFallback()
        print("PASS testPinnedDeadlineAndExpiredFallback")
        try checks.testAoEConversionToBeijingCrossesDate()
        print("PASS testAoEConversionToBeijingCrossesDate")
        try checks.testDSTGapIsRejected()
        print("PASS testDSTGapIsRejected")
        try checks.testDSTUsesCorrectSeasonOffset()
        print("PASS testDSTUsesCorrectSeasonOffset")
        try checks.testArchiveRoundTrip()
        print("PASS testArchiveRoundTrip")
        try checks.testCorruptAndUnsupportedBackupsRejected()
        print("PASS testCorruptAndUnsupportedBackupsRejected")
        try checks.testRemindersIgnoreCompletedPastAndDuplicateOffsets()
        print("PASS testRemindersIgnoreCompletedPastAndDuplicateOffsets")
        try checks.testNotificationBudgetKeepsNearestSixty()
        print("PASS testNotificationBudgetKeepsNearestSixty")
        print("All 9 checks passed.")
        try CCFChecks.run()
        if let index = CommandLine.arguments.firstIndex(of: "--ccf-file"), CommandLine.arguments.count > index + 1 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            let live = try CCFCatalog.parse(data)
            try checkTrue(live.entries.count > 1000)
            let upcoming = live.entries.filter { ($0.deadline ?? .distantPast) > Date() }
            try checkTrue(upcoming.count > 10)
            let roundTrip = CatalogMerge.importing(Array(upcoming.prefix(50)), into: Archive(), now: CCFChecks.now)
            _ = try Archive.decode(roundTrip.archive.encoded())
            print("PASS live CCFDDL: \(live.entries.count) nodes; \(upcoming.count) upcoming; 50 imports validated")
        }
        if CommandLine.arguments.contains("--fetch-ccf") {
            let (catalog, _) = try await CCFClient.fetch()
            try checkTrue(catalog.entries.count > 1000)
            print("PASS live URLSession fetch: \(catalog.entries.count) nodes")
        }
    }
}
