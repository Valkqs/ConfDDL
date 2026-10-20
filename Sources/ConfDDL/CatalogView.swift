import SwiftUI
import DeadlineCore

struct CatalogView: View {
    @ObservedObject var model: AppModel
    let dismiss: () -> Void
    @State private var search = ""
    @State private var category = "all"
    @State private var rank = "all"
    @State private var kind = "全文截稿"
    @State private var includePast = false
    @State private var selected = Set<String>()

    var filtered: [CatalogEntry] {
        let year = Calendar.current.component(.year, from: model.now)
        return model.catalogEntries.filter { item in
            (category == "all" || category == item.category) && (rank == "all" || rank == item.rank) &&
            (kind == "all" || kind == item.kind) &&
            (includePast || (item.deadline.map { $0 > model.now } ?? (item.year >= year))) &&
            (search.isEmpty || "\(item.name) \(item.title) \(item.round)".localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.deadline != $1.deadline { return ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            return $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: "从 CCFDDL 导入", back: dismiss)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("选择关注的节点，自动填入日期与时区").font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer(minLength: 0)
                    if model.catalogLoading {
                        ProgressView().controlSize(.small).scaleEffect(0.75).frame(width: 15, height: 15)
                        Button("取消") { model.cancelCatalogRefresh() }.buttonStyle(.link).font(.system(size: 10))
                            .help("停止本次目录下载，保留已保存的会议和缓存")
                    } else {
                        Button { model.refreshCatalog() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).help("刷新目录并更新已关注会议").accessibilityLabel("刷新 CCFDDL")
                    }
                }
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("搜索名称，如 CVPR、ICLR、SIGMOD", text: $search).textFieldStyle(.plain).font(.system(size: 12))
                        .help("按会议简称、全称、年份或轮次说明搜索，并结合下方条件筛选")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundColor(.secondary)
                            .help("清空搜索词，保留领域、等级和节点筛选条件").accessibilityLabel("清空会议库搜索")
                    }
                }.padding(10).background(Palette.card, in: RoundedRectangle(cornerRadius: 9))
                HStack(spacing: 12) {
                    Picker("领域", selection: $category) {
                        Text("全部领域").tag("all")
                        ForEach(CatalogEntry.categories.keys.sorted(), id: \.self) { key in Text(CatalogEntry.categories[key]!).tag(key) }
                    }.help("按研究领域筛选会议，例如人工智能、数据库或计算机网络")
                    Picker("CCF", selection: $rank) {
                        Text("全部").tag("all")
                        ForEach(["A", "B", "C", "N"], id: \.self) { Text($0 == "N" ? "未评级" : $0).tag($0) }
                    }.frame(width: 112).help("按 CCF 的 A、B、C 等级筛选；未评级表示来源未提供 CCF 等级")
                }.font(.system(size: 11))
                HStack {
                    Picker("节点", selection: $kind) {
                        Text("全部节点").tag("all")
                        ForEach(["全文截稿", "摘要截稿", "Rebuttal", "录用通知"], id: \.self) { Text($0).tag($0) }
                    }.frame(width: 177).help("选择要导入的时间节点：全文、摘要、Rebuttal、录用通知或全部")
                    Spacer()
                    Toggle("含已截稿", isOn: $includePast).toggleStyle(.checkbox)
                        .help("同时显示已经截止的节点与往届会议，便于查阅历史记录")
                }.font(.system(size: 11))
                if let error = model.catalogError {
                    Text(error).font(.system(size: 10)).foregroundColor(.orange).lineLimit(3)
                }
                HStack {
                    Text("\(filtered.count) 个节点\(filtered.count > 150 ? " · 显示前 150 个，请缩小筛选" : "")")
                    Spacer()
                    if let date = model.catalogFetchedAt {
                        Text("获取于 \(dateText(date, zone: .current, pattern: "MM/dd HH:mm"))")
                    }
                }.font(.system(size: 10)).foregroundColor(.secondary)
            }.padding(.horizontal, 22).padding(.bottom, 10)
            Divider().padding(.horizontal, 22)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: model.catalogLoading ? "network" : "magnifyingglass").font(.system(size: 26, weight: .light))
                            Text(model.catalogLoading ? "正在获取会议目录…" : model.catalogEntries.isEmpty ? "暂未获取到会议目录，点击右上角重试" : "没有匹配的节点，试试其他筛选条件")
                                .font(.system(size: 12)).multilineTextAlignment(.center)
                        }.foregroundColor(.secondary).frame(maxWidth: .infinity).padding(.vertical, 48)
                    }
                    ForEach(Array(filtered.prefix(150))) { entry in
                        catalogRow(entry)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 12)
            }
            VStack(spacing: 10) {
                HStack {
                    Button("查看 CCFDDL") { model.openWebsite("https://ccfddl.com") }.buttonStyle(.link).font(.system(size: 11))
                        .help("在默认浏览器中打开数据来源 CCFDDL 网站")
                    Spacer()
                    Button("导入 \(selected.count) 个节点") {
                        let entries = model.catalogEntries.filter { selected.contains($0.id) }
                        if model.importCatalogEntries(entries) > 0 { dismiss() }
                    }.buttonStyle(.borderedProminent).controlSize(.large).disabled(selected.isEmpty)
                        .help(selected.isEmpty ? "先勾选列表中要关注的节点，再点击导入" : "导入已勾选的 \(selected.count) 个节点，自动保存日期与时区；重复节点会跳过")
                }
                Text("导入后每日检查改期；未公布日期不能导入。数据由社区维护，请以会议官网为准。")
                    .font(.system(size: 10)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(18).background(Palette.card.opacity(0.4))
        }.onAppear { model.openCatalog() }
            .onChange(of: model.catalogFetchedAt) { _ in
                let eligible = Set(model.catalogEntries.filter { $0.deadline != nil }.map(\.id)).subtracting(model.importedKeys)
                selected.formIntersection(eligible)
            }
    }

    func catalogRow(_ entry: CatalogEntry) -> some View {
        let imported = model.importedKeys.contains(entry.id)
        let chosen = selected.contains(entry.id)
        return Button {
            if chosen { selected.remove(entry.id) } else { selected.insert(entry.id) }
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: imported ? "checkmark.circle.fill" : chosen ? "checkmark.square.fill" : "square")
                    .font(.system(size: 17)).foregroundColor(imported || chosen ? Palette.green : Color.secondary.opacity(0.4)).padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 3)
                        Text(imported ? "已添加" : "CCF \(entry.rank)").font(.system(size: 10, weight: .medium)).foregroundColor(Palette.green)
                    }
                    Text("\(entry.kind)\(entry.round.isEmpty ? "" : " · \(entry.round)")")
                        .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
                    if let date = entry.deadline {
                        Text("\(dateText(date, zone: .current)) 本机时间")
                            .font(.system(size: 11, weight: .medium)).foregroundColor(Palette.green)
                        Text("来源：\(dateText(date, zone: TimeZone(identifier: entry.timeZoneID) ?? .gmt)) · \(entry.timeZoneID == "Etc/GMT+12" ? "AoE" : entry.timeZoneID)")
                            .font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                    } else {
                        Text(entry.unavailableReason ?? "时间待公布").font(.system(size: 11)).foregroundColor(.secondary)
                    }
                    if entry.assumptions != nil { Text("含来源默认约定，详见导入后的备注").font(.system(size: 9)).foregroundColor(.orange) }
                }
            }.padding(12).background(chosen ? Palette.green.opacity(0.08) : Palette.card, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(chosen ? Palette.green.opacity(0.3) : .clear))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(imported || entry.deadline == nil)
            .help(imported ? "此节点已经添加，可回到主面板查看或编辑" : entry.deadline == nil ? "\(entry.unavailableReason ?? "时间待公布")，暂时无法导入" : chosen ? "取消选择 \(entry.name) 的\(entry.kind)节点" : "选择 \(entry.name) 的\(entry.kind)节点，再点击底部导入")
    }
}
