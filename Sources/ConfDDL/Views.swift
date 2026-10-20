import AppKit
import SwiftUI
import DeadlineCore

enum Palette {
    static let green = Color(red: 0.10, green: 0.49, blue: 0.38)
    static let mint = Color(red: 0.88, green: 0.95, blue: 0.91)
    static let ink = Color.primary
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static func urgency(_ date: Date, now: Date) -> Color {
        let seconds = date.timeIntervalSince(now)
        if seconds <= 86400 { return .orange }
        if seconds <= 3 * 86400 { return Color(red: 0.72, green: 0.49, blue: 0.13) }
        return green
    }
}

func dateText(_ date: Date, zone: TimeZone, pattern: String = "yyyy/MM/dd HH:mm") -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.timeZone = zone
    formatter.dateFormat = pattern
    return formatter.string(from: date)
}

struct RootView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0
    @State private var editing: Conference?
    @State private var creating = false

    var body: some View {
        Group {
            if creating || editing != nil {
                EditorView(model: model, original: editing) { creating = false; editing = nil }
            } else if page == 1 {
                SettingsView(model: model) { page = 0 }
            } else if page == 2 {
                CatalogView(model: model) { page = 0 }
            } else {
                DashboardView(model: model, add: { creating = true }, edit: { editing = $0 }, settings: { page = 1 }, browse: { page = 2 })
            }
        }
        .frame(width: 432, height: 666)
        .background(Palette.canvas)
        .tint(Palette.green)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .alert("ConfDDL", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("知道了") { model.message = nil }.help("关闭这条提示，返回当前页面")
        } message: { Text(model.message ?? "") }
    }
}

struct DashboardView: View {
    @ObservedObject var model: AppModel
    let add: () -> Void
    let edit: (Conference) -> Void
    let settings: () -> Void
    var browse: () -> Void = {}
    @State private var filter = 0
    @State private var search = ""
    @State private var deletion: Conference?

