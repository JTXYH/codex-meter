# Codex Meter

简体中文 · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter 是一款原生 macOS 菜单栏工具，用来快速查看 ChatGPT/Codex 账户的额度窗口和 token 活跃度。它通过本机 Codex CLI 的 `app-server` JSON-RPC 接口读取数据，复用已有登录态，不读取或保存访问令牌。

> Codex Meter 是独立开源项目，不是 OpenAI 官方产品，也不代表 OpenAI 提供支持或背书。

## 软件截图

| 简体中文 · 浅色 | English · Dark |
| --- | --- |
| [![简体中文浅色界面](docs/images/overview-zh-Hans-light.png)](docs/images/overview-zh-Hans-light.png) | [![English dark interface](docs/images/overview-en-dark.png)](docs/images/overview-en-dark.png) |

> 两张截图均展示全部七个面板模块，点击可查看原图。截图使用纯演示数据，不包含真实账户信息。

## 功能

- 菜单栏优先显示 Codex 5 小时剩余额度；账户仅返回周额度时自动回退
- 菜单栏默认显示与额度卡片同色的进度圆环，按剩余百分比变化，支持 12–22 pt 大小调节和实时预览
- 根据 API 返回的窗口自适应展示额度卡片：5 小时额度显示重置倒计时与时间，周额度以单行显示剩余比例与重置日期
- 展示今日明细、昨日、近 7 天、本月及累计 Token 与 API 等效费用、连续使用天数和最长任务
- 近 120 天热力图采用紧凑小方格按星期完整铺满，支持悬停查看每日用量
- 今日 Token 从本机 Codex 会话日志增量统计，每 5 秒刷新，并细分输入、输出、缓存输入和美元 API 等效费用
- 显示 Codex Credits 余额，并换算为美元金额
- 所有主面板卡片可独立显示或隐藏、拖动排序，并自动保存设置
- 支持手动刷新、预设刷新间隔和 1–1440 分钟自定义间隔
- 支持登录时启动，以及跟随系统、浅色和深色外观
- 可创建多组自定义额度背景，为充足、注意和紧张三种状态分别裁剪卡片图片与面板图标，并随剩余额度自动切换
- 通过 Sparkle 每 6 小时检查更新，在应用内校验、安装并重启，无需反复手动下载
- 账户邮箱默认脱敏，仅在主动点击后显示完整地址
- 额度刷新失败时保留上次成功数据

## 界面语言

Codex Meter 默认使用简体中文，目前支持：

- 简体中文 (`zh-Hans`)
- 繁體中文 (`zh-Hant`)
- English (`en`)
- 日本語 (`ja`)
- 한국어 (`ko`)
- Español (`es`)

## 下载

