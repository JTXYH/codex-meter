# Codex Meter

[简体中文](README.md) · 繁體中文 · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter 是一款原生 macOS 選單列工具，用於快速查看 ChatGPT/Codex 帳戶的額度視窗與 token 活躍度。它透過本機 Codex CLI 的 `app-server` JSON-RPC 介面讀取資料，沿用現有登入狀態，不會讀取或儲存存取令牌。

> Codex Meter 是獨立開源專案，並非 OpenAI 官方產品，也不代表 OpenAI 提供支援或背書。

## 軟體截圖

| 簡體中文 · 淺色 | English · Dark |
| --- | --- |
| ![簡體中文淺色介面](docs/images/overview-zh-Hans-light.png) | [![English dark interface](docs/images/overview-en-dark.png)](docs/images/overview-en-dark.png) |

> 截圖使用純示範資料，不含真實帳戶資訊。

## 功能

- 在選單列常駐顯示 Codex 每週剩餘額度
- 顯示所有額度視窗、剩餘百分比與重設倒數
- 顯示今日、近 7 天、累計 token 用量和近 90 天活躍熱力圖
- 今日 Token 從本機 Codex 會話日誌增量統計，每 5 秒更新，並細分輸入、輸出、快取輸入與美元 API 等效費用
- 支援手動更新、預設間隔與 1–1440 分鐘自訂間隔
- 支援跟隨系統、淺色與深色外觀
- 每 6 小時透過 Sparkle 檢查更新，並在 App 內驗證、安裝與重新啟動
- 帳戶電子郵件預設隱碼，僅在主動點擊後顯示完整地址
- 更新失敗時保留上次成功的資料

## 介面語言

Codex Meter 預設使用簡體中文，目前支援：

- 簡體中文 (`zh-Hans`)
- 繁體中文 (`zh-Hant`)
- English (`en`)
- 日本語 (`ja`)
- 한국어 (`ko`)
- Español (`es`)

## 下載

[⬇️ 下載 Codex Meter v1.1.0（macOS Universal 2）](https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0-macOS.zip)

此版本同時支援 Apple Silicon 與 Intel Mac。下載 ZIP 後解壓縮，將 `CodexMeter.app` 拖入「應用程式」資料夾即可。[查看 v1.1.0 發佈說明](https://github.com/JTXYH/codex-meter/releases/tag/v1.1.0)。

### 首次開啟時遭 macOS 阻擋

目前安裝包使用 ad-hoc 簽章，尚未經過 Apple 公證。若首次啟動時出現「Apple 無法檢查 App 是否為惡意軟體」或「無法驗證開發者」，請先確認 App 下載自本倉庫的 [GitHub Releases](https://github.com/JTXYH/codex-meter/releases)，然後使用以下任一方法：

**方法一：從 Finder 開啟**

1. 在 Finder 中進入「應用程式」，找到 `CodexMeter.app`。
2. 按住 Control 鍵點按 App，或直接按右鍵，然後選擇「打開」。
3. 在確認視窗中再次點按「打開」。首次允許後，以後可正常按兩下啟動。

**方法二：從系統設定允許**

1. 先按兩下 `CodexMeter.app` 嘗試啟動一次，並關閉 macOS 的阻擋提示。
2. 開啟「蘋果」選單 ** → 系統設定 → 隱私權與安全性**。
3. 向下捲動到「安全性」，找到 Codex Meter 的阻擋記錄，點按「強制打開」。
4. 按系統提示完成身分驗證，再點按「打開」。「強制打開」通常只在嘗試啟動 App 後約一小時內顯示。

可參考 [Apple 官方：在 Mac 上安全地打開 App](https://support.apple.com/zh-tw/102445)。若 macOS 明確提示該 App「將損害你的電腦」或偵測到惡意軟體，請不要繞過警告；刪除目前檔案並從官方 Release 重新下載。

## 系統需求

- macOS 14 Sonoma 或更新版本
- 已安裝 [Codex CLI](https://github.com/openai/codex) 並使用 ChatGPT 帳戶登入
- Swift 6 / Xcode 16 或更新版本（僅從原始碼建置時需要）

Codex Meter 會依序查找 `PATH`、`~/.local/bin/codex`、`~/.npm-global/bin/codex`、Homebrew 常見目錄，以及 Codex/ChatGPT App 內的 `codex` 可執行檔。

## 安裝

複製或下載倉庫後，執行：

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

建置結果位於 `dist/CodexMeter.app`。可直接開啟，或移到「應用程式」資料夾。

開發時也可直接執行：

```bash
swift run CodexMeter
```

## 使用指南

1. 先啟動 Codex CLI，確認已使用 ChatGPT 帳戶登入。
2. 啟動 Codex Meter；選單列會出現應用圖示和每週剩餘額度。
3. 點擊選單列項目，查看額度、token 活躍度、熱力圖和用量概覽。
4. 使用右上角更新按鈕立即重新讀取資料。
5. 點擊隱碼電子郵件可暫時顯示完整地址；關閉面板後會自動再次隱藏。
6. 點擊左下角齒輪開啟設定，調整外觀、語言與自動更新間隔。
7. 點擊右下角電源按鈕結束應用。

## 資料與隱私

- 帳戶摘要來自 `account/read`。
- 額度視窗來自 `account/rateLimits/read`；百分比代表視窗的已使用比例。
- Token 活躍度與熱力圖來自 `account/usage/read`，不等於額度上限。
- 今日 Token 統計只會讀取本機 Codex 會話日誌中的 token 計數事件，不儲存或顯示會話內容。
- API 等效費用依 [OpenAI 公開的 GPT-5.6 標準 API 費率](https://openai.com/api/pricing/) 估算，會區分一般輸入、快取讀取、快取寫入、輸出與長上下文；無法辨識的 Codex 內部路由會以 GPT-5.6 Sol 費率作為預設值。這只是 API 等效估算，不代表 ChatGPT 訂閱的實際扣費。
- 應用不存取 `auth.json`、不儲存存取令牌、不記錄完整伺服器回應，也不上傳額外資料。
- API Key 或 Amazon Bedrock 登入可能不會回傳 ChatGPT 額度或活躍統計；如需這些資料，請使用 ChatGPT 登入。

## 開發與測試

```bash
swift test
swift build -c release
```

專案使用 Swift Package Manager，並透過 Sparkle 2 提供 App 內更新。提交變更前，請確認測試與 release 建置均已通過。

## 安全

請勿在公開 Issue 中貼上存取令牌、`auth.json`、完整電子郵件或原始 App Server 回應。若倉庫已啟用 GitHub Private Vulnerability Reporting，請使用 **Security → Advisories → Report a vulnerability** 私下回報。

## 常見問題（FAQ）

### 為什麼不支援 Claude Code？

![Anthropic 拒絕恢復 Claude Code 帳戶](docs/images/why-claude-code-is-not-supported.png)

## 開源授權

Codex Meter 使用 [MIT License](LICENSE) 授權。
