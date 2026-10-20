import Foundation
import Yams

public struct SourceReference: Codable, Equatable {
    public var key: String
    public var followUpdates: Bool
    public var lastSyncedAt: Date

    public init(key: String, followUpdates: Bool = true, lastSyncedAt: Date = Date()) {
        self.key = key; self.followUpdates = followUpdates; self.lastSyncedAt = lastSyncedAt
    }
}

public struct CatalogEntry: Identifiable, Equatable {
    public var id: String
    public var name: String
    public var title: String
    public var year: Int
    public var category: String
    public var rank: String
    public var kind: String
    public var round: String
    public var deadline: Date?
    public var timeZoneID: String
    public var website: String
    public var place: String
    public var unavailableReason: String?
    public var assumptions: String?

    public func conference(now: Date) -> Conference? {
        guard let deadline else { return nil }
        let details = ["来源：CCFDDL · CCF \(rank) · \(Self.categories[category] ?? category)",
                       round, place, assumptions ?? ""].filter { !$0.isEmpty }.joined(separator: "\n")
        return Conference(name: String(name.prefix(60)), title: String(title.prefix(200)), deadline: deadline,
            timeZoneID: timeZoneID, kind: kind, website: website, notes: String(details.prefix(10000)),
            source: SourceReference(key: id, lastSyncedAt: now))
    }

    public static let categories = ["AI": "人工智能", "CG": "图形学与多媒体", "DB": "数据库与数据挖掘",
        "DS": "体系结构与并行计算", "NW": "计算机网络", "SC": "网络与信息安全", "SE": "软件工程与系统",
        "CT": "计算理论", "HI": "人机交互", "MX": "交叉与新兴领域"]
}

public struct CCFCatalog {
    public var entries: [CatalogEntry]
    public var fetchedAt: Date
    public init(entries: [CatalogEntry], fetchedAt: Date = Date()) {
        self.entries = entries; self.fetchedAt = fetchedAt
    }

    public static func parse(_ data: Data, now: Date = Date()) throws -> CCFCatalog {
        guard data.count <= 5_000_000, let yaml = String(data: data, encoding: .utf8) else {
            throw ValidationError("CCFDDL 数据过大或不是 UTF-8 文本。")
        }
        let conferences: [RemoteConference]
        do { conferences = try YAMLDecoder().decode([RemoteConference].self, from: yaml) }
        catch { throw ValidationError("CCFDDL 数据格式已变化，暂时无法解析。") }
        guard !conferences.isEmpty else { throw ValidationError("CCFDDL 返回了空数据，已保留本地会议。") }
        var entries: [CatalogEntry] = []
        var seen = Set<String>()
        for conference in conferences {
            for edition in conference.confs ?? [] {
                let rounds = edition.timeline ?? []
                for (index, timeline) in rounds.enumerated() {
                    // Prefer a unique round label; otherwise include the round count so an
                    // inserted round cannot silently shift an existing subscription's index.
                    let label = (timeline.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let uniqueLabel = !label.isEmpty && rounds.filter { ($0.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == label }.count == 1
                    let roundKey = uniqueLabel ? "label:\(label)" : "round:\(index):of:\(rounds.count)"
                    let parent = conference.conference_key ?? "\(conference.sub)/\(conference.title.lowercased())"
                    let fields: [(String, String, String?)] = [
                        ("deadline", "全文截稿", timeline.deadline),
                        ("abstract_deadline", "摘要截稿", timeline.abstract_deadline),
                        ("rebuttal_deadline", "Rebuttal", timeline.rebuttal_deadline),
                        ("decision_deadline", "录用通知", timeline.decision_deadline)
                    ]
                    for (field, kind, raw) in fields where raw != nil || field == "deadline" {
                        // Length-prefix components to keep IDs unambiguous even when a label contains '/'.
                        let key = [parent, edition.id, roundKey, field].map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
                        guard seen.insert(key).inserted else { continue }
                        let rawZone = edition.timezone ?? "AoE"
                        let zone = CCFDate.timeZone(rawZone)
                        let date = zone.flatMap { CCFDate.parse(raw ?? "TBD", zone: $0) }
                        let cleanRaw = (raw ?? "TBD").trimmingCharacters(in: .whitespacesAndNewlines)
                        let unpublished = ["TBD", "TBA", "", "N/A"].contains(cleanRaw.uppercased())
                        var assumptions: [String] = []
                        if edition.timezone == nil { assumptions.append("来源未写时区，按 CCFDDL 约定使用 AoE") }
                        if cleanRaw.count == 10 && date != nil { assumptions.append("来源仅给出日期，按 CCFDDL 约定使用 23:59:59") }
                        let reason: String? = date != nil ? nil : unpublished ? "时间待公布" : zone == nil ? "无法识别来源时区" : "来源日期无效"
                        entries.append(CatalogEntry(id: key, name: "\(conference.title) \(edition.year)",
                            title: conference.description ?? "", year: edition.year, category: conference.sub,
                            rank: conference.rank?.ccf ?? "N", kind: kind,
                            round: label.isEmpty && rounds.count > 1 ? "第 \(index + 1) 轮" : label,
                            deadline: date, timeZoneID: zone?.identifier ?? "Etc/GMT+12",
                            website: edition.link ?? "", place: edition.place ?? "", unavailableReason: reason,
                            assumptions: assumptions.isEmpty ? nil : assumptions.joined(separator: "；")))
                    }
                }
            }
        }
        guard !entries.isEmpty else { throw ValidationError("CCFDDL 没有可识别的截稿节点，已保留本地会议。") }
        return CCFCatalog(entries: entries, fetchedAt: now)
    }
}

private struct RemoteConference: Decodable {
    var title: String
    var description: String?
    var sub: String
    var rank: Rank?
    var conference_key: String?
    var confs: [Edition]?
    struct Rank: Decodable { var ccf: String? }
    struct Edition: Decodable {
        var year: Int
        var id: String
        var link: String?
        var timeline: [Timeline]?
        var timezone: String?
        var place: String?
    }
    struct Timeline: Decodable {
        var deadline: String?
        var abstract_deadline: String?
        var rebuttal_deadline: String?
        var decision_deadline: String?
        var comment: String?
    }
}

public enum CCFDate {
    public static func timeZone(_ value: String) -> TimeZone? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch cleaned.uppercased() {
        case "AOE": return TimeZone(identifier: "Etc/GMT+12")
        case "PT": return TimeZone(identifier: "America/Los_Angeles")
        case "UTC", "GMT": return TimeZone(secondsFromGMT: 0)
        default: break
        }
        if let match = cleaned.range(of: #"^UTC([+-])(\d{1,2})(?::(\d{2}))?$"#, options: .regularExpression) {
            let suffix = String(cleaned[match]).dropFirst(3)
            let sign = suffix.first == "-" ? -1 : 1
            let parts = suffix.dropFirst().split(separator: ":")
            guard let hour = Int(parts[0]), hour <= 14,
                  let minute = parts.count == 2 ? Int(parts[1]) : 0, minute < 60,
                  hour < 14 || minute == 0 else { return nil }
            let offset = sign * (hour * 3600 + minute * 60)
            // Prefer IANA names for whole hours so the existing timezone picker can show them.
            if minute == 0, hour != 0 { return TimeZone(identifier: "Etc/GMT\(sign > 0 ? "-" : "+")\(hour)") }
            return TimeZone(secondsFromGMT: offset)
        }
        return TimeZone(identifier: cleaned)
    }

    public static func parse(_ value: String, zone: TimeZone) -> Date? {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil { text += " 23:59:59" }
        guard text.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.isLenient = false
        guard let date = formatter.date(from: text), formatter.string(from: date) == text else { return nil }
        return date
    }
}

public struct CatalogMergeResult {
    public var archive: Archive
    public var added = 0
    public var updated = 0
    public var missing = 0
}

public enum CatalogMerge {
    public static func importing(_ entries: [CatalogEntry], into archive: Archive, now: Date) -> CatalogMergeResult {
        var result = CatalogMergeResult(archive: archive)
        var keys = Set(archive.conferences.compactMap { $0.source?.key })
        for entry in entries {
            guard keys.insert(entry.id).inserted, let conference = entry.conference(now: now) else { continue }
            result.archive.conferences.append(conference)
            result.added += 1
        }
        return result
    }

