# Codex Meter 2.0

简体中文 · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

<img src="Resources/AppIcon.png" alt="Codex Meter 图标" width="96">

原生 macOS 菜单栏工具，查看 Codex 账号额度、跨设备用量和本机实时 Token。点击菜单栏即可打开面板。

Codex Meter 是独立开源项目，与 OpenAI 无隶属关系。

[下载 v2.0.0](https://github.com/JTXYH/codex-meter/releases/download/v2.0.0/CodexMeter-2.0.0-macOS.zip) · [发布说明](https://github.com/JTXYH/codex-meter/releases/tag/v2.0.0) · [反馈问题](https://github.com/JTXYH/codex-meter/issues)

## 界面

截图使用演示数据。

| A · 轻量面板 | B · 数据面板 |
| --- | --- |
| ![轻量面板](docs/images/panel-light.png) | ![数据面板](docs/images/panel-data.png) |

![统一设置中心](docs/images/settings.png)

## 功能

- **两种主题**：轻量主题使用紫色圆环，数据主题使用绿色横向刻度。设置中心跟随主题强调色，两种主题均支持系统、浅色和深色外观。
- **额度与重置时间**：菜单栏显示剩余额度，优先使用 5 小时窗口，仅有周额度时自动回退。面板显示账号返回的额度窗口和重置时间；可自定义“可以继续使用”“额度即将用尽”“等待额度恢复”等状态文字。
- **今日明细**：每 5 秒增量读取本机当天的 Token 计数，展示输入、输出、缓存输入和模型明细。
- **账号历史**：按日、周、月、年查看官方账号接口返回的 Token 总量，包含其他设备和云端任务。显示所用模型、Fast 标记及接口数据支持的使用占比。
- **活跃度**：昨日、近 7 天、本月用量，120 天热力图，以及接口返回的累计 Token、连续使用天数和最长单次任务。
- **充值卡**：展示官方接口返回的可用数量及每张卡的到期日期和时间，按到期时间排列。这里只查看卡片，不执行额度重置。
- **Credits 余额**：展示账号额外用量余额，换算口径见下表。
- **统一设置**：卡片显隐和拖动排序、菜单栏圆环大小、整体或分卡片字号、刷新频率、启动方式、语言及本机数据清理。
- **更新与隐私**：Sparkle 应用内更新；邮箱默认脱敏，点击可临时显示，关闭面板后重新隐藏。

界面支持简体中文、繁體中文、English、日本語、한국어 和 Español。首次启动匹配系统首选语言，未匹配时使用英文。

## 安装与使用

需要 macOS 14 Sonoma 或更高版本，支持 Apple Silicon 和 Intel Mac。请先安装 [Codex 桌面应用或 CLI](https://github.com/openai/codex)，并用 ChatGPT 账号登录。

1. 从 [GitHub Releases](https://github.com/JTXYH/codex-meter/releases/latest) 下载 ZIP，解压并将 `CodexMeter.app` 拖入“应用程序”。
2. 启动 Codex Meter，点击菜单栏的额度圆环打开面板。
3. 右上角按钮手动刷新；左下角齿轮打开设置；右下角电源按钮退出。
4. 在设置中选择手动启动、登录后启动或跟随 Codex 启停。后两种方式互斥；跟随启停需要打包后的应用，并可能需要在 macOS“登录项与扩展”中允许后台助手。

构建脚本默认使用 ad-hoc 签名，不代表经过 Apple 公证。若 macOS 阻止首次打开，请先核对下载来源与 Release 中的 SHA-256 校验文件，再通过“系统设置 → 隐私与安全性”中的“仍要打开”处理。

正式包支持在“关于与更新”中检查更新，也会按配置每 6 小时自动检查。更新包由 Sparkle 校验后安装；开发模式不自动检查更新。

## 数据从哪里来

| 内容 | 来源与口径 |
| --- | --- |
| 账号、额度、重置时间 | 本机 Codex CLI 的官方 `app-server` 接口：`account/read`、`account/rateLimits/read`。 |
| 历史 Token、热力图、账号摘要 | `account/usage/read` 返回的账号统计。未返回的日期保持缺失，不用本机记录补齐。 |
| 历史模型与占比 | 官方账号的 `daily-token-usage-breakdown` 接口。占比是同一次请求中各模型 `credits` 权重之和除以总权重，不是 Token 占比或美元费用；权重缺失时只显示模型。 |
| 今日 Token 与模型明细 | 本机 Codex 会话及归档日志中的当天计数事件，只覆盖这台 Mac。 |
| 充值卡 | `account/rateLimits/read` 中的 `rateLimitResetCredits`。数量使用 `availableCount`，逐张到期时间使用可用卡片明细；明细缺失时保留官方数量并提示。 |
| Credits 余额 | 官方返回的 Credits 余额，应用按固定 `1 Credit = US$0.04` 换算显示；它不是按 Token 计算的 API 费用。 |

今日与历史统计统一使用 **UTC 日界线**，避免把本地“今天”与接口“昨天”重复计入。每周按 UTC 周一至周日计算；额度重置和卡片到期时间按 Mac 当前时区显示。历史中的今日数据完全以接口为准，不叠加本机实时数值。

API 费用计算和相关设置已移除。API Key 或 Amazon Bedrock 登录可能无法提供 ChatGPT 账号额度、历史模型或充值卡信息；接口本身也可能延迟或缺少字段。刷新失败时保留上次成功结果，首次失败则显示重试入口。

## 本地数据与隐私

设置、本机计数和日志读取位置保存在：

```text
~/Library/Application Support/CodexMeter/meter.sqlite
```

SQLite 使用 WAL 和事务。账号额度、历史统计及模型结果只缓存在内存中。应用只提取日志中的用量计数，不保存或上传会话正文。

历史模型请求使用 `$CODEX_HOME/auth.json`（默认 `~/.codex/auth.json`）中已有的 ChatGPT 登录信息，核对账号后向 `chatgpt.com` 发送请求。访问令牌不写入应用数据库或日志。

“设置 → 本机数据”可按保留天数或全部清理已保存的本机统计，不删除 Codex 原始日志、账号统计或设置。清理界限会保存，已清理的旧事件不会因重启再次导入。

请勿在公开 Issue 中附上访问令牌、`auth.json`、完整邮箱或原始账号响应。

## 从源码构建

需要 Swift 6 工具链（Xcode 16 或更高版本）。

```bash
git clone https://github.com/JTXYH/codex-meter.git
cd codex-meter
./scripts/build-app.sh release
```

产物为 `dist/CodexMeter.app`。每次构建会先清空项目 `dist/` 内的旧产物。应用优先使用用户指定的 CLI；自动查找时优先使用 Codex/ChatGPT 桌面应用内置版本，再查找常见 CLI 安装位置。

```bash
swift run CodexMeter
swift test
```

发布和签名步骤见 [发布指南](docs/releasing.md)。`master` 为 2.0 版本代码；发布前的线上 `master` 保存在 [V1.0 分支](https://github.com/JTXYH/codex-meter/tree/V1.0)。

## 协议

[MIT License](LICENSE)