    var visible: [Conference] {
        model.conferences.filter { item in
            let matches = filter == 0 ? !item.isCompleted && item.deadline > model.now
                : filter == 1 ? !item.isCompleted && item.deadline <= model.now : item.isCompleted
            return matches && (search.isEmpty || "\(item.name) \(item.title) \(item.notes)".localizedCaseInsensitiveContains(search))
        }.sorted { filter == 0 ? $0.deadline < $1.deadline : $0.deadline > $1.deadline }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.green).frame(width: 36, height: 36)
                    Image(systemName: "hourglass").font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("ConfDDL").font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("把精力留给研究").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
                Button(action: browse) { Image(systemName: "globe").frame(width: 27, height: 30) }
                    .buttonStyle(.plain).foregroundColor(Palette.green).help("打开 CCFDDL 会议库，搜索并选择要导入的截稿节点").accessibilityLabel("从 CCFDDL 导入")
                Button(action: add) { Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).frame(width: 30, height: 30) }
                    .buttonStyle(.plain).background(Palette.card, in: RoundedRectangle(cornerRadius: 9)).help("手动添加会议，填写截稿日期和时区（⌘N）")
                    .accessibilityLabel("添加会议").keyboardShortcut("n")
                Button(action: settings) { Image(systemName: "gearshape").frame(width: 28, height: 30) }
                    .buttonStyle(.plain).foregroundColor(.secondary).help("设置系统提醒、自动更新、登录启动及数据备份").accessibilityLabel("设置")
            }.padding(.horizontal, 22).padding(.top, 21).padding(.bottom, 18)

            if let conference = model.featured {
                HeroCard(conference: conference, now: model.now, edit: { edit(conference) })
                    .padding(.horizontal, 20).padding(.bottom, 18)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Label("留一点从容，给下一个截稿日", systemImage: "sparkles").font(.system(size: 14, weight: .semibold))
                    Text("从会议库选择，或手动添加你的截稿日。").font(.system(size: 12)).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button("从 CCFDDL 导入", action: browse).buttonStyle(.borderedProminent)
                            .help("从公开会议库选择截稿节点，自动填入日期与时区")
                        Button("手动添加", action: add).buttonStyle(.link).font(.system(size: 11))
                            .help("自行填写会议名称、截稿日期、时区与备注")
                    }.padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
                    .background(Palette.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20).padding(.bottom, 18)
            }

            if let notice = model.catalogNotice {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(notice).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { model.catalogNotice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                        .help("收起本次改期提示，已更新的会议时间会保留").accessibilityLabel("关闭更新提示")
                }.font(.system(size: 10)).foregroundColor(Palette.green).padding(10)
                    .background(Palette.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 20).padding(.bottom, 10)
            }
            HStack(spacing: 5) {
                filterButton("待截稿", count: model.conferences.filter { !$0.isCompleted && $0.deadline > model.now }.count, value: 0)
                filterButton("已截稿", count: model.conferences.filter { !$0.isCompleted && $0.deadline <= model.now }.count, value: 1)
                filterButton("已完成", count: model.conferences.filter(\.isCompleted).count, value: 2)
                Spacer(minLength: 0)
            }.padding(.horizontal, 20)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索会议", text: $search).textFieldStyle(.plain).font(.system(size: 12))
                    .help("在当前分类中按会议名称、全称或备注搜索")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundColor(.secondary)
                        .help("清空搜索，显示当前分类中的全部会议").accessibilityLabel("清空搜索")
                }
            }.padding(10).background(Palette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 9))
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if visible.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: search.isEmpty ? "tray" : "magnifyingglass").font(.system(size: 25, weight: .light)).foregroundColor(Palette.green.opacity(0.7))
                            Text(search.isEmpty ? (filter == 0 ? "还没有待截稿的会议" : filter == 1 ? "没有已截稿的会议" : "完成投稿后，在这里回顾") : "没有找到相关会议")
                                .font(.system(size: 12)).foregroundColor(.secondary)
                            if model.conferences.isEmpty && search.isEmpty {
                                Button("载入示例，体验一下") { model.addExamples() }.buttonStyle(.link).font(.system(size: 11))
                                    .help("添加两条演示会议；示例日期不代表真实会议截稿日")
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 30)
                    }
                    ForEach(visible) { conference in
                        ConferenceRow(conference: conference, now: model.now, edit: { edit(conference) }, pin: { model.pin(conference) },
                                      complete: { model.complete(conference) }, delete: { deletion = conference }, website: { model.openWebsite(conference.website) })
                    }
                }.padding(.horizontal, 20).padding(.vertical, 4)
            }
            Spacer(minLength: 0)
            HStack {
                Circle().fill(Palette.green).frame(width: 5, height: 5)
                Text("本地保存 · \(TimeZone.current.identifier)").font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.secondary)
                    .help("退出 ConfDDL 并移除菜单栏入口；已保存的数据会保留")
            }.padding(.horizontal, 22).padding(.vertical, 13).background(Palette.card.opacity(0.35))
        }
        .alert("删除这条会议？", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("取消", role: .cancel) { deletion = nil }.help("保留会议及其提醒，返回列表")
            Button("删除", role: .destructive) { if let deletion { model.delete(deletion) }; deletion = nil }
                .help("删除这条会议，并取消其待发送提醒")
        } message: { Text("“\(deletion?.name ?? "")”及其提醒将被移除。") }
    }

    func filterButton(_ title: String, count: Int, value: Int) -> some View {
        Button { filter = value } label: {
            HStack(spacing: 5) {
                Text(title).fontWeight(filter == value ? .semibold : .regular)
                Text("\(count)").font(.system(size: 10, weight: .medium, design: .rounded))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(filter == value ? Palette.green.opacity(0.12) : Color.secondary.opacity(0.08), in: Capsule())
            }.font(.system(size: 12)).padding(.horizontal, 9).padding(.vertical, 7)
                .foregroundColor(filter == value ? Palette.green : .secondary)
                .background(filter == value ? Palette.green.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
            .help(value == 0 ? "查看尚未截止且未完成的会议" : value == 1 ? "查看已经超过截止时间、仍未标记完成的会议" : "查看已标记完成的会议，可通过会议操作恢复为待办")
    }
}

struct HeroCard: View {
    let conference: Conference
    let now: Date
    let edit: () -> Void
    var countdown: Countdown { Countdown(deadline: conference.deadline, now: now) }

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label(conference.isPinned ? "已固定在菜单栏" : "下一个截稿日", systemImage: conference.isPinned ? "pin.fill" : "circle.dotted")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.72))
                    Spacer()
                    Text(conference.kind).font(.system(size: 10)).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                Text(conference.name).font(.system(size: 25, weight: .bold, design: .rounded)).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    timeUnit(countdown.days, "天")
                    Text(":").font(.system(size: 24, weight: .light)).foregroundColor(.white.opacity(0.35))
                    timeUnit(countdown.hours, "时")
                    Text(":").font(.system(size: 24, weight: .light)).foregroundColor(.white.opacity(0.35))
                    timeUnit(countdown.minutes, "分")
                    Spacer(minLength: 0)
                }.monospacedDigit()
                HStack(spacing: 5) {
                    Image(systemName: "globe.asia.australia")
                    Text("\(dateText(conference.deadline, zone: .current, pattern: "M月d日 HH:mm")) 本机时间")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.system(size: 11)).foregroundColor(.white.opacity(0.75))
            }.padding(20).foregroundColor(.white)
                .background(LinearGradient(colors: [Palette.green, Color(red: 0.08, green: 0.34, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).help("编辑 \(conference.name) 的截稿时间、时区、官网与备注")
    }

    func timeUnit(_ value: Int, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String(format: "%02d", value)).font(.system(size: 34, weight: .medium, design: .rounded))
            Text(unit).font(.system(size: 11)).foregroundColor(.white.opacity(0.65))
        }
    }
}