[⬇️ 下载 Codex Meter v1.6.0（macOS Universal 2）](https://github.com/JTXYH/codex-meter/releases/download/v1.6.0/CodexMeter-1.6.0-macOS.zip)

该版本同时支持 Apple Silicon 和 Intel Mac。下载 ZIP 后解压，将 `CodexMeter.app` 拖入“应用程序”目录即可。[查看 v1.6.0 发布说明](https://github.com/JTXYH/codex-meter/releases/tag/v1.6.0)。

### 首次打开时被 macOS 拦截

当前安装包使用 ad-hoc 签名，尚未经过 Apple 公证。如果首次启动时出现“Apple 无法检查是否包含恶意软件”或“无法验证开发者”，请先确认应用下载自本仓库的 [GitHub Releases](https://github.com/JTXYH/codex-meter/releases)，然后使用以下任一方法：

**方法一：从 Finder 打开**

1. 在 Finder 中进入“应用程序”，找到 `CodexMeter.app`。
2. 按住 Control 键点击应用，或直接右键点击，然后选择“打开”。
3. 在确认窗口中再次点击“打开”。首次允许后，以后可以正常双击启动。

**方法二：从系统设置允许**

1. 先双击 `CodexMeter.app` 启动一次，并关闭 macOS 的拦截提示。
2. 打开苹果菜单 ** → 系统设置 → 隐私与安全性**。
3. 向下滚动到“安全性”，找到 Codex Meter 的拦截记录，点击“仍要打开”。
4. 按系统提示完成身份验证，再点击“打开”。“仍要打开”通常只在尝试启动应用后的一小时内显示。

可参考 [Apple 官方：在 Mac 上安全地打开 App](https://support.apple.com/zh-cn/102445)。如果 macOS 明确提示该应用“将损坏你的电脑”或检测到恶意软件，请不要绕过警告；删除当前文件并从官方 Release 重新下载。

从首个内置 Sparkle 的版本开始，更新包会用 Ed25519 签名并在应用内安装。如果你已安装的旧版本仍使用浏览器下载，还需手动安装一次过渡版本；之后的更新不再触发同样的 Gatekeeper 提示。

## 系统要求

- macOS 14 Sonoma 或更高版本
- 已安装 [Codex CLI](https://github.com/openai/codex) 并使用 ChatGPT 账户登录
- Swift 6 / Xcode 16 或更高版本（仅从源码构建时需要）

Codex Meter 会依次查找 `PATH`、`~/.local/bin/codex`、`~/.npm-global/bin/codex`、Homebrew 常见目录，以及 Codex/ChatGPT App 内置的 `codex` 可执行文件。

## 安装

克隆或下载仓库后，可直接从源码构建：

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

构建结果位于 `dist/CodexMeter.app`。可以直接双击运行，也可拖入“应用程序”目录。

开发时可以直接运行：

```bash
swift run CodexMeter
```

## 使用指南

1. 先启动 Codex CLI，确认已使用 ChatGPT 账户登录。
2. 启动 Codex Meter；菜单栏会出现彩色额度圆环，并优先显示 5 小时剩余额度（仅有周额度时自动回退）。
3. 点击菜单栏项打开面板，查看额度、token 活跃度、热力图和用量概览。
4. 点击右上角刷新按钮立即更新数据。
5. 点击脱敏邮箱可临时显示完整地址；关闭面板后会自动重新隐藏。
6. 点击左下角齿轮打开设置，配置登录时启动、外观、语言、菜单栏圆环大小、卡片显隐与顺序、字体、额度背景和自动刷新间隔。
7. 在「字体」中调整数值、标题、标签与说明的字号，可统一内容卡片或单独调整；「额度卡片」独立设置。修改立即生效并自动保存，支持恢复默认。
8. 点击右下角电源按钮退出应用。

## 数据与隐私

- 账户摘要来自 `account/read`。
- 额度窗口和 Credits 余额来自 `account/rateLimits/read`；百分比表示当前窗口的已使用比例，Credits 按服务端返回的余额换算为美元金额。
- Token 活跃度和热力图来自 `account/usage/read`，不等同于额度上限。
- 今日 Token 和累计 API 等效费用只读取本机 Codex 现存会话及归档日志中的 token 计数事件，不保存或展示会话内容。今日统计独立刷新，不等待历史扫描；累计费用首次在后台读取历史记录，后续每 5 秒检查文件变化并只计算新增日志。每日计数、费用及读取位置保存在本机 SQLite 数据库（不保存聊天内容），重启后复用读取进度；统计范围可能与服务端的账户累计 Token 不同。
- API 等效费用按会话模型和 [OpenAI 公开的标准 API 费率](https://developers.openai.com/api/docs/pricing) 估算（费率核对日期：2026-09-21），会区分普通输入、缓存读取、缓存写入、输出和适用模型的长上下文；无法识别的 Codex 内部路由按 GPT-5.6 Sol 费率回退。历史用量使用当前内置费率折算，不含工具费用、Fast 模式或区域附加费，不代表 ChatGPT 订阅的实际扣费。
- 用量统计支持每小时、每日、每月和每年：小时范围为近 6 / 12 / 24 小时，日为近 7 / 14 / 30 天，月为近 3 / 6 / 12 个月，年为近 3 / 5 年或全部年份。各周期独立记住范围；点击日期或柱条查看 Token 与 API 等效费用，缺少本机记录的时段显示「—」。小时统计按本地时区的整点划分，包含当前未结束的小时；首次升级会在后台补读日志建立小时缓存，后续增量更新，已清理的历史记录不会恢复。卡片显隐、排序和字体设置继续保留。
- 最长任务使用当前账户服务端返回的 `longestRunningTurnSec`，单位为秒，界面显示到分钟；它是最长单次任务，不是整段会话的累计时长。
- 应用不访问 `auth.json`，不保存访问令牌，不记录完整服务端响应，也不上传额外数据。
- API Key 或 Amazon Bedrock 登录方式可能不返回 ChatGPT 额度或活跃统计；如需这些数据，请使用 ChatGPT 登录态。

### 本地数据与清理

- 应用自己的统计、设置、背景配置和背景图片统一保存在
  `~/Library/Application Support/CodexMeter/meter.sqlite`。SQLite 使用 WAL 和事务；
  仅为变化的日志更新读取进度和每日统计。实时账户额度、界面快照和解码图片保留在内存。
- 首次启动会迁移原先的 UserDefaults 设置、背景图片及
  `~/Library/Caches/CodexMeter/usage-{today,history}.json`，数据库写入成功后才移除对应旧数据。
  Codex 自己的会话日志、登录信息，以及 macOS/Sparkle 管理的状态不属于应用数据库。
- “今日明细”和“活跃度概览”是两张独立卡片，均可在“设置 → 显示”中开关和拖动排序；
  升级时保留已有顺序，新的活跃度概览放在今日明细后，并继承其原显示状态。
- “设置 → 数据管理”显示数据库总占用（含 WAL）、背景图片大小和已保存统计的日期范围。
  可选择清理 7、30、90、180、365 天前、自定义天数之前或全部已记录的本机统计；
  清理前显示具体截止时间，清理后回收空间。设置、背景图片和 Codex 原始日志保持不变，
  账户额度与服务端统计不受影响。
- 清理时间界限会持久保存，已清理的旧事件不会因重启、日志搬移或重写而重新导入。
  新产生的用量正常记录；少量文件读取进度会保留，因此清理全部统计后数据库也不会变成 0 字节。

## 开发与测试

```bash
swift test
swift build -c release
```

项目使用 Swift Package Manager，并通过 Sparkle 2 提供应用内更新。提交更改前，请确保测试和 release 构建都通过。发布流程见 [发布指南](docs/releasing.md)。

## 安全

请不要在公开 Issue 中粘贴访问令牌、`auth.json`、完整邮箱或原始 App Server 响应。如果仓库开启了 GitHub Private Vulnerability Reporting，请通过 **Security → Advisories → Report a vulnerability** 私下报告安全问题。

## 常见问题（FAQ）

### 为什么不支持 Claude Code？

![Anthropic 拒绝恢复 Claude Code 账户](docs/images/why-claude-code-is-not-supported.png)

## 开源协议

项目使用 [MIT License](LICENSE) 开源。
