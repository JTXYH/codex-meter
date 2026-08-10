# Codex Meter

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · English · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter is a native macOS menu bar utility for checking the quota windows and token activity of your ChatGPT/Codex account at a glance. It reads data from the local Codex CLI `app-server` JSON-RPC interface, reuses your existing sign-in, and never reads or stores access tokens.

> Codex Meter is an independent open-source project. It is not an official OpenAI product and is not supported or endorsed by OpenAI.

## Screenshots

| Simplified Chinese · Light | English · Dark |
| --- | --- |
| ![Simplified Chinese light interface](docs/images/overview-zh-Hans-light.png) | ![English dark interface](docs/images/overview-en-dark.png) |

> Screenshots use synthetic demo data and contain no real account information.

## Features

- Shows the remaining weekly Codex quota directly in the menu bar
- Displays all quota windows, remaining percentages, and reset countdowns
- Tracks today, the last 7 days, lifetime token activity, and a 90-day heatmap
- Falls back to yesterday when today's activity is unavailable
- Supports manual refresh, preset intervals, and custom intervals from 1 to 1,440 minutes
- Supports system, light, and dark appearances
- Checks GitHub Releases through Cloudflare at launch and every 6 hours, then offers the new download
- Masks the account email until you explicitly reveal it
- Keeps the last successful snapshot visible when a refresh fails

## Interface languages

Simplified Chinese is the default. The app currently supports:

- Simplified Chinese (`zh-Hans`)
- Traditional Chinese (`zh-Hant`)
- English (`en`)
- Japanese (`ja`)
- Korean (`ko`)
- Spanish (`es`)

## Download

[⬇️ Download Codex Meter v1.0.1 (macOS Universal 2)](https://github.com/JTXYH/codex-meter/releases/download/v1.0.1/CodexMeter-1.0.1-macOS.zip)

This build supports both Apple Silicon and Intel Macs. Download and extract the ZIP, then move `CodexMeter.app` to Applications. [View the v1.0.1 release notes](https://github.com/JTXYH/codex-meter/releases/tag/v1.0.1).

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

## Requirements

- macOS 14 Sonoma or later
- [Codex CLI](https://github.com/openai/codex), signed in with a ChatGPT account
- Swift 6 / Xcode 16 or later (only when building from source)

Codex Meter searches `PATH`, `~/.local/bin/codex`, `~/.npm-global/bin/codex`, common Homebrew locations, and the Codex/ChatGPT app bundles for the `codex` executable.

## Installation

After cloning or downloading the repository, build the app from source:

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The app is created at `dist/CodexMeter.app`. Open it directly or move it to the Applications folder.

For development, run:

```bash
swift run CodexMeter
```

## Usage guide

1. Start Codex CLI and confirm that it is signed in with your ChatGPT account.
2. Launch Codex Meter. Its icon and your remaining weekly quota appear in the menu bar.
3. Click the menu bar item to view quota windows, token activity, the heatmap, and the usage overview.
4. Use the refresh button in the top-right corner to update data immediately.
5. Click the masked email to reveal it temporarily. Closing the panel masks it again.
6. Open Settings with the gear button to change appearance, language, and automatic refresh interval.
7. Quit the app with the power button in the bottom-right corner.

## Data and privacy

- Account metadata comes from `account/read`.
- Quota windows come from `account/rateLimits/read`; percentages represent the used portion of each window.
- Token activity and the heatmap come from `account/usage/read`; they are activity statistics, not quota limits.
- The app does not access `auth.json`, store access tokens, log full server responses, or upload additional data.
- API key or Amazon Bedrock sign-ins may not return ChatGPT quota or activity data. Use a ChatGPT sign-in for these metrics.

## Development and testing

```bash
swift test
swift build -c release
```

The project uses Swift Package Manager and currently has no third-party package dependencies. Please make sure the tests and release build pass before submitting changes.

## Security

Never paste access tokens, `auth.json`, full email addresses, or raw App Server responses into a public issue. If GitHub Private Vulnerability Reporting is enabled, use **Security → Advisories → Report a vulnerability** to report security issues privately.

## FAQ

### Why isn't Claude Code supported?

![Anthropic declined to reinstate the Claude Code account](docs/images/why-claude-code-is-not-supported.png)

## License

Codex Meter is licensed under the [Apache License 2.0](LICENSE).
