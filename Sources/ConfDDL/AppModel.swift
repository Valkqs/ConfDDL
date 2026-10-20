import AppKit
import Combine
import DeadlineCore
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var archive = Archive()
    @Published var now = Date()
    @Published var message: String?
    @Published var notificationStatus = "尚未开启"
    @Published var loginEnabled = false
    @Published private(set) var catalogEntries: [CatalogEntry] = []
    @Published private(set) var catalogFetchedAt: Date?
    @Published private(set) var catalogLoading = false
    @Published private(set) var catalogError: String?
    @Published private(set) var catalogStatus: String?
    @Published var catalogNotice: String?
    private var loadFailed = false
    private let previewMode: Bool
    private var schedulingTask: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private var lastCatalogAttempt: Date?
    private var catalogRequestID: UUID?
    let dataURL: URL

    init(dataURL: URL? = nil, initialArchive: Archive? = nil) {
        previewMode = initialArchive != nil
        self.dataURL = dataURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ConfDDL/deadlines.json")
        do {
            if FileManager.default.fileExists(atPath: self.dataURL.path) {
                archive = try Archive.decode(Data(contentsOf: self.dataURL))
            }
        } catch {
            loadFailed = true
            message = "无法读取本地数据，已暂停写入以保留原文件。\n\(self.dataURL.path)\n\(error.localizedDescription)"
        }
        if let initialArchive { archive = initialArchive }
        refreshLoginStatus()
    }

    var conferences: [Conference] { archive.conferences }
    var featured: Conference? { Conference.featured(in: conferences, now: now) }
    var importedKeys: Set<String> { Set(conferences.compactMap { $0.source?.key }) }
    var catalogCacheURL: URL { dataURL.deletingLastPathComponent().appendingPathComponent("ccfddl-cache.yml") }

    func openCatalog() {
        guard !previewMode else { return }
        if catalogEntries.isEmpty, let data = try? Data(contentsOf: catalogCacheURL),
           let attributes = try? FileManager.default.attributesOfItem(atPath: catalogCacheURL.path),
           let modified = attributes[.modificationDate] as? Date {
            Task {
                if let catalog = try? await Task.detached(priority: .utility, operation: { try CCFCatalog.parse(data, now: modified) }).value,
                   catalogEntries.isEmpty {
                    catalogEntries = catalog.entries; catalogFetchedAt = modified
                }
            }
        }
        if catalogFetchedAt == nil || Date().timeIntervalSince(catalogFetchedAt!) > 3600 { refreshCatalog(manual: false) }
    }

    func cancelCatalogRefresh() {
        catalogTask?.cancel(); catalogRequestID = nil
        catalogLoading = false
    }

    func refreshCatalog(manual: Bool = true) {
        guard !previewMode, !catalogLoading else { return }
        catalogLoading = true; catalogError = nil; catalogStatus = nil
        lastCatalogAttempt = Date()
        let requestID = UUID()
        catalogRequestID = requestID
        catalogTask = Task {
            do {
                let (catalog, data) = try await CCFClient.fetch()
                guard !Task.isCancelled, catalogRequestID == requestID else { return }
                catalogEntries = catalog.entries; catalogFetchedAt = catalog.fetchedAt
                do {
                    try FileManager.default.createDirectory(at: catalogCacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: catalogCacheURL, options: .atomic)
                } catch { catalogError = "目录已更新，但离线缓存保存失败：\(error.localizedDescription)" }
                if manual || archive.preferences.autoSyncEnabled { applyCatalogUpdates(catalog) }
                catalogLoading = false
            } catch {
                guard catalogRequestID == requestID else { return }
                catalogLoading = false
                if !Task.isCancelled { catalogError = error.localizedDescription }
            }
        }
    }

    private func applyCatalogUpdates(_ catalog: CCFCatalog) {
        let result = CatalogMerge.syncing(catalog, into: archive)
        let followed = conferences.filter { $0.source?.followUpdates == true && !$0.isCompleted }.count
        guard followed > 0 else { catalogStatus = "会议目录已更新"; return }
        guard commit(result.archive) else { return }
        catalogStatus = "已检查 \(followed) 条关注 · 更新 \(result.updated) 条"
        if result.missing > 0 { catalogStatus! += " · \(result.missing) 条来源待确认" }
        if result.updated > 0 { catalogNotice = "CCFDDL 更新了 \(result.updated) 条截止时间，相关提醒已重新安排。" }
    }

    func autoRefreshCatalogIfNeeded() {
        guard archive.preferences.autoSyncEnabled,
              conferences.contains(where: { $0.source?.followUpdates == true && !$0.isCompleted }) else { return }
        let last = archive.ccfLastSync ?? .distantPast
        guard Date().timeIntervalSince(last) >= 86400,
              Date().timeIntervalSince(lastCatalogAttempt ?? .distantPast) >= 3600 else { return }
        refreshCatalog(manual: false)
    }

    func setCCFAutoSync(_ enabled: Bool) {
        var next = archive; next.preferences.ccfAutoSync = enabled
        if commit(next), enabled { autoRefreshCatalogIfNeeded() }
    }

    @discardableResult
    func importCatalogEntries(_ entries: [CatalogEntry]) -> Int {
        var result = CatalogMerge.importing(entries, into: archive, now: Date())
        guard result.added > 0 else { return 0 }
        if !archive.conferences.contains(where: { $0.source?.followUpdates == true }) {
            result.archive.ccfLastSync = catalogFetchedAt
        }
        guard commit(result.archive) else { return 0 }
        return result.added
    }

    func sourceIsUnavailable(_ source: SourceReference) -> Bool {
        !catalogEntries.isEmpty && !catalogEntries.contains { $0.id == source.key && $0.deadline != nil }
    }

    func setPreviewCatalog(_ entries: [CatalogEntry]) {
        guard previewMode else { return }
        catalogEntries = entries; catalogFetchedAt = Date()
    }

    @discardableResult
    private func commit(_ next: Archive) -> Bool {
        guard next.conferences.count <= 2000 else {
            message = "最多支持 2000 条会议，请先清理记录或分开备份。"
            return false
        }
        guard !loadFailed else {
            message = "请先修复或移走无法读取的数据文件，再重新启动。\n\(dataURL.path)"
            return false
        }
        do {
            try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try next.encoded().write(to: dataURL, options: .atomic)
            archive = next
            scheduleNotifications()
            return true
        } catch {
            message = "保存失败，修改尚未写入：\(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func save(_ conference: Conference) -> Bool {
        var next = archive
        var conference = conference
        if var source = conference.source, source.followUpdates,
           let remote = catalogEntries.first(where: { $0.id == source.key }), let deadline = remote.deadline {
            conference.deadline = deadline; conference.timeZoneID = remote.timeZoneID; conference.kind = remote.kind
            source.lastSyncedAt = catalogFetchedAt ?? Date(); conference.source = source
        }
        if let index = next.conferences.firstIndex(where: { $0.id == conference.id }) {
            next.conferences[index] = conference
        } else { next.conferences.append(conference) }
        return commit(next)
    }

    func pin(_ conference: Conference) {
        var next = archive
        for index in next.conferences.indices {
            next.conferences[index].isPinned = next.conferences[index].id == conference.id ? !conference.isPinned : false
        }
        commit(next)
    }

    func complete(_ conference: Conference) {
        var edited = conference
        edited.isCompleted.toggle()
        if save(edited), !edited.isCompleted { autoRefreshCatalogIfNeeded() }
    }

    func delete(_ conference: Conference) {
        var next = archive
        next.conferences.removeAll { $0.id == conference.id }
        commit(next)
    }

    func setReminder(_ hour: Int, enabled: Bool) {
        var next = archive
        next.preferences.reminderHours.removeAll { $0 == hour }
        if enabled { next.preferences.reminderHours.append(hour) }
        commit(next)
    }

    func setNotifications(_ enabled: Bool) {
        if !enabled {
            var next = archive; next.preferences.notificationsEnabled = false
            commit(next)
            return
        }
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                if granted {
                    var next = archive; next.preferences.notificationsEnabled = true
                    commit(next)
                } else {
                    message = "通知权限未开启。请在系统设置 → 通知 → ConfDDL 中允许通知，再回来开启提醒。"
                }
                await refreshNotificationStatus()
            } catch { message = "无法启用通知：\(error.localizedDescription)" }
        }
    }

    func refreshNotificationStatus() async {
        guard !previewMode else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: notificationStatus = "系统已允许"
        case .denied: notificationStatus = "系统已关闭，请到系统设置开启"
        case .notDetermined: notificationStatus = "尚未申请通知权限"
        @unknown default: notificationStatus = "未知状态"
        }
    }

    func scheduleNotifications() {
        guard !previewMode else { return }
        let previous = schedulingTask
        previous?.cancel()
        let snapshot = archive
        schedulingTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            guard snapshot.preferences.notificationsEnabled else { return }
            let settings = await center.notificationSettings()
            guard !Task.isCancelled, [.authorized, .provisional].contains(settings.authorizationStatus) else { return }
            let reminders = Reminder.planned(for: snapshot.conferences, hours: snapshot.preferences.reminderHours, now: Date())
            for reminder in reminders {
                guard !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = reminder.hoursBefore == 0 ? "\(reminder.conferenceName) 现在截稿" : "\(reminder.conferenceName) 截稿提醒"
                let lead = reminder.hoursBefore >= 24 ? "\(reminder.hoursBefore / 24) 天" : "\(reminder.hoursBefore) 小时"
                content.body = reminder.hoursBefore == 0 ? "\(reminder.kind)截止时间已到。" : "距离\(reminder.kind)还有 \(lead)，记得预留上传时间。"
                content.sound = .default
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.date)
                components.timeZone = calendar.timeZone
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                do { try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)) }
                catch { message = "系统提醒安排失败：\(error.localizedDescription)" }
            }
        }
    }

    func testNotification() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard [.authorized, .provisional].contains(settings.authorizationStatus) else {
                message = "请先开启截稿提醒并允许系统通知。"; return
            }
            let content = UNMutableNotificationContent()
            content.title = "ConfDDL 提醒已就绪"
            content.body = "会议截稿前，你会在这里收到提醒。"
            content.sound = .default
            do {
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)))
            } catch { message = error.localizedDescription }
        }
    }

    func refreshLoginStatus() {
        guard !previewMode else { return }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLoginStatus()
            if SMAppService.mainApp.status == .requiresApproval {
                message = "请在系统设置 → 通用 → 登录项与扩展中允许 ConfDDL。"
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch { message = "无法修改登录启动设置：\(error.localizedDescription)"; refreshLoginStatus() }
    }

    func exportBackup() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ConfDDL-backup.json"
        panel.title = "导出会议备份"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try archive.encoded().write(to: url, options: .atomic) }
        catch { message = "导出失败：\(error.localizedDescription)" }
    }

    func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.title = "导入 ConfDDL 备份"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) < 10_000_000 else { throw ValidationError("备份文件超过 10 MB。") }
            let imported = try Archive.decode(Data(contentsOf: url))
            let alert = NSAlert()
            alert.messageText = "导入 \(imported.conferences.count) 条会议？"
            alert.informativeText = "新会议将合并到列表，相同 ID 的会议将被更新。当前通知设置保持不变。"
            alert.addButton(withTitle: "导入").toolTip = "合并备份中的会议，相同 ID 的记录会更新"
            alert.addButton(withTitle: "取消").toolTip = "取消导入，保留当前会议信息"
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            var next = archive
            for conference in imported.conferences {
                if let index = next.conferences.firstIndex(where: { $0.id == conference.id }) { next.conferences[index] = conference }
                else { next.conferences.append(conference) }
            }
            commit(next)
        } catch { message = "导入失败：\(error.localizedDescription)" }
    }

    func openWebsite(_ value: String) {
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return }
        NSWorkspace.shared.open(url)
    }

    func addExamples() {
        let names = [("示例 · 视觉会议", "仅供体验，请替换为官方日期", 10), ("示例 · 学习会议", "仅供体验，请替换为官方日期", 28)]
        var next = archive
        for (name, title, days) in names {
            next.conferences.append(Conference(name: name, title: title, deadline: Date().addingTimeInterval(Double(days) * 86400)))
        }
        commit(next)
    }
}
