# 首次公开发布准备

项目文档和源码可以先在私有仓库中整理；准备好后再由维护者将仓库改为公开。

## 发布前

- 本机和 GitHub Actions 校验通过，确认 README 的功能与实际版本一致。
- 完善 GitHub About 描述：`A native macOS menu bar app for conference deadlines, CCFDDL import, and reminders.`
- 添加相关 Topics：`macos`、`swift`、`swiftui`、`menubar`、`conference`、`deadlines`、`ccfddl`、`academic`。
- 核对 MIT 许可证和第三方声明，检查截图不含私人备注或信息。
- 确认当前界面为中文、Intel 尚未验证、安装包尚未公证等限制已明确说明。

## 首个 Release

- 最好先完成 Developer ID 签名与 Apple 公证，再面向普通用户提供下载。
- 若先发布未公证的预览版，明确标为预览版，说明签名和支持架构，保留源码安装路径。
- 提供实际验证过的架构的 ZIP、SHA-256 校验值、版本说明和安装步骤。
- README 的主要安装入口应指向真实存在的 Release 资源，避免失效下载链接。
- 录制一段简短演示：菜单栏倒计时 → 搜索会议 → 导入 → 固定会议 → 开启提醒。

## 公开介绍时

围绕具体使用场景介绍：Mac 上投稿前快速看剩余时间、AoE 换算、多轮截稿与改期提醒。使用真实截图和演示，写清已有功能与限制。

可以由维护者在熟悉的科研社区、macOS 社区或个人社交账号发布，并按社区规则附上 GitHub 链接。不要批量刷屏、购买 Star 或承诺无法验证的使用量。收到反馈后持续修复和发布，会比重复索要 Star 更有价值。
