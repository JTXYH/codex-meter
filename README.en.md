# Codex Meter

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · English · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter is a native macOS menu bar utility for checking the quota windows and token activity of your ChatGPT/Codex account at a glance. It reads data from the local Codex CLI `app-server` JSON-RPC interface, reuses your existing sign-in, and never reads or stores access tokens.

> Codex Meter is an independent open-source project. It is not an official OpenAI product and is not supported or endorsed by OpenAI.

## Screenshots

| Simplified Chinese · Light | English · Dark |
| --- | --- |
| [![Simplified Chinese light interface](docs/images/overview-zh-Hans-light.png)](docs/images/overview-zh-Hans-light.png) | [![English dark interface](docs/images/overview-en-dark.png)](docs/images/overview-en-dark.png) |

> Both refreshed screenshots show all seven dashboard cards using synthetic demo data. Click either image for the full-size view. Neither contains real account information.

| Usage Statistics · English · Dark | Settings · English · Light |
| --- | --- |
| [![Selected-period model usage](docs/images/usage-statistics-en-dark.png)](docs/images/usage-statistics-en-dark.png) | [![General settings with Follow Codex app and sidebar navigation](docs/images/settings-en-light.png)](docs/images/settings-en-light.png) |

> Additional views show model usage for a selected week and General settings, including Follow Codex app. The settings sidebar links to Display, Fonts, and Data Management. All usage figures are demo data.

## Features

- Prioritizes the remaining Codex five-hour quota in the menu bar, falling back to weekly quota when that is the only window returned
- Shows a colored quota ring matching the dashboard, with a 12–22 pt size control and live preview
- Adapts the quota card to the API response: five-hour quota shows a reset countdown and time, while weekly quota uses a compact percentage and reset date
- Shows today's details, yesterday, the last 7 days, this month, lifetime tokens and API-equivalent costs, streaks, and the longest task
- Keeps Today's Details and Activity Overview as separate cards, with a weekday-aligned 120-day heatmap and daily details on hover
- Updates today's local token count every 5 seconds, with input, output, cached input, and USD API-equivalent cost details
- Shows today's model-by-model input, output, cost, and share of total tokens, plus the same breakdown for the selected day, week, month, or year
- Estimates quota consumed today and in the selected statistics period; Usage Statistics places tokens, API-equivalent cost, and quota consumed side by side
- Supports daily, weekly, monthly, and yearly usage ranges, with a separate saved range for each period
- Stores local statistics, settings, and background images in SQLite; Data Management shows storage use and can clear selected ages or all recorded statistics
- Lets you adjust value, title, label, and detail font sizes across content cards or individually, with independent quota-card controls and reset to defaults
- Shows the Codex Credits balance converted to its USD value
- Lets every dashboard card be shown or hidden independently, drag-reordered, and saved automatically
- Supports manual refresh, preset intervals, and custom intervals from 1 to 1,440 minutes
- Supports launch at login or following the Codex desktop app's startup and shutdown, plus system, light, and dark appearances
- Prefers the desktop app's bundled CLI during automatic discovery, while keeping manually specified executable paths first
- Creates multiple custom quota-background sets, with separately cropped card art and panel icons for plenty, attention, and low-quota states that switch automatically
- Checks for updates every 6 hours with Sparkle, then verifies, installs, and relaunches in-app
- Masks the account email until you explicitly reveal it
- Keeps the last successful quota snapshot when a refresh fails; local usage remains visible even if the first quota request fails, with a retry action

## Interface languages

On first launch, the app uses your macOS preferred language when supported, falling back to English. Your selection in Settings is saved. The app supports:

- Simplified Chinese (`zh-Hans`)
- Traditional Chinese (`zh-Hant`)
- English (`en`)
- Japanese (`ja`)
- Korean (`ko`)
- Spanish (`es`)

## Download