struct ConferenceRow: View {
    let conference: Conference
    let now: Date
    let edit: () -> Void
    let pin: () -> Void
    let complete: () -> Void
    let delete: () -> Void
    let website: () -> Void
    var color: Color { conference.isCompleted || conference.deadline <= now ? .secondary : Palette.urgency(conference.deadline, now: now) }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.65)).frame(width: 3, height: 46).padding(.top, 2)
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Text(conference.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        if conference.isPinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundColor(Palette.green) }
                    }
                    Text("\(dateText(conference.deadline, zone: .current, pattern: "MM/dd HH:mm")) · \(conference.kind)\(conference.source == nil ? "" : " · CCF")")
                        .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    if !conference.title.isEmpty {
                        Text(conference.title).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("编辑 \(conference.name) 的会议信息与截稿时间")
            VStack(alignment: .trailing, spacing: 7) {
                Text(conference.isCompleted ? "已完成" : Countdown(deadline: conference.deadline, now: now).compact)
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit().foregroundColor(color)
                Menu {
                    Button("编辑会议", action: edit).help("修改会议名称、截稿时间、时区或备注")
                    if !conference.isCompleted && conference.deadline > now {
                        Button(conference.isPinned ? "取消菜单栏固定" : "固定到菜单栏", action: pin)
                            .help(conference.isPinned ? "恢复在菜单栏显示最近截稿的会议" : "优先在菜单栏显示此会议的倒计时，直到完成或截稿")
                    }
                    Button(conference.isCompleted ? "恢复为待办" : "标记已完成", action: complete)
                        .help(conference.isCompleted ? "移回待办列表；尚未截稿时恢复倒计时与提醒" : "移入已完成列表，停止此会议的倒计时与提醒")
                    if !conference.website.isEmpty {
                        Button("打开会议网站", action: website).help("在默认浏览器中打开此会议的官网")
                    }
                    Divider()
                    Button("删除会议…", role: .destructive, action: delete).help("确认后删除此会议及其提醒")
                } label: { Image(systemName: "ellipsis").frame(width: 22, height: 16) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("打开会议操作：编辑、固定到菜单栏、标记完成、打开官网或删除")
                    .accessibilityLabel("\(conference.name)的操作")
            }
        }.padding(13).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PageHeader: View {
    let title: String
    let back: () -> Void
    var body: some View {
        HStack {
            Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold)).frame(width: 26, height: 30) }
                .buttonStyle(.plain).help("返回会议主面板；编辑内容未保存时会提示确认").accessibilityLabel("返回主面板")
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
        }.padding(.horizontal, 18).padding(.vertical, 17)
    }
}

