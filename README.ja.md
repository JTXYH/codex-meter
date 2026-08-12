# Codex Meter

[简体中文](README.md) · [繁體中文](README.zh-Hant.md) · [English](README.en.md) · 日本語 · [한국어](README.ko.md) · [Español](README.es.md)

Codex Meter は、ChatGPT/Codex アカウントの割り当てウィンドウと token アクティビティをすばやく確認できるネイティブ macOS メニューバーユーティリティです。ローカルの Codex CLI `app-server` JSON-RPC インターフェースからデータを読み取り、既存のログイン状態を再利用します。アクセストークンは読み取りも保存もしません。

> Codex Meter は独立したオープンソースプロジェクトです。OpenAI の公式製品ではなく、OpenAI によるサポートまたは推奨を意味しません。

## スクリーンショット

| 簡体中国語 · ライト | English · Dark |
| --- | --- |
| ![簡体中国語のライト表示](docs/images/overview-zh-Hans-light.png) | ![英語のダーク表示](docs/images/overview-en-dark.png) |

> 画像はすべて合成デモデータを使用しており、実際のアカウント情報は含まれません。

## 主な機能

- メニューバーに Codex の週間残量を常時表示
- すべての割り当てウィンドウ、残りの割合、リセットまでの時間を表示
- 今日、過去 7 日間、累計の token アクティビティと90日間ヒートマップ
- 今日の Token をローカル Codex セッションログから5秒ごとに差分更新し、入力、出力、キャッシュ入力、米ドルの API 換算料金を表示
- 手動更新、プリセット、1〜1,440分のカスタム更新間隔
- システム、ライト、ダークの外観
- Sparkle で 6 時間ごとに更新を確認し、App 内で検証、インストール、再起動
- アカウントのメールアドレスを初期状態でマスク表示
- 更新失敗時に前回の成功データを保持

## 対応言語

デフォルトは簡体中国語です。現在の対応言語：

- 簡体中国語 (`zh-Hans`)
- 繁体中国語 (`zh-Hant`)
- English (`en`)
- 日本語 (`ja`)
- 한국어 (`ko`)
- Español (`es`)

## ダウンロード

[⬇️ Codex Meter v1.1.0 をダウンロード（macOS Universal 2）](https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0-macOS.zip)

Apple Silicon と Intel Mac の両方に対応しています。ZIP を解凍し、`CodexMeter.app` を「アプリケーション」フォルダに移動してください。[v1.1.0 のリリースノート](https://github.com/JTXYH/codex-meter/releases/tag/v1.1.0)。

### 初回起動時に macOS にブロックされる場合

現在のビルドは ad-hoc 署名で、Apple のノータリゼーションは未実施です。初回起動時に「アプリにマルウェアが含まれていないことを Apple では確認できません」または「開発元を検証できません」と表示された場合は、まず本リポジトリの [GitHub Releases](https://github.com/JTXYH/codex-meter/releases) からダウンロードしたアプリであることを確認し、以下のいずれかの方法を使用してください。

**方法 1：Finder から開く**

1. Finder で「アプリケーション」を開き、`CodexMeter.app` を探します。
2. Control キーを押しながらアプリをクリックするか、右クリックして、「開く」を選びます。
3. 確認ダイアログでもう一度「開く」をクリックします。一度許可すれば、次回からはダブルクリックで通常どおり起動できます。

**方法 2：システム設定から許可する**

1. `CodexMeter.app` を一度ダブルクリックし、macOS の警告を閉じます。
2. Apple メニュー ** → システム設定 → プライバシーとセキュリティ** を開きます。
3. 「セキュリティ」まで下にスクロールし、Codex Meter のメッセージにある「このまま開く」をクリックします。
4. 求められた認証を完了し、「開く」をクリックします。「このまま開く」ボタンは、通常、アプリを開こうとした後の約 1 時間だけ表示されます。

詳細は [Apple サポート：Mac でアプリを安全に開く](https://support.apple.com/ja-jp/102445) を参照してください。macOS にアプリが「コンピュータを破損します」と明示された場合や、マルウェアが検出された場合は、警告を無視しないでください。現在のファイルを削除し、公式 Release から再度ダウンロードしてください。

## 動作要件

- macOS 14 Sonoma 以降
- [Codex CLI](https://github.com/openai/codex) がインストール済みで、ChatGPT アカウントでログイン済みであること
- Swift 6 / Xcode 16 以降（ソースからビルドする場合のみ）

Codex Meter は `PATH`、`~/.local/bin/codex`、`~/.npm-global/bin/codex`、Homebrew の一般的な場所、Codex/ChatGPT App 内の `codex` 実行ファイルを順に探します。

## インストール

リポジトリをクローンまたはダウンロードした後、次を実行します。

```bash
cd codex-meter
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

`dist/CodexMeter.app` が作成されます。直接開くか、「アプリケーション」フォルダに移動してください。

開発中は次のコマンドで直接実行できます。

```bash
swift run CodexMeter
```

## 使い方

1. Codex CLI を起動し、ChatGPT アカウントでログイン済みか確認します。
2. Codex Meter を起動すると、メニューバーにアイコンと週間残量が表示されます。
3. メニューバー項目をクリックし、割り当て、token アクティビティ、ヒートマップ、使用概要を確認します。
4. 右上の更新ボタンですぐにデータを更新できます。
5. マスクされたメールアドレスをクリックすると一時的に全体を表示します。パネルを閉じると再度マスクされます。
6. 左下の歯車から設定を開き、外観、言語、自動更新間隔を変更できます。
7. 右下の電源ボタンで終了します。

## データとプライバシー

- アカウント概要は `account/read` から取得します。
- 割り当てウィンドウは `account/rateLimits/read` から取得し、パーセントは各ウィンドウの使用済み割合です。
- Token アクティビティとヒートマップは `account/usage/read` から取得します。これらは割り当て上限とは異なります。
- 今日の Token 統計はローカル Codex セッションログの token カウントイベントのみを読み取り、会話内容は保存または表示しません。
- API 換算料金は [OpenAI が公開する GPT-5.6 の標準 API 料金](https://openai.com/api/pricing/) を使い、通常入力、キャッシュ読み取り、キャッシュ書き込み、出力、長文コンテキストを考慮して推定します。識別できない Codex 内部ルートは GPT-5.6 Sol 料金を使います。これは API 換算の推定値であり、ChatGPT サブスクリプションの実際の請求額ではありません。
- `auth.json` へのアクセス、アクセストークンの保存、サーバー応答全体の記録、追加データの送信は行いません。
- API Key または Amazon Bedrock ログインでは ChatGPT の割り当てやアクティビティが返らない場合があります。これらの指標には ChatGPT ログインを使用してください。

## 開発とテスト

```bash
swift test
swift build -c release
```

このプロジェクトは Swift Package Manager と Sparkle 2 による App 内更新を使用します。変更を送信する前に、テストと release ビルドが通ることを確認してください。

## セキュリティ

公開 Issue にアクセストークン、`auth.json`、メールアドレス全体、または App Server の生レスポンスを貼り付けないでください。GitHub Private Vulnerability Reporting が有効な場合は、**Security → Advisories → Report a vulnerability** から非公開で報告してください。

## よくある質問（FAQ）

### Claude Code がサポートされていないのはなぜですか？

![Anthropic が Claude Code アカウントの復旧を拒否した通知](docs/images/why-claude-code-is-not-supported.png)

## ライセンス

Codex Meter は [MIT License](LICENSE) で提供されます。
