<div align="center">
  <img src="docs/assets/app-icon.png" width="88" alt="ConfDDL 图标">
  <h1>ConfDDL</h1>
  <p><strong>会议截稿，一眼可见。</strong></p>
  <p>常驻 Mac 菜单栏的会议 DDL 工具，支持 CCFDDL 导入、时区换算和系统提醒。</p>
  <p><a href="README.md">English</a> · 简体中文</p>
  <p><a href="#安装与使用">安装使用</a> · <a href="docs/guide.zh-CN.md">完整指南</a> · <a href="CONTRIBUTING.md">参与贡献</a> · <a href="https://github.com/Valkqs/ConfDDL/issues">反馈问题</a></p>
</div>

<p align="center">
  <img src="docs/assets/dashboard.png" width="360" alt="菜单面板：置顶会议倒计时与待截稿列表">
  <img src="docs/assets/ccfddl-catalog.png" width="360" alt="CCFDDL 导入：会议搜索、领域、CCF 等级与截稿节点筛选">
</p>
<p align="center"><sub>截图用于展示界面，示例会议日期不代表真实截稿日，来源日期也可能改期。</sub></p>

## 让倒计时留在菜单栏

会议投稿往往同时涉及摘要、全文、多轮次与 AoE 时区。ConfDDL 将下一个重要截稿日放在菜单栏，点开即可查看、编辑和安排提醒。

不用注册账号，关注的会议保存在本机。可以从 CCFDDL 导入，也可以自己添加会议和备注。

## 已有功能

| 功能 | 用途 |
| --- | --- |
| **菜单栏倒计时** | 默认显示最近截稿的会议，也可固定一条重要会议。 |
| **CCFDDL 自动导入** | 按会议名搜索，按领域、CCF 等级和节点类型筛选，逐轮选择。 |
| **时区换算** | 支持 AoE、固定 UTC 偏移和美西夏令时，同时显示本机时间。 |
| **改期检查** | 应用运行时每日检查关注节点，更新截止时间并重新安排提醒。 |
| **系统通知** | 可选提前 7 天、3 天、1 天、1 小时和截止时提醒。 |
| **投稿管理** | 手动添加、备注、完成归档、JSON 备份导入导出。 |
| **原生交互** | 菜单栏入口、登录启动，按钮和设置均提供悬停说明。 |

## 安装与使用

要求 macOS 13+、Xcode Command Line Tools 与 Swift 5.9+。目前已在 Apple Silicon Mac 本机验证，Intel 构建仍待验证。

```sh
git clone https://github.com/Valkqs/ConfDDL.git
cd ConfDDL
bash scripts/build.sh --install
```

如果未安装 Command Line Tools，先运行 `xcode-select --install`，并完成系统安装向导。无需完整 Xcode，YAML 解析依赖随源码附带，构建时不需要联网拉取依赖。

安装后应用位于 `~/Applications/ConfDDL.app`。入口是屏幕顶部菜单栏的沙漏与 `DDL`，不会显示 Dock 图标。如果已有安装，请退出旧版本，再用 `dist/ConfDDL.app` 替换。

当前构建使用本地 ad-hoc 签名，尚未通过 Apple 公证；目前推荐从源码安装。开发者签名与公证下载包已列入路线图。

### 开始关注一场会议

1. 点击菜单栏 → **地球图标**，进入 CCFDDL 会议库。
2. 搜索会议，确认年份、轮次和截稿类型，勾选需要的节点。
3. 点击 **导入**，倒计时会显示在菜单栏。
4. 在 **设置 → 开启系统通知** 中允许 macOS 通知权限，即可使用提醒。

**＋** 用于手动添加，**···** 用于固定到菜单栏、标记完成、打开官网或删除。光标停在控件上即可查看功能说明。更多细节见[完整使用指南](docs/guide.zh-CN.md)。

## 截止时间如何处理

- **AoE 是 UTC−12。** 10 月 20 日 23:59 AoE 对应北京时间 10 月 21 日 19:59。导入保留来源秒数，手动输入使用该分钟的第 59 秒。
- **节点各自独立。** 摘要、全文、Rebuttal、不同年份和轮次分别关注；日期未公布时不能导入。
- **保留手动修改。** 修改导入节点的时间、时区或类型会暂停该条的自动更新；可在编辑页重新开启跟随。
- **来源异常不清空。** 节点消失或改为待公布时保留已有时间，并提示核对。
- **只跟随所选节点。** 不会自动添加下一届会议。应用运行时检查改期，也可在设置中手动立即更新。

CCFDDL 是社区维护的数据源，重要日期请以会议官网为准。

## 数据与提醒

会议和偏好仅保存在本机：

```text
~/Library/Application Support/ConfDDL/deadlines.json
```

无账号、无统计追踪，不上传会议数据。导入和更新仅下载 CCFDDL 的公开目录，打开官网使用默认浏览器；已有缓存时可离线浏览会议库。可导出 JSON 备份，旧版数据继续兼容。

系统安排最近的 60 条提醒，应用运行及唤醒时补充队列。退出后已安排的通知仍由 macOS 发送，超出队列的远期提醒需要再次运行应用补充。关机期间无法提醒，专注模式可能静音通知。

## 开发与贡献

```sh
swift build
swift run DeadlineCoreChecks
bash scripts/build.sh
```

产物是 `dist/ConfDDL.app` 与 `dist/ConfDDL-macOS.zip`。CI 会在 macOS 上执行校验、构建和打包，并保存 ZIP 构建产物。实时联网校验可另行运行 `swift run DeadlineCoreChecks --fetch-ccf`。

项目使用 SwiftUI + AppKit。投稿时间、时区、CCFDDL 解析合并和提醒计划集中在 `Sources/DeadlineCore`。欢迎提交可复现问题、界面改进、翻译和代码贡献，流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 后续计划

- [ ] 英文应用界面
- [ ] Developer ID 签名与 Apple 公证下载包
- [ ] 验证 Intel 构建并提供通用安装包
- [ ] 更多会议来源与导入格式

如果它帮你减少了反复查 DDL 的麻烦，欢迎点一个 Star 支持项目，也欢迎在 [Issues](https://github.com/Valkqs/ConfDDL/issues) 提出需求。

## 致谢与许可

会议数据来自 [CCFDDL](https://ccfddl.com) / [ccf-deadlines](https://github.com/ccfddl/ccf-deadlines)。YAML 解析使用 [Yams 6.2.2](https://github.com/jpsim/Yams) 及其包含的 LibYAML。

项目采用 [MIT 许可证](LICENSE)。第三方来源与许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
