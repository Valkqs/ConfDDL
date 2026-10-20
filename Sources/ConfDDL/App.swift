import AppKit
import Combine
import SwiftUI
import UserNotifications
import DeadlineCore

@main
struct ConfDDLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var timer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var model: AppModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
            do { try PreviewRenderer.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
            catch { fputs("Preview failed: \(error)\n", stderr) }
            NSApp.terminate(nil)
            return
        }
        model = AppModel()
        UNUserNotificationCenter.current().delegate = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hourglass", accessibilityDescription: "会议截稿倒计时")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        popover.contentSize = NSSize(width: 432, height: 666)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: RootView(model: model))
        model.$archive.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateTitle() }
        }.store(in: &subscriptions)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer?.tolerance = 0.3
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(woke), name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
        updateTitle()
        model.scheduleNotifications()
        model.autoRefreshCatalogIfNeeded()
        if CommandLine.arguments.contains("--show") { showPopover() }
    }

    private func tick() {
        model.now = Date()
        updateTitle()
        // Keep the system's limited notification queue populated on long-running sessions.
        let minute = Int(model.now.timeIntervalSince1970) / 60
        if minute != lastMinute {
            lastMinute = minute; model.scheduleNotifications(); model.autoRefreshCatalogIfNeeded()
        }
    }
    private var lastMinute = Int(Date().timeIntervalSince1970) / 60

    private func updateTitle() {
        guard let conference = model.featured else {
            updateStatusButton(title: " DDL", tooltip: "ConfDDL · 单击查看、添加或导入会议\n右键打开快捷菜单")
            return
        }
        let shortName = conference.name.count > 15 ? String(conference.name.prefix(14)) + "…" : conference.name
        updateStatusButton(title: " \(shortName) · \(Countdown(deadline: conference.deadline, now: model.now).compact)",
            tooltip: "\(conference.name) · \(conference.kind)\n本机：\(dateText(conference.deadline, zone: .current))\n会议：\(dateText(conference.deadline, zone: conference.timeZone)) \(conference.timeZoneLabel)\n单击管理会议 · 右键打开快捷菜单")
    }

    private func updateStatusButton(title: String, tooltip: String) {
        guard let button = statusItem.button else { return }
        if button.title != title { button.title = title }
        // Preserve the native tooltip's hover delay while the countdown timer ticks.
        if button.toolTip != tooltip { button.toolTip = tooltip }
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let openItem = menu.addItem(withTitle: "打开 ConfDDL", action: #selector(openFromMenu), keyEquivalent: "")
            openItem.target = self
            openItem.toolTip = "打开会议倒计时主面板"
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出 ConfDDL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                .toolTip = "退出应用并移除菜单栏入口，保留已保存的数据"
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    @objc private func openFromMenu() { showPopover() }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        model.now = Date()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func woke() {
        model.now = Date(); updateTitle(); model.scheduleNotifications(); model.autoRefreshCatalogIfNeeded()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover(); return false
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse) async {
        await MainActor.run { self.showPopover() }
    }
}
