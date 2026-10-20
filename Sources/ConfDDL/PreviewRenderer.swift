import AppKit
import SwiftUI
import DeadlineCore

/// Renders isolated UI fixtures for visual QA without touching the user's conferences.
@MainActor
enum PreviewRenderer {
    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("preview.json")
        defer { try? FileManager.default.removeItem(at: scratch.deletingLastPathComponent()) }
        let now = Date()
        let demo = Conference(name: "示例 · CV Conference", title: "计算机视觉 · 示例日期", deadline: now.addingTimeInterval(10 * 86400 + 5 * 3600), isPinned: true)
        let second = Conference(name: "示例 · ML Conference", title: "机器学习 · 示例日期", deadline: now.addingTimeInterval(28 * 86400))
        let model = AppModel(dataURL: scratch, initialArchive: Archive(conferences: [demo, second]))
        try snapshot(DashboardView(model: model, add: {}, edit: { _ in }, settings: {}), name: "dashboard", in: directory)
        try snapshot(EditorView(model: model, original: demo, dismiss: {}), name: "editor", in: directory)
        try snapshot(SettingsView(model: model, dismiss: {}), name: "settings", in: directory)
        let empty = AppModel(dataURL: scratch, initialArchive: Archive())
        try snapshot(DashboardView(model: empty, add: {}, edit: { _ in }, settings: {}), name: "empty", in: directory)
        if let index = CommandLine.arguments.firstIndex(of: "--ccf-file"), CommandLine.arguments.count > index + 1 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            let catalog = try CCFCatalog.parse(data)
            let catalogModel = AppModel(dataURL: scratch.deletingLastPathComponent().appendingPathComponent("catalog-preview.json"), initialArchive: Archive())
            catalogModel.setPreviewCatalog(catalog.entries)
            try snapshot(CatalogView(model: catalogModel, dismiss: {}), name: "ccfddl-catalog", in: directory)
            if let entry = catalog.entries.filter({ $0.kind == "全文截稿" && ($0.deadline ?? .distantPast) > now }).sorted(by: { $0.deadline! < $1.deadline! }).first {
                guard catalogModel.importCatalogEntries([entry, entry]) == 1,
                      catalogModel.importCatalogEntries([entry]) == 0 else { throw ValidationError("CCFDDL 导入去重校验失败") }
                let original = catalogModel.conferences[0]
                try snapshot(EditorView(model: catalogModel, original: original, dismiss: {}), name: "ccfddl-editor", in: directory)
                var noteEdit = original; noteEdit.notes = "自定义备注"
                guard catalogModel.save(noteEdit), catalogModel.conferences[0].deadline == original.deadline else {
                    throw ValidationError("CCFDDL 编辑校验失败")
                }
                var pausedEdit = catalogModel.conferences[0]
                pausedEdit.deadline = original.deadline.addingTimeInterval(3600); pausedEdit.source?.followUpdates = false
                guard catalogModel.save(pausedEdit), catalogModel.conferences[0].deadline == pausedEdit.deadline else {
                    throw ValidationError("CCFDDL 暂停跟随校验失败")
                }
                pausedEdit.source?.followUpdates = true
                guard catalogModel.save(pausedEdit), catalogModel.conferences[0].deadline == original.deadline else {
                    throw ValidationError("CCFDDL 恢复跟随校验失败")
                }
                _ = try Archive.decode(Data(contentsOf: catalogModel.dataURL))
                print("CCFDDL storage checks passed: import, deduplicate, edit, pause and resume.")
            }
        }
        // Exercise the real persistence and mutation paths in an isolated directory.
        guard model.save(demo), try Archive.decode(Data(contentsOf: scratch)).conferences.count == 2 else {
            throw ValidationError("会议保存校验失败")
        }
        model.complete(demo)
        guard model.featured?.id == second.id else { throw ValidationError("完成与自动切换校验失败") }
        model.complete(model.conferences.first { $0.id == demo.id }!)
        model.pin(second)
        guard model.featured?.id == second.id else { throw ValidationError("固定会议校验失败") }
        model.delete(demo)
        model.setReminder(168, enabled: false)
        let persisted = try Archive.decode(Data(contentsOf: scratch))
        guard persisted.conferences.count == 1, !persisted.preferences.reminderHours.contains(168) else {
            throw ValidationError("删除与提醒偏好保存校验失败")
        }
        print("Storage checks passed; four UI previews rendered.")
    }

    private static func snapshot<V: View>(_ view: V, name: String, in directory: URL) throws {
        let host = NSHostingView(rootView: view.frame(width: 432, height: 666).background(Palette.canvas)
            .tint(Palette.green).environment(\.locale, Locale(identifier: "zh_CN")))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 432, height: 666), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ValidationError("无法创建预览位图") }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw ValidationError("无法编码预览") }
        try data.write(to: directory.appendingPathComponent("\(name).png"))
        window.close()
    }
}
