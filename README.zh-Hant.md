# Codex Meter

[简体中文](README.md) · 繁體中文 · [English](README.en.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter 是一款原生 macOS 選單列工具，用於快速查看 ChatGPT/Codex 帳戶的額度視窗與 token 活躍度。它透過本機 Codex CLI 的 `app-server` JSON-RPC 介面讀取資料，沿用現有登入狀態，不會讀取或儲存存取令牌。

> Codex Meter 是獨立開源專案，並非 OpenAI 官方產品，也不代表 OpenAI 提供支援或背書。

## 軟體截圖

| 簡體中文 · 淺色 | English · Dark |
| --- | --- |
| [![簡體中文淺色介面](docs/images/overview-zh-Hans-light.png)](docs/images/overview-zh-Hans-light.png) | [![English dark interface](docs/images/overview-en-dark.png)](docs/images/overview-en-dark.png) |

> 兩張更新後的截圖均展示全部七個面板卡片，點擊可查看原圖。截圖使用純示範資料，不含真實帳戶資訊。

| 用量統計 · English · Dark | 設定 · English · Light |
| --- | --- |
| [![所選時段的模型用量](docs/images/usage-statistics-en-dark.png)](docs/images/usage-statistics-en-dark.png) | [![一般設定中的隨 Codex 啟停與側邊導覽](docs/images/settings-en-light.png)](docs/images/settings-en-light.png) |

> 額外截圖展示所選週的模型用量，以及含「隨 Codex 啟停」的一般設定；設定側邊欄可前往顯示、字體與資料管理。用量數字均為示範資料。

## 功能

- 選單列優先顯示 Codex 5 小時剩餘額度；帳戶只回傳週額度時自動改用週額度
- 選單列預設顯示與額度卡片同色的進度圓環，支援 12–22 pt 大小調整和即時預覽
- 依 API 回傳的視窗調整額度卡片：5 小時額度顯示重設倒數與時間，週額度以單行顯示剩餘比例與重設日期
- 顯示今日明細、昨日、近 7 天、本月及累計 Token 與 API 等效費用、連續使用天數與最長任務
- 「今日明細」和「活躍度概覽」為獨立卡片；近 120 天熱力圖以緊湊小方格依星期完整鋪滿，支援懸停查看每日用量
- 今日 Token 從本機 Codex 會話日誌增量統計，每 5 秒更新，細分輸入、輸出、快取輸入與美元 API 等效費用
- 今日明細顯示各模型的輸入、輸出 Token、API 等效費用與 Token 占比；用量統計顯示所選日、週、月或年的相同模型明細
- 估算今日及所選統計時段的額度消耗；用量統計並列顯示 Token、API 等效費用和額度消耗
- 支援每日、每週、每月和每年用量範圍，各週期分別記住設定
- 本機統計、設定及背景圖片使用 SQLite 儲存；資料管理可查看儲存用量，並依資料年齡或全部清理統計
- 可統一或個別調整內容卡片的數值、標題、標籤與說明字級；額度卡片獨立設定，支援恢復預設
- 顯示 Codex Credits 餘額，並換算為美元金額
- 所有主面板卡片均可獨立顯示或隱藏、拖曳排序，並自動儲存設定
- 支援手動更新、預設間隔與 1–1440 分鐘自訂間隔
- 支援登入時啟動或隨 Codex 桌面應用程式啟停，以及跟隨系統、淺色與深色外觀
- 自動尋找 CLI 時優先使用桌面 App 內建版本；手動指定的可執行檔路徑仍優先
- 可建立多組自訂額度背景，為充足、注意與緊張三種狀態分別裁切卡片圖片及面板圖示，並依剩餘額度自動切換
- 每 6 小時透過 Sparkle 檢查更新，並在 App 內驗證、安裝與重新啟動
- 帳戶電子郵件預設隱碼，僅在主動點擊後顯示完整地址
- 額度更新失敗時保留上次成功資料；首次請求失敗仍顯示本機用量，並提供重試入口

## 介面語言

首次啟動會依 macOS 偏好語言選擇支援的介面語言，未支援時使用英文；在設定中選擇的語言會自動儲存。目前支援：

- 簡體中文 (`zh-Hans`)
- 繁體中文 (`zh-Hant`)
- English (`en`)
- 日本語 (`ja`)
- 한국어 (`ko`)
- Español (`es`)

## 下載

[⬇️ 下載 Codex Meter v1.7.0（macOS Universal 2）](https://github.com/JTXYH/codex-meter/releases/download/v1.7.0/CodexMeter-1.7.0-macOS.zip)

此版本同時支援 Apple Silicon 與 Intel Mac。下載 ZIP 後解壓縮，將 `CodexMeter.app` 拖入「應用程式」資料夾即可。[查看 v1.7.0 發佈說明](https://github.com/JTXYH/codex-meter/releases/tag/v1.7.0)。

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

從首個內建 Sparkle 的版本開始，更新包使用 Ed25519 簽章並在 App 內安裝。仍使用瀏覽器下載更新的舊版本，需要先手動安裝一次過渡版本；之後的更新不再觸發相同的 Gatekeeper 提示。

## 系統需求

- macOS 14 Sonoma 或更新版本
- Codex 桌面應用程式或 [Codex CLI](https://github.com/openai/codex)，並使用 ChatGPT 帳戶登入
- Swift 6 / Xcode 16 或更新版本（僅從原始碼建置時需要）

手動指定的 CLI 路徑優先。自動尋找時，先檢查 Codex/ChatGPT App 內建版本，再查找 `PATH`、`~/.local/bin/codex`、`~/.npm-global/bin/codex` 和 Homebrew 常見目錄。若已有相容的內建可執行檔，就不必另行安裝 CLI。

「隨 Codex 啟停」需要 Codex 桌面應用程式及打包後的 Codex Meter；`swift run` 開發版本不啟用背景監看程式。開啟此選項前，請先將 Codex Meter 安裝至「應用程式」資料夾。

## 安裝

複製或下載倉庫後，執行：

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

建置結果位於 `dist/CodexMeter.app`。可直接開啟，或移到「應用程式」資料夾。建置腳本會在每次建置前清除 `dist/` 中的舊產物。

開發時也可直接執行：

```bash
swift run CodexMeter
```

## 使用指南

1. 開啟 Codex 桌面應用程式或 CLI，確認已使用 ChatGPT 帳戶登入。
2. 啟動 Codex Meter；選單列會顯示彩色圓環，並優先顯示 5 小時剩餘額度（僅有週額度時自動改用週額度）。
3. 點擊選單列項目，查看額度、含模型用量的今日明細、活躍度概覽、熱力圖與用量統計。
4. 在用量統計選擇日、週、月或年及顯示範圍，再點擊日期標籤查看 Token、API 等效費用、額度消耗估算和模型明細。每日標籤從昨天開始；今天的用量另列於今日明細。
5. 使用右上角更新按鈕立即重新讀取額度。遠端請求失敗時可重試，本機統計仍可查看。
6. 點擊隱碼電子郵件可暫時顯示完整地址；關閉面板後會自動再次隱藏。
7. 點擊齒輪開啟設定，調整啟動方式、外觀、語言、圓環大小、卡片顯示與順序、額度背景和更新間隔。
8. 選擇「登入時啟動」或「隨 Codex 啟停」，開啟其中一項會關閉另一項。隨 Codex 啟停會在 Codex 桌面應用程式開啟時啟動 Codex Meter，Codex 結束時關閉。若 macOS 要求核准，請至「系統設定 → 一般 → 登入項目與延伸功能」允許 Codex Meter 在背景執行。移動或替換 App 後，可重新切換此設定以更新監看程式路徑。
9. 在「字體」中統一或個別調整內容卡片的數值、標題、標籤與說明字級；額度卡片獨立設定。修改立即生效並自動儲存，支援恢復預設。在「資料管理」查看儲存用量或清理已記錄的統計。
10. 點擊右下角電源按鈕結束應用。

## 資料與隱私

- 帳戶摘要來自 `account/read`。
- 額度視窗和 Credits 餘額來自 `account/rateLimits/read`；百分比代表視窗的已使用比例，Credits 依服務端傳回的餘額換算為美元金額。
- 今日及所選時段的額度消耗，依本機記錄的額度讀數變化估算，按目前主要額度視窗彙總並處理重設邊界。跨越多個重設視窗時，累計百分點增量可能超過 100%。其他裝置的用量與服務端同步延遲可能影響結果；缺少可計算記錄時顯示「—」。本機僅儲存時間、額度視窗中繼資料與百分比，不儲存會話內容。
- Token 活躍度與熱力圖來自 `account/usage/read`，不等於額度上限。
- 今日 Token 和本機累計 API 等效費用只讀取 Codex 現存會話及封存日誌中的 token 計數事件，不儲存或顯示會話內容。今日統計獨立更新，不等待首次背景歷史掃描；後續每 5 秒檢查檔案變化並處理新增事件。SQLite 儲存每日計數、費用及檔案讀取位置，重新啟動後沿用進度。本機統計範圍可能與服務端帳戶累計 Token 不同。
- API 等效費用使用 App 內建的各模型標準美元 API 費率，區分一般輸入、快取讀取、快取寫入、輸出及適用模型的長上下文。無法辨識的內部路由以 GPT-5.6 Sol 費率作為預設。歷史用量以內建費率表折算，不是即時價格資料，也不含工具費用、Fast 模式或區域附加費；不代表 ChatGPT 訂閱的實際扣費。費率表參考 [OpenAI API 定價文件](https://developers.openai.com/api/docs/pricing)。
- 用量統計支援每日、每週、每月和每年。每日從昨天開始，顯示今天之前的 7 / 14 / 30 天。每週依本地時間週一至週日統計，顯示近 4 / 8 / 12 週（預設 4 週），包含本週截至目前的用量。每月顯示近 3 / 6 / 12 個月；每年顯示近 3 / 5 年或全部已記錄年份。週、月、年均包含今天，各週期分別記住範圍。模型占比依所選時段的本機 Token 計算；缺少模型識別的事件歸入 Unknown。今天的模型用量另列於今日明細。原「每小時」設定自動遷移為「每日」，並保留卡片顯示、排序與字體設定。
- 最長任務使用服務端的 `longestRunningTurnSec`，單位為秒，介面顯示到分鐘；代表最長單次任務，不是整段會話累計時長。
- 應用不存取 `auth.json`、不儲存存取令牌、不記錄完整伺服器回應，也不上傳額外資料。
- API Key 或 Amazon Bedrock 登入可能不會回傳 ChatGPT 額度或活躍統計；如需這些資料，請使用 ChatGPT 登入。

### 本機資料與清理

- 應用自己的統計、設定、背景配置及背景圖片儲存於 `~/Library/Application Support/CodexMeter/meter.sqlite`。SQLite 使用 WAL 與交易；僅為有變化的日誌更新讀取進度和每日統計。即時帳戶額度、介面快照及解碼圖片保留於記憶體。
- v1.7.0 在現有資料庫加入各模型統計與額度讀數。舊檔案讀取進度會視需要重新讀取原日誌，恢復模型明細和額度歷史，並遵守已儲存的清理截止時間。
- 從採用 SQLite 之前的版本升級時（SQLite 儲存於 v1.6.0 引入），會遷移原有 UserDefaults 設定、背景圖片及 `~/Library/Caches/CodexMeter/usage-{today,history}.json`，資料庫寫入成功後才移除舊資料。Codex 自己的會話日誌、登入資訊及 macOS/Sparkle 管理的狀態不屬於此資料庫。
- 「今日明細」和「活躍度概覽」可在「設定 → 顯示」獨立開關及拖曳排序。遷移舊版配置時，會保留已有卡片順序，將活躍度概覽放在今日明細後，繼承其原顯示狀態。
- 「設定 → 資料管理」顯示資料庫總占用（含 WAL）、背景圖片大小和已儲存統計的日期範圍。可清理 7、30、90、180、365 天前、自訂天數之前或全部已記錄的本機統計；清理前顯示具體截止時間，完成後回收空間。設定、背景圖片、Codex 原始日誌、帳戶額度及服務端統計保持不變。
- 清理截止時間會持續儲存，舊事件不會因重新啟動、日誌搬移或重寫而重新匯入。新用量正常記錄；少量檔案讀取進度仍會保留，因此清理全部統計後，資料庫不會變成 0 位元組。

## 開發與測試

```bash
swift test
swift build -c release
```

專案使用 Swift Package Manager，並透過 Sparkle 2 提供 App 內更新。提交變更前，請確認測試與 release 建置均已通過。打包與簽章流程請參閱 [發佈指南](docs/releasing.md)。

## 安全

請勿在公開 Issue 中貼上存取令牌、`auth.json`、完整電子郵件或原始 App Server 回應。若倉庫已啟用 GitHub Private Vulnerability Reporting，請使用 **Security → Advisories → Report a vulnerability** 私下回報。

## 常見問題（FAQ）

### 為什麼不支援 Claude Code？

![Anthropic 拒絕恢復 Claude Code 帳戶](docs/images/why-claude-code-is-not-supported.png)

## 開源授權

Codex Meter 使用 [MIT License](LICENSE) 授權。