    public static func syncing(_ catalog: CCFCatalog, into archive: Archive) -> CatalogMergeResult {
        var result = CatalogMergeResult(archive: archive)
        let remote = Dictionary(catalog.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for index in result.archive.conferences.indices {
            var item = result.archive.conferences[index]
            guard var source = item.source, source.followUpdates, !item.isCompleted else { continue }
            guard let entry = remote[source.key], let deadline = entry.deadline else {
                result.missing += 1
                continue // A removed or unpublished remote date never deletes or invents a local DDL.
            }
            if item.deadline != deadline || item.timeZoneID != entry.timeZoneID {
                item.deadline = deadline; item.timeZoneID = entry.timeZoneID
                result.updated += 1
            }
            source.lastSyncedAt = catalog.fetchedAt
            item.source = source
            result.archive.conferences[index] = item
        }
        result.archive.ccfLastSync = catalog.fetchedAt
        return result
    }
}

public enum CCFClient {
    public static let sources = ["https://ccfddl.com/conference/allconf.yml", "https://ccfddl.github.io/conference/allconf.yml"]

    public static func fetch() async throws -> (CCFCatalog, Data) {
        typealias Payload = (CCFCatalog, Data)
        // Race the two official hosts so an unreachable host cannot delay the other.
        let result = await withTaskGroup(of: Result<Payload, Error>.self, returning: Result<Payload, Error>.self) { group in
            for address in sources {
                group.addTask {
                    do {
                        var request = URLRequest(url: URL(string: address)!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 35)
                        request.setValue("ConfDDL/1.1", forHTTPHeaderField: "User-Agent")
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                            throw ValidationError("数据服务器返回异常状态")
                        }
                        try Task.checkCancellation()
                        let catalog = try await Task.detached(priority: .utility) { try CCFCatalog.parse(data) }.value
                        try Task.checkCancellation()
                        return .success((catalog, data))
                    } catch { return .failure(error) }
                }
            }
            var lastError: Error = ValidationError("无法连接 CCFDDL")
            for await result in group {
                switch result {
                case .success: group.cancelAll(); return result
                case .failure(let error): lastError = error
                }
            }
            return .failure(ValidationError("无法更新 CCFDDL，已保留本地数据。\n\(lastError.localizedDescription)"))
        }
        try Task.checkCancellation()
        return try result.get()
    }
}
