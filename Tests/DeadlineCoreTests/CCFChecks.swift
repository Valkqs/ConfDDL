import Foundation
import DeadlineCore

enum CCFChecks {
    static let fixture = """
    - title: TEST
      description: Test Conference
      sub: AI
      rank:
        ccf: A
      conference_key: AI/test
      confs:
      - year: 2099
        id: test99
        link: https://example.org
        timezone: AoE
        place: Test city
        timeline:
        - deadline: '2099-10-20 23:59:00'
          abstract_deadline: '2099-10-13 23:59:59'
          comment: Regular round
        - deadline: TBD
          comment: Second round
    """
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func run() throws {
        let catalog = try CCFCatalog.parse(Data(fixture.utf8), now: now)
        try checkEqual(catalog.entries.count, 3)
        let full = try unwrap(catalog.entries.first { $0.kind == "全文截稿" && $0.deadline != nil })
        let deadline = try unwrap(full.deadline)
        let beijing = try unwrap(CCFDate.timeZone("Asia/Shanghai"))
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = beijing
        try checkEqual(calendar.component(.day, from: deadline), 21)
        try checkEqual(calendar.component(.hour, from: deadline), 19)
        try checkEqual(calendar.component(.second, from: deadline), 0)
        try checkEqual(catalog.entries.last?.unavailableReason, "时间待公布")
        try checkNil(catalog.entries.last?.conference(now: now))
        print("PASS CCF catalog: multi-round, abstract, AoE and TBD")

        let winter = try unwrap(CCFDate.parse("2099-01-15 12:00:00", zone: try unwrap(CCFDate.timeZone("PT"))))
        let summer = try unwrap(CCFDate.parse("2099-07-15 12:00:00", zone: try unwrap(CCFDate.timeZone("PT"))))
        calendar.timeZone = .gmt
        try checkEqual(calendar.component(.hour, from: winter), 20)
        try checkEqual(calendar.component(.hour, from: summer), 19)
        try checkEqual(CCFDate.timeZone("UTC+8")?.secondsFromGMT(), 28800)
        try checkEqual(CCFDate.timeZone("UTC-12")?.secondsFromGMT(), -43200)
        try checkEqual(CCFDate.timeZone("UTC+5:30")?.secondsFromGMT(), 19800)
        try checkNil(CCFDate.timeZone("UTC+25"))
        try checkNil(CCFDate.parse("2026-02-30 12:00:00", zone: .gmt))
        try checkNil(CCFDate.parse("2026-03-08 02:30:00", zone: try unwrap(CCFDate.timeZone("PT"))))
        let fixed = try unwrap(CCFDate.parse("2099-07-15 12:00:00", zone: try unwrap(CCFDate.timeZone("UTC-8"))))
        try checkEqual(calendar.component(.hour, from: fixed), 20)
        print("PASS CCF timezone: Pacific DST, fixed offsets and invalid dates")

        var archive = Archive()
        let imported = CatalogMerge.importing(catalog.entries, into: archive, now: now)
        try checkEqual(imported.added, 2)
        let duplicate = CatalogMerge.importing(catalog.entries, into: imported.archive, now: now)
        try checkEqual(duplicate.added, 0)
        try checkEqual(try Archive.decode(duplicate.archive.encoded()), duplicate.archive)
        print("PASS CCF import: skip TBD, deduplicate and persist source")

        archive = imported.archive
        let index = try unwrap(archive.conferences.firstIndex { $0.source?.key == full.id })
        archive.conferences[index].name = "我的自定义名称"
        archive.conferences[index].notes = "自己的投稿计划"
        archive.conferences[index].isPinned = true
        let updatedText = fixture.replacingOccurrences(of: "2099-10-20 23:59:00", with: "2099-10-27 23:59:00")
        let updated = try CCFCatalog.parse(Data(updatedText.utf8), now: now.addingTimeInterval(86400))
        let sync = CatalogMerge.syncing(updated, into: archive)
        try checkEqual(sync.updated, 1)
        try checkEqual(sync.archive.conferences[index].deadline.timeIntervalSince(deadline), 7 * 86400)
        try checkEqual(sync.archive.conferences[index].name, "我的自定义名称")
        try checkEqual(sync.archive.conferences[index].notes, "自己的投稿计划")
        try checkTrue(sync.archive.conferences[index].isPinned)
        try checkEqual(sync.archive.conferences[index].id, archive.conferences[index].id)
        print("PASS CCF sync: reschedule changed dates and preserve user fields")

        archive.conferences[index].source?.followUpdates = false
        let paused = CatalogMerge.syncing(updated, into: archive)
        try checkEqual(paused.updated, 0)
        try checkEqual(paused.archive.conferences[index].deadline, deadline)
        archive.conferences[index].source?.followUpdates = true
        archive.conferences[index].isCompleted = true
        try checkEqual(CatalogMerge.syncing(updated, into: archive).updated, 0)
        archive.conferences[index].isCompleted = false
        let missing = CatalogMerge.syncing(CCFCatalog(entries: [], fetchedAt: now), into: archive)
        try checkEqual(missing.missing, 2)
        try checkEqual(missing.archive.conferences, archive.conferences)
        print("PASS CCF sync: preserve paused, completed and missing entries")

        let reordered = fixture.replacingOccurrences(of: "Regular round", with: "Renamed round")
        let renamed = try CCFCatalog.parse(Data(reordered.utf8))
        try checkTrue(renamed.entries.first?.id != full.id)
        try checkEqual(CatalogMerge.syncing(renamed, into: archive).updated, 0)
        let unnamed = fixture.replacingOccurrences(of: "comment: Regular round", with: "comment: ''")
        let withMoreRounds = unnamed.replacingOccurrences(of: "    - deadline: TBD", with: "    - deadline: '2099-11-02 23:59:59'\n    - deadline: TBD")
        // Inserting a round changes fallback keys rather than pointing an old subscription at another round.
        let fallback = try CCFCatalog.parse(Data(unnamed.utf8))
        let more = try CCFCatalog.parse(Data(withMoreRounds.utf8))
        try checkTrue(more.entries.count > fallback.entries.count)
        try checkTrue(more.entries.first?.id != fallback.entries.first?.id)
        print("PASS CCF source identities: renamed and inserted rounds")

        let legacy = Data("""
        {"version":1,"conferences":[],"preferences":{"notificationsEnabled":false,"reminderHours":[168,24,0]}}
        """.utf8)
        let old = try Archive.decode(legacy)
        try checkTrue(old.preferences.autoSyncEnabled)
        try checkNil(old.ccfLastSync)
        let oldConference = try unwrap(imported.archive.conferences.first)
        var json = try unwrap(JSONSerialization.jsonObject(with: imported.archive.encoded()) as? [String: Any])
        var items = try unwrap(json["conferences"] as? [[String: Any]])
        items[0].removeValue(forKey: "source"); json["conferences"] = items
        let migrated = try Archive.decode(JSONSerialization.data(withJSONObject: json))
        try checkNil(migrated.conferences[0].source)
        try checkEqual(migrated.conferences[0].id, oldConference.id)
        try checkThrows(CCFCatalog.parse(Data("<html>error</html>".utf8)))
        try checkThrows(CCFCatalog.parse(Data("[]".utf8)))
        print("PASS CCF migration: old backups and invalid feeds")
    }
}