struct EditorView: View {
    @ObservedObject var model: AppModel
    let original: Conference?
    let dismiss: () -> Void
    @State private var name = ""
    @State private var title = ""
    @State private var wallDate = Date()
    @State private var zoneID = "Etc/GMT+12"
    @State private var kind = "全文截稿"
    @State private var website = ""
    @State private var notes = ""
    @State private var error: String?
    @State private var initialized = false
    @State private var discardConfirmation = false
    @State private var baseline: Draft?
    @State private var followUpdates = true

    struct Draft: Equatable {
        var name: String; var title: String; var wallDate: Date; var zoneID: String
        var kind: String; var website: String; var notes: String; var followUpdates: Bool
    }
    var draft: Draft { Draft(name: name, title: title, wallDate: wallDate, zoneID: zoneID, kind: kind, website: website, notes: notes, followUpdates: followUpdates) }
    var zone: TimeZone { TimeZone(identifier: zoneID) ?? TimeZone(secondsFromGMT: -43200)! }
    var instant: Date? {
        if let original, zoneID == original.timeZoneID {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let originalWall = DeadlineClock.wallTime(for: original.deadline, in: original.timeZone)
            if calendar.isDate(originalWall, equalTo: wallDate, toGranularity: .minute) {
                return original.deadline // Editing notes must not round an imported :00 deadline to :59.
            }
        }
        return DeadlineClock.instant(from: wallDate, in: zone)
    }
    let commonZones = ["Etc/GMT+12", "Asia/Shanghai", "UTC", "America/Los_Angeles", "America/New_York", "Europe/London", "Europe/Paris", "Asia/Tokyo"]

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: original == nil ? "添加会议" : "编辑会议") {
                if let baseline, baseline != draft { discardConfirmation = true } else { dismiss() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    field("会议名称 *") {
                        TextField("例如：ICLR 2027", text: $name).textFieldStyle(.roundedBorder).help("填写显示在列表和菜单栏中的会议名称，最多 60 个字符")
                    }
                    field("会议全称 / 研究方向") {
                        TextField("可选", text: $title).textFieldStyle(.roundedBorder).help("可选：补充会议全称或研究方向，方便搜索和辨认")
                    }
                    field("截稿类型") {
                        Picker("截稿类型", selection: $kind) {
                            ForEach(["摘要截稿", "全文截稿", "补充材料", "Rebuttal", "录用通知", "Camera-ready", "其他"], id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                            .help("选择这条倒计时对应的节点，例如摘要截止、全文截止或 Rebuttal")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("截止时间").font(.system(size: 12, weight: .semibold))
                        DatePicker("会议当地日期", selection: $wallDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.field).labelsHidden().environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                            .help("按下方所选时区填写当地截止日期和时间，本机时间会自动换算")
                        Picker("时区", selection: $zoneID) {
                            ForEach(commonZones, id: \.self) { Text($0 == "Etc/GMT+12" ? "AoE（Anywhere on Earth · UTC−12）" : $0).tag($0) }
                            Divider()
                            ForEach(TimeZone.knownTimeZoneIdentifiers.filter { !commonZones.contains($0) }, id: \.self) { Text($0).tag($0) }
                            if !commonZones.contains(zoneID) && !TimeZone.knownTimeZoneIdentifiers.contains(zoneID) { Text(zoneID).tag(zoneID) }
                        }.font(.system(size: 12)).help("选择会议截止时间使用的时区；AoE 为 UTC−12，比北京时间慢 20 小时")
                        if let instant {
                            Label("本机：\(dateText(instant, zone: .current))", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium)).foregroundColor(Palette.green)
                            if instant <= model.now {
                                Text("此时间已过去，保存后会放入“已截稿”。").font(.system(size: 10)).foregroundColor(.orange)
                            }
                        } else { Text("该时间因夏令时切换不存在，请调整。").font(.system(size: 11)).foregroundColor(.red) }
                        Text(original?.source == nil ? "按所选时区输入，精确到该分钟的第 59 秒。AoE 是 UTC−12；北京时间比它快 20 小时。" : "导入时保留来源的秒数；手动修改时间后使用该分钟第 59 秒，并暂停自动更新时间。")
                            .font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(14).background(Palette.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    if let source = original?.source {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("跟随 CCFDDL 更新截止时间", isOn: $followUpdates).toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                                .help("开启后跟随来源改期；关闭后保留此会议的手动时间。此设置随“保存会议”生效")
                            Text(followUpdates ? "保存后以来源时间为准，名称和备注可自行保留。" : "已暂停此条的自动更新，手动日期将被保留。")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                            if model.sourceIsUnavailable(source) {
                                Text("来源节点待确认，已保留上次时间，请核对官网。").font(.system(size: 10)).foregroundColor(.orange)
                            }
                        }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                    }
                    field("会议官网") {
                        TextField("https://…（可选）", text: $website).textFieldStyle(.roundedBorder).help("可选：填写完整的 http:// 或 https:// 网址，保存后可从会议操作中打开")
                    }
                    field("备注") {
                        TextEditor(text: $notes).font(.system(size: 12)).frame(height: 62).padding(5)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 7))
                            .help("记录投稿计划、轮次说明或需要注意的事项")
                    }
                    if let error { Text(error).font(.system(size: 11)).foregroundColor(.red) }
                }.padding(.horizontal, 22).padding(.bottom, 16)
            }
            HStack {
                Text("请以会议官网的截稿时间为准").font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
                Button("保存会议", action: save).buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                    .help("保存会议信息并更新对应提醒，随后返回主面板（回车）")
            }.padding(18)
        }.onAppear(perform: initialize)
            .onChange(of: wallDate) { value in if original?.source != nil, let baseline, baseline.wallDate != value { followUpdates = false } }
            .onChange(of: zoneID) { value in if original?.source != nil, let baseline, baseline.zoneID != value { followUpdates = false } }
            .onChange(of: kind) { value in if original?.source != nil, let baseline, baseline.kind != value { followUpdates = false } }
            .alert("放弃未保存的修改？", isPresented: $discardConfirmation) {
                Button("继续编辑", role: .cancel) {}.help("保留当前输入，继续编辑这条会议")
                Button("放弃修改", role: .destructive, action: dismiss).help("丢弃本次未保存的修改，返回主面板")
            }
    }

    func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            content()
        }
    }

    func initialize() {
        guard !initialized else { return }
        initialized = true
        if let original {
            name = original.name; title = original.title; zoneID = original.timeZoneID
            kind = original.kind; website = original.website; notes = original.notes
            followUpdates = original.source?.followUpdates ?? true
            wallDate = DeadlineClock.wallTime(for: original.deadline, in: original.timeZone)
        } else {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let date = DeadlineClock.wallTime(for: Date().addingTimeInterval(14 * 86400), in: zone)
            wallDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
        }
        baseline = draft
    }

    func save() {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 60 else { error = "请输入会议名称，最多 60 个字符。"; return }
        guard title.count <= 200, notes.count <= 10000, website.count <= 2000 else { error = "全称最多 200 字，备注最多 10000 字，网址最多 2000 字。"; return }
        let link = website.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.isEmpty {
            guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
                error = "请输入以 https:// 或 http:// 开头的有效网址。"; return
            }
        }
        guard let deadline = instant else { error = "所选时区内不存在这一时间，请调整日期。"; return }
        var source = original?.source
        source?.followUpdates = followUpdates
        let value = Conference(id: original?.id ?? UUID(), name: cleaned, title: title, deadline: deadline,
            timeZoneID: zoneID, kind: kind, website: link, notes: notes,
            isPinned: original?.isPinned ?? false, isCompleted: original?.isCompleted ?? false, source: source)
        if model.save(value) { dismiss() }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let dismiss: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "设置", back: dismiss)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("CCFDDL 会议来源", icon: "globe") {
                        Toggle("每天自动检查关注会议的改期", isOn: Binding(get: { model.archive.preferences.autoSyncEnabled }, set: model.setCCFAutoSync))
                            .toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                            .help("应用运行时每天检查已关注节点的改期；关闭后仍可手动立即更新")
                        Text("从主面板的地球按钮导入会议。应用运行时每日更新；手动修改日期会暂停该条的跟随更新。")
                            .font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(model.catalogLoading ? "更新中…" : "立即更新目录与关注") { model.refreshCatalog() }.disabled(model.catalogLoading)
                                .help(model.catalogLoading ? "正在下载并检查 CCFDDL 数据，请稍候" : "立即下载最新会议目录，并更新允许跟随的会议时间与提醒")
                            Spacer()
                            Button("CCFDDL 网站") { model.openWebsite("https://ccfddl.com") }.buttonStyle(.link)
                                .help("在默认浏览器中打开 CCFDDL 网站")
                        }.font(.system(size: 11))
                        if let last = model.archive.ccfLastSync {
                            Text("上次检查：\(dateText(last, zone: .current))").font(.system(size: 10)).foregroundColor(.secondary)
                        }
                        if let status = model.catalogStatus { Text(status).font(.system(size: 10)).foregroundColor(Palette.green) }
                        if let error = model.catalogError { Text(error).font(.system(size: 10)).foregroundColor(.orange) }
                    }
                    section("截稿提醒", icon: "bell.badge") {
                        Toggle("开启系统通知", isOn: Binding(get: { model.archive.preferences.notificationsEnabled }, set: model.setNotifications))
                            .toggleStyle(.switch).controlSize(.small)
                            .help("开启或关闭截稿系统通知；首次开启需要允许 macOS 通知权限")
                        Text(model.notificationStatus).font(.system(size: 10)).foregroundColor(.secondary)
                        Divider().padding(.vertical, 4)
                        ForEach([168, 72, 24, 1, 0], id: \.self) { hour in
                            Toggle(hour == 0 ? "截止时" : hour >= 24 ? "提前 \(hour / 24) 天" : "提前 1 小时",
                                   isOn: Binding(get: { model.archive.preferences.reminderHours.contains(hour) }, set: { model.setReminder(hour, enabled: $0) }))
                                .toggleStyle(.checkbox).font(.system(size: 12))
                                .help(hour == 0 ? "启用截止时刻的提醒，需先开启系统通知" : "启用提前 \(hour >= 24 ? "\(hour / 24) 天" : "1 小时")的提醒，需先开启系统通知")
                        }
                        HStack {
                            Button("发送测试通知") { model.testNotification() }.disabled(!model.archive.preferences.notificationsEnabled)
                                .help(model.archive.preferences.notificationsEnabled ? "约 3 秒后发送一条测试通知，检查提醒是否正常" : "请先开启系统通知，再发送测试提醒")
                            Spacer()
                            Button("系统通知设置") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                            }.buttonStyle(.link).help("打开 macOS 通知设置，检查 ConfDDL 的通知权限与显示方式")
                        }.font(.system(size: 11)).padding(.top, 6)
                        Text("系统安排最近的 60 条提醒，运行及唤醒时自动补充。关机期间无法提醒；专注模式可能静音通知。")
                            .font(.system(size: 10)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    section("启动与菜单栏", icon: "menubar.rectangle") {
                        Toggle("登录时启动", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin)).toggleStyle(.switch).controlSize(.small)
                            .help("登录这台 Mac 时自动启动 ConfDDL，并在菜单栏显示倒计时")
                        Text("默认显示最近截稿的会议。通过会议右侧的 ··· 可固定一条会议；完成或截稿后自动切换。")
                            .font(.system(size: 11)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    section("数据与备份", icon: "externaldrive") {
                        HStack(spacing: 10) {
                            Button("导入备份…") { model.importBackup() }.help("选择 ConfDDL JSON 备份，确认后合并会议；相同 ID 的记录会更新")
                            Button("导出备份…") { model.exportBackup() }.help("将全部会议及提醒偏好保存为 JSON 备份文件")
                        }.controlSize(.regular)
                        Text("数据仅保存在这台 Mac，建议定期导出备份。").font(.system(size: 11)).foregroundColor(.secondary)
                        Button("在 Finder 中查看数据") { NSWorkspace.shared.selectFile(model.dataURL.path, inFileViewerRootedAtPath: model.dataURL.deletingLastPathComponent().path) }
                            .buttonStyle(.link).font(.system(size: 11))
                            .help("在 Finder 中定位本机保存的 deadlines.json 数据文件")
                    }
                    HStack {
                        Text("ConfDDL 1.1.1").font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("专注每一次投稿").font(.system(size: 11)).foregroundColor(.secondary)
                    }.padding(.horizontal, 3).padding(.bottom, 15)
                }.padding(.horizontal, 22)
            }
        }.task { await model.refreshNotificationStatus(); model.refreshLoginStatus() }
    }

    func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.green).padding(.bottom, 3)
            content()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
    }
}
