# Codex Meter

简体中文 · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter 是一款原生 macOS 菜单栏工具，用来快速查看 ChatGPT/Codex 账户的额度窗口和 token 活跃度。它通过本机 Codex CLI 的 `app-server` JSON-RPC 接口读取数据，复用已有登录态，不读取或保存访问令牌。

> Codex Meter 是独立开源项目，不是 OpenAI 官方产品，也不代表 OpenAI 提供支持或背书。

## 软件截图

| 简体中文 · 浅色 | English · Dark |
| --- | --- |
| ![简体中文浅色界面](docs/images/overview-zh-Hans-light.png) | ![English dark interface](docs/images/overview-en-dark.png) |

> 截图使用纯演示数据，不包含真实账户信息。

## 功能

- 菜单栏常驻显示 Codex 每周剩余额度
- 展示所有额度窗口、剩余百分比和重置倒计时
- 展示今日、近 7 天、累计 token 用量和近 90 天活跃热力图
- 今日数据缺失时自动回退到昨日
- 支持手动刷新、预设刷新间隔和 1–1440 分钟自定义间隔
- 支持跟随系统、浅色和深色外观
- 启动时和每 6 小时通过 Cloudflare 检查 GitHub Release，发现新版本后提示下载
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

[⬇️ 下载 Codex Meter v1.0.1（macOS Universal 2）](https://github.com/JTXYH/codex-meter/releases/download/v1.0.1/CodexMeter-1.0.1-macOS.zip)

该版本同时支持 Apple Silicon 和 Intel Mac。下载 ZIP 后解压，将 `CodexMeter.app` 拖入“应用程序”目录即可。[查看 v1.0.1 发布说明](https://github.com/JTXYH/codex-meter/releases/tag/v1.0.1)。

> 当前安装包使用 ad-hoc 签名，尚未经过 Apple 公证。首次启动如被 macOS 拦截，请在 Finder 中右键点击应用，选择“打开”并再次确认。

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
2. 启动 Codex Meter；菜单栏会出现应用图标和每周剩余额度。
3. 点击菜单栏项打开面板，查看额度、token 活跃度、热力图和用量概览。
4. 点击右上角刷新按钮立即更新数据。
5. 点击脱敏邮箱可临时显示完整地址；关闭面板后会自动重新隐藏。
6. 点击左下角齿轮打开设置，修改外观、语言和自动刷新间隔。
7. 点击右下角电源按钮退出应用。

## 数据与隐私

- 账户摘要来自 `account/read`。
- 额度窗口来自 `account/rateLimits/read`；百分比表示当前窗口的已使用比例。
- Token 活跃度和热力图来自 `account/usage/read`，不等同于额度上限。
- 应用不访问 `auth.json`，不保存访问令牌，不记录完整服务端响应，也不上传额外数据。
- API Key 或 Amazon Bedrock 登录方式可能不返回 ChatGPT 额度或活跃统计；如需这些数据，请使用 ChatGPT 登录态。

## 开发与测试

```bash
swift test
swift build -c release
```

项目使用 Swift Package Manager，目前没有第三方包依赖。提交更改前，请确保测试和 release 构建都通过。

## 安全

请不要在公开 Issue 中粘贴访问令牌、`auth.json`、完整邮箱或原始 App Server 响应。如果仓库开启了 GitHub Private Vulnerability Reporting，请通过 **Security → Advisories → Report a vulnerability** 私下报告安全问题。

## 常见问题（FAQ）

### 为什么不支持 Claude Code？

![Anthropic 拒绝恢复 Claude Code 账户](docs/images/why-claude-code-is-not-supported.png)

## 开源协议

项目使用 [Apache License 2.0](LICENSE) 开源。
