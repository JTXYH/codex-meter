# Codex Meter 2.0

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · English · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

<img src="Resources/AppIcon.png" alt="Codex Meter icon" width="96">

A native macOS menu bar app for Codex account limits, usage across devices, and live token counts on your Mac. Click the menu bar item to open the panel.

Codex Meter is an independent open-source project, unaffiliated with OpenAI.

[Download v2.0.0](https://github.com/JTXYH/codex-meter/releases/download/v2.0.0/CodexMeter-2.0.0-macOS.zip) · [Release notes](https://github.com/JTXYH/codex-meter/releases/tag/v2.0.0) · [Report an issue](https://github.com/JTXYH/codex-meter/issues)

## Screenshots

Screenshots use demo data.

| A · Quiet panel | B · Data panel |
| --- | --- |
| ![Quiet panel](docs/images/panel-light.png) | ![Data panel](docs/images/panel-data.png) |

![Shared settings center](docs/images/settings.png)

## Features

- **Two themes:** a purple quota ring in the quiet panel and a green horizontal gauge in the data panel. Settings use the selected theme's accent. Both themes support system, light, and dark appearance.
- **Limits and reset times:** the menu bar shows the remaining 5-hour allowance, falling back to the weekly window when needed. The panel shows the windows returned for your account. You can customize the available, low-quota, and waiting-for-reset messages.
- **Today's details:** incremental reads of local token counters every 5 seconds, with input, output, cached input, and model details.
- **Account history:** daily, weekly, monthly, and yearly token totals from the official account endpoints, including other devices and cloud tasks. Model names, Fast labels, and usage shares appear when the response supports them.
- **Activity:** yesterday, the last 7 days, this month, a 120-day heatmap, and account-provided lifetime tokens, streaks, and longest single task.
- **Reset cards:** the official available count and each available card's expiry date and time, sorted by expiry. Cards are read-only; the app does not redeem them.
- **Credits balance:** the account's extra usage balance, displayed using the conversion described below.
- **Shared settings:** card visibility and drag ordering, menu bar ring size, global or per-card font sizes, refresh frequency, startup behavior, language, and local data cleanup.
- **Updates and privacy:** in-app updates through Sparkle. Email addresses are masked by default; click to reveal them temporarily. Closing the panel hides them again.

The interface supports Simplified Chinese, Traditional Chinese, English, Japanese, Korean, and Spanish. The first launch follows your preferred system language, with English as the fallback.

## Install and use

Requires macOS 14 Sonoma or later. Universal builds support Apple Silicon and Intel Macs. Install the [Codex desktop app or CLI](https://github.com/openai/codex) and sign in with a ChatGPT account first.

1. Download the ZIP from [GitHub Releases](https://github.com/JTXYH/codex-meter/releases/latest), extract it, and move `CodexMeter.app` to Applications.
2. Open Codex Meter and click its quota ring in the menu bar.
3. Use the top-right button to refresh, the bottom-left gear to open settings, and the bottom-right power button to quit.
4. Choose manual startup, launch at login, or follow Codex in settings. The last two options are mutually exclusive. Following Codex requires the packaged app and may require allowing its background helper in macOS Login Items & Extensions.

The build script uses ad-hoc signing by default; this does not imply Apple notarization. If macOS blocks the first launch, verify the release source and SHA-256 checksum before using Open Anyway in System Settings → Privacy & Security.

Release builds offer Check for Updates under About & Updates and scheduled checks every 6 hours. Sparkle verifies update packages before installation. Development builds do not check automatically.

## Data sources

| Data | Source and meaning |
| --- | --- |
| Account, limits, reset times | The local Codex CLI's official `app-server`: `account/read` and `account/rateLimits/read`. |
| Historical tokens, heatmap, account summary | Account statistics from `account/usage/read`. Missing dates stay missing; local history does not fill the gaps. |
| Historical models and shares | The official account's `daily-token-usage-breakdown` endpoint. Each share is the model's summed `credits` weights divided by all weights in the same response. It is not a token share or a dollar cost. Missing weights leave model names visible without shares. |
| Today's tokens and model details | Today's counter events in local Codex session and archive logs, covering this Mac only. |
| Reset cards | `rateLimitResetCredits` from `account/rateLimits/read`. The badge uses `availableCount`; each expiry comes from the available-card details. If details are missing, the app keeps the official count and shows a notice. |
| Credits balance | Official Credits, converted for display at a fixed `1 Credit = US$0.04`. This is separate from token-based API costs. |

Today and account history share **UTC day boundaries** to avoid overlapping local “today” with account “yesterday.” Weeks run Monday through Sunday in UTC. Quota resets and card expiry times use your Mac's current time zone. Historical totals use only the account response, including any data for today; local live counts are never added to them.

API cost calculations and their settings have been removed. API key or Amazon Bedrock sign-ins may not expose ChatGPT account limits, model history, or reset cards. Account responses may arrive late or omit fields. Failed refreshes retain the last successful data; an initial failure offers a retry.

## Local storage and privacy

Settings, local counters, and log read positions are stored in:

```text
~/Library/Application Support/CodexMeter/meter.sqlite
```

SQLite uses WAL and transactions. Account limits, history, and model results are cached only in memory. The app extracts usage counters from logs without storing or uploading conversation text.

Model-history requests use the existing ChatGPT sign-in from `$CODEX_HOME/auth.json` (default: `~/.codex/auth.json`). After checking the account identity, the app sends the request to `chatgpt.com`. Access tokens are not written to the app database or logs.

Settings → Local Data can remove saved local statistics by age or clear them all. It preserves original Codex logs, account statistics, and settings. The cleanup boundary persists so old events are not imported again after a restart.

Do not attach access tokens, `auth.json`, full email addresses, or raw account responses to public issues.

## Build from source

Requires a Swift 6 toolchain (Xcode 16 or later).

```bash
git clone https://github.com/JTXYH/codex-meter.git
cd codex-meter
./scripts/build-app.sh release
```

The app is written to `dist/CodexMeter.app`. Each build clears old products from the project's `dist/` first. A manually selected CLI takes priority; automatic discovery prefers the CLI bundled with the Codex/ChatGPT desktop app, then checks common installation paths.

```bash
swift run CodexMeter
swift test
```

See the [release guide](docs/releasing.md) for packaging and signing. `master` contains version 2.0. The previously published `master` is preserved on the [V1.0 branch](https://github.com/JTXYH/codex-meter/tree/V1.0).

## License

[MIT License](LICENSE)