[⬇️ Download Codex Meter v1.7.0 (macOS Universal 2)](https://github.com/JTXYH/codex-meter/releases/download/v1.7.0/CodexMeter-1.7.0-macOS.zip)

This build supports both Apple Silicon and Intel Macs. Download and extract the ZIP, then move `CodexMeter.app` to Applications. [View the v1.7.0 release notes](https://github.com/JTXYH/codex-meter/releases/tag/v1.7.0).

### If macOS blocks the app on first launch

The current build is ad-hoc signed and is not Apple-notarized. If the first launch shows “Apple cannot check it for malicious software” or “the developer cannot be verified,” first make sure the app came from this repository’s [GitHub Releases](https://github.com/JTXYH/codex-meter/releases), then use either method below.

**Method 1: Open it from Finder**

1. Open Applications in Finder and locate `CodexMeter.app`.
2. Control-click or right-click the app, then choose **Open**.
3. Click **Open** again in the confirmation dialog. After you allow it once, you can launch it normally by double-clicking.

**Method 2: Allow it in System Settings**

1. Double-click `CodexMeter.app` once, then dismiss the macOS warning.
2. Open the Apple menu ** → System Settings → Privacy & Security**.
3. Scroll down to Security, find the message about Codex Meter, and click **Open Anyway**.
4. Authenticate when prompted, then click **Open**. The **Open Anyway** button is usually available for about one hour after you try to launch the app.

See [Apple Support: Safely open apps on your Mac](https://support.apple.com/en-us/102445) for more information. If macOS explicitly says the app “will damage your computer” or reports malware, do not bypass the warning; delete the current file and download it again from the official Release.

Starting with the first Sparkle-enabled release, update archives are signed with Ed25519 and installed in-app. Users on an older browser-download release must manually install that transition release once; later updates no longer trigger the same Gatekeeper prompt.

## Requirements

- macOS 14 Sonoma or later
- The Codex desktop app or [Codex CLI](https://github.com/openai/codex), signed in with a ChatGPT account
- Swift 6 / Xcode 16 or later (only when building from source)

Manually specified CLI paths take priority. Automatic discovery checks the Codex/ChatGPT app bundles before `PATH`, `~/.local/bin/codex`, `~/.npm-global/bin/codex`, and common Homebrew locations. A separate CLI installation is unnecessary when a compatible bundled executable is available.

Following Codex requires the Codex desktop app and a packaged Codex Meter app; the watcher is inactive in `swift run` development builds. Install Codex Meter in Applications before enabling this option.

## Installation

After cloning or downloading the repository, build the app from source:

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The app is created at `dist/CodexMeter.app`. Open it directly or move it to the Applications folder. The build script clears previous artifacts from `dist/` before each build.

For development, run:

```bash
swift run CodexMeter
```

## Usage guide

1. Open the Codex desktop app or CLI and confirm that it is signed in with your ChatGPT account.
2. Launch Codex Meter. The menu bar shows a colored ring and the remaining five-hour quota, or the weekly quota when that is the only window available.
3. Click the menu bar item to view quota windows, Today's Details with model usage, Activity Overview, the heatmap, and Usage Statistics.
4. In Usage Statistics, choose Day, Week, Month, or Year, set the range, and click a date tab to inspect its tokens, API-equivalent cost, quota consumption estimate, and model breakdown. Daily tabs start yesterday; today's breakdown appears in Today's Details.
5. Use the refresh button in the top-right corner to refresh quota data immediately. If a remote request fails, use the retry action; local statistics remain available.
6. Click the masked email to reveal it temporarily. Closing the panel masks it again.
7. Open Settings with the gear button to configure startup, appearance, language, ring size, card visibility and order, quota backgrounds, and the refresh interval.
8. Choose either Launch at login or Follow Codex app. Enabling one disables the other. Follow Codex app starts Codex Meter when the Codex desktop app opens and quits it when Codex closes. If macOS requests approval, allow the Codex Meter background item in System Settings → General → Login Items & Extensions. If you move or replace the app, toggle this setting again to update the watcher path.
9. In Fonts, adjust value, title, label, and detail sizes across content cards or for individual cards; the quota card has independent controls. Changes apply immediately and save automatically, with a reset option. Use Data Management to review storage and clear recorded statistics.
10. Quit the app with the power button in the bottom-right corner.

## Data and privacy

- Account metadata comes from `account/read`.
- Quota windows and the Credits balance come from `account/rateLimits/read`; percentages represent the used portion of each window, while Credits are converted from the server-returned balance to USD.
- Quota consumed today and in a selected period is estimated from changes in locally recorded quota readings for the current primary quota window, accounting for reset boundaries. Accumulated percentage-point increases can exceed 100% across multiple reset windows. Usage on other devices and server synchronization delays can affect the estimate. Missing usable readings show “—”. Only time, quota-window metadata, and percentages are saved locally, without conversation content.
- Token activity and the heatmap come from `account/usage/read`; they are activity statistics, not quota limits.
- Today's tokens and local lifetime API-equivalent costs read token-count events from existing Codex session and archived logs. The app neither stores nor displays conversation content. Today refreshes independently of the initial background history scan; later scans check for file changes every 5 seconds and process new events. SQLite preserves daily totals, costs, and file offsets across restarts. Local coverage can differ from the account-wide lifetime tokens reported by the server.
- API-equivalent cost uses the app's bundled per-model standard USD API rates, distinguishing regular input, cache reads, cache writes, output, and long-context pricing where applicable. Unrecognized internal routes fall back to GPT-5.6 Sol rates. Historical usage is converted using the bundled rate table; it is not a live price feed and excludes tool fees, Fast mode, and regional surcharges. This estimate is not an actual ChatGPT subscription charge. The rate table references [OpenAI's API pricing documentation](https://developers.openai.com/api/docs/pricing).
- Usage Statistics supports Day, Week, Month, and Year. Day shows the 7 / 14 / 30 days before today, starting yesterday. Week uses local Monday–Sunday boundaries and shows 4 / 8 / 12 weeks (default: 4), including the current week through now. Month shows 3 / 6 / 12 months; Year shows 3 / 5 years or all recorded years. Week, Month, and Year include today. Each period remembers its own range. Model shares use local tokens for the selected period; events without a model identifier appear under Unknown. Today's model usage appears separately in Today's Details. The former Hour setting migrates to Day, preserving card visibility, order, and fonts.
- The longest task uses the server's `longestRunningTurnSec`, expressed in seconds and displayed to the minute. It measures the longest single task, not the total duration of a conversation.
- The app does not access `auth.json`, store access tokens, log full server responses, or upload additional data.
- API key or Amazon Bedrock sign-ins may not return ChatGPT quota or activity data. Use a ChatGPT sign-in for these metrics.

### Local storage and cleanup

- The app's statistics, settings, background configuration, and background images are stored in `~/Library/Application Support/CodexMeter/meter.sqlite`. SQLite uses WAL and transactions; file offsets and daily totals update only for changed logs. Current account quotas, interface snapshots, and decoded images remain in memory.
- v1.7.0 adds per-model totals and quota observations to the existing database. Older file checkpoints trigger a reread of the original logs as needed to restore model details and quota history, honoring any saved cleanup cutoff.
- When upgrading from versions predating SQLite storage (introduced in v1.6.0), the app migrates previous UserDefaults settings, background images, and `~/Library/Caches/CodexMeter/usage-{today,history}.json`, removing legacy data only after successful database writes. Codex session logs, authentication, and macOS/Sparkle-managed state are outside this database.
- Today's Details and Activity Overview are independent cards in Settings → Display. When older layouts are migrated, the app preserves card order and places Activity Overview after Today's Details, inheriting its previous visibility.
- Settings → Data Management shows total database storage (including WAL), background-image size, and the saved statistics date range. You can clear statistics older than 7, 30, 90, 180, or 365 days, choose a custom age, or clear all recorded local statistics. The app shows the exact cutoff before cleanup and reclaims space afterward. Settings, background images, Codex's original logs, account quotas, and server statistics remain intact.
- The cleanup cutoff is persisted, preventing older events from being imported again after restarts, log moves, or rewrites. New usage is recorded normally. A small amount of file-offset metadata remains, so clearing all statistics does not reduce the database to zero bytes.

## Development and testing

```bash
swift test
swift build -c release
```

The project uses Swift Package Manager and Sparkle 2 for in-app updates. Please make sure the tests and release build pass before submitting changes. See the [release guide](docs/releasing.md) for packaging and signing.

## Security

Never paste access tokens, `auth.json`, full email addresses, or raw App Server responses into a public issue. If GitHub Private Vulnerability Reporting is enabled, use **Security → Advisories → Report a vulnerability** to report security issues privately.

## FAQ

### Why isn't Claude Code supported?

![Anthropic declined to reinstate the Claude Code account](docs/images/why-claude-code-is-not-supported.png)

## License

Codex Meter is licensed under the [MIT License](LICENSE).
