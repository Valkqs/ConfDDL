# ConfDDL 完整使用指南

[返回项目首页](../README.zh-CN.md) · [English](../README.md)

一个原生 macOS 会议截稿倒计时应用。常驻菜单栏，点击即可查看和管理会议；使用 SwiftUI + AppKit，支持从 CCFDDL 导入与更新会议。

## 直接使用

打开 `dist/ConfDDL.app`。本次安装的位置为 `~/Applications/ConfDDL.app`。应用不显示 Dock 图标，入口在屏幕顶部菜单栏，显示沙漏与倒计时；没有会议时显示 `DDL`。

将光标停留在按钮、图标、筛选器或设置开关上，稍等片刻即可看到 macOS 原生悬停说明。提示会解释该操作的用途；导入选择、系统通知等控件还会根据当前状态说明下一步操作。

1. 点击菜单栏 → 右上角 **地球图标**，或空列表中的 **从 CCFDDL 导入**。搜索会议，按领域、CCF 等级和节点类型筛选，勾选需要关注的节点后导入。
2. 也可通过右上角 **＋** 手动添加。默认选择 **AoE（UTC−12）**，可改为北京时间、美西时间等时区。按所选时区输入日期，下面即时显示本机时间。手动输入精确到该分钟的第 59 秒；导入保留来源的原始秒数。
3. 菜单栏默认显示最近的未完成、未截稿会议。通过每条会议右侧 **··· → 固定到菜单栏**，可优先显示某条会议。该会议完成或截稿后自动切换。
4. **···** 还可打开官网、编辑、标记完成、恢复或删除会议。删除需要确认，编辑返回时会提示未保存的修改。
5. 进入 **设置 → 开启系统通知**，允许 macOS 通知权限。可选择提前 7 天、3 天、1 天、1 小时和截止时提醒，并发送测试通知。
6. 需要随登录自动运行时，在设置中开启 **登录时启动**。建议先将应用保留在 `~/Applications` 或 `/Applications` 的固定位置。

导入和手动填写的日期均应以会议官网为准。空列表中的“载入示例”仅供体验，名称与说明均标注为示例，不代表真实会议日期。

## CCFDDL 自动导入与更新

数据来自 [CCFDDL](https://ccfddl.com) 的[公开会议数据](https://github.com/ccfddl/ccf-deadlines)，通过其官方网站和 GitHub Pages 镜像获取，无需账号或 API Key。

- 默认显示尚未截止的全文投稿节点，可切换到摘要、Rebuttal、录用通知，或勾选“含已截稿”查看往届。多轮会议逐轮显示，最多展示筛选结果中的前 150 条。
- 每个截稿节点单独选择。日期待公布或无法识别的节点可见但不可导入，不会猜测日期。部分来源只提供日期或未写时区时，按 CCFDDL 的默认约定处理，并在导入备注中明确说明。
- 同一个来源节点重复导入会去重。会议的不同年份、不同轮次以及摘要与全文各自独立。
- 默认在应用运行时每日检查已关注节点，启动及唤醒时也会检查是否需要更新。失败后最多每小时自动重试。设置中可关闭自动检查，或点击“立即更新目录与关注”手动检查。
- 改期仅更新截止时刻和时区，保留自定义名称、备注、固定状态与本地 ID，并重新安排通知。主面板会提示更新的条数。完成的会议停止自动更新。
- 手动修改导入节点的时间、时区或类型后，会自动关闭该节点的“跟随 CCFDDL 更新截止时间”。重新开启并保存时，如果已有目录数据，会恢复来源的最新时间。
- 来源节点被删除、改为待公布、轮次标识变化或无标识轮次增减时，保留旧的本地时间，不会将订阅悄悄指向另一轮。可在设置和编辑页查看待确认提示，然后依据官网核对。
- 只跟随选中的年份与节点，不会自动加入下一届会议。
- 最近成功获取的目录缓存为 `~/Library/Application Support/ConfDDL/ccfddl-cache.yml`。断网时可以搜索缓存并导入，获取时间会显示在列表中；联网更新失败不会清空本地数据。

## 时区与提醒

- AoE 是固定 UTC−12，始终比北京时间慢 20 小时。例如 10 月 20 日 23:59 AoE 对应北京时间 10 月 21 日 19:59。
- 支持 IANA 时区，按截止日所在季节自动计算夏令时。不存在的夏令时跳转时间会被拒绝；秋季回拨重复时间采用系统日历默认的第一次出现。
- 会议信息保存为绝对时刻，切换本机时区不会改变实际截止时间。编辑时修改时区会保留输入的当地日期和时间，并重新换算本机时间。
- 系统最多安排最近 60 条提醒，应用运行时每分钟、系统唤醒时以及数据更改时自动刷新。退出应用后已安排的通知由 macOS 负责发送；超出队列的远期提醒需要应用再次运行补充。
- Mac 关机期间无法提醒，专注模式或系统通知设置可能使通知静音。手动会议或暂停跟随的节点改期后，请及时更新日期。

## 数据与备份

数据保存在：

```text
~/Library/Application Support/ConfDDL/deadlines.json
```

文件采用 JSON、ISO 8601 时间和原子写入。会议及备份仅保存在本机，不会上传。CCFDDL 导入与自动检查只下载公开会议目录。读取失败时暂停写入并显示文件路径，以保留原文件。1.0 版本的数据和备份仍可读取。

设置中可导入、导出 JSON 备份。导入前会校验格式并请求确认；相同 ID 的会议更新，其他会议合并，当前通知设置保持不变。最多保留 2000 条会议，导入文件不超过 10 MB。导出文件也包括提醒偏好，但不包括 macOS 的通知权限与登录启动状态。

## 从源码构建

要求 macOS 13 或更新版本，以及支持 Swift 5.9 或更新的 Xcode Command Line Tools。当前产物已在 Apple Silicon Mac 上构建；其他架构可在对应 Mac 上重新构建。

```sh
# 编译、生成图标、本地签名并打包
bash scripts/build.sh

# 构建后安装到 ~/Applications 并打开（不会覆盖已有安装）
bash scripts/build.sh --install

# 运行核心与 CCFDDL 校验，无需 XCTest 或完整 Xcode
swift run DeadlineCoreChecks

# 验证实时下载与解析
swift run DeadlineCoreChecks --fetch-ccf

# 可选：用本地保存的 CCFDDL YAML 验证并生成界面预览
swift run DeadlineCoreChecks --ccf-file /path/to/allconf.yml
swift build
.build/debug/ConfDDL --render-previews "$PWD/dist/screenshots" --ccf-file /path/to/allconf.yml
```

也可双击 `Install.command` 执行安装。构建产物：

- `dist/ConfDDL.app`
- `dist/ConfDDL-macOS.zip`

此构建使用本地 ad-hoc 签名，适合这台 Mac 上使用；向其他用户正式分发时，需要 Apple Developer ID 签名和公证。

YAML 解析使用随源码附带的 Yams 6.2.2，无需在构建时联网拉取依赖。许可和数据来源说明见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)。

## 项目结构

```text
Sources/DeadlineCore/   截稿模型、时区转换、CCFDDL 解析与同步、备份校验与提醒计划
Sources/ConfDDL/        菜单栏生命周期、界面、本地保存及系统集成
Tests/                 核心校验、数据兼容、CCFDDL 多轮导入与更新保护
scripts/               构建打包、原生图标生成
Vendor/Yams/           原版 Yams 6.2.2 及其许可
```

系统集成参考 Apple 文档：[NSStatusBar](https://developer.apple.com/documentation/appkit/nsstatusbar)、[UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger)、[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。
