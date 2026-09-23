import Foundation

extension L10n {
    enum UpdateKey {
        case updates
        case updatesHint
        case currentVersion
        case currentVersionHint
        case appUpdates
        case automaticUpdateHint
        case debugBuildUpdateHint
        case checkForUpdates
        case checkingForUpdates
        case upToDate
        case updateCheckFailed
    }

    static func updateText(_ key: UpdateKey, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            switch key {
            case .updates: "更新"
            case .updatesHint: "检查并下载 Codex Meter 的新版本"
            case .currentVersion: "当前版本"
            case .currentVersionHint: "当前安装的 Codex Meter 版本"
            case .appUpdates: "软件更新"
            case .automaticUpdateHint: "启动时检查，此后每 6 小时检查一次"
            case .debugBuildUpdateHint: "调试版本不检查更新"
            case .checkForUpdates: "检查更新"
            case .checkingForUpdates: "正在检查更新..."
            case .upToDate: "已是最新版本"
            case .updateCheckFailed: "暂时无法检查更新"
            }
        case .traditionalChinese:
            switch key {
            case .updates: "更新"
            case .updatesHint: "檢查並下載 Codex Meter 的新版本"
            case .currentVersion: "目前版本"
            case .currentVersionHint: "目前安裝的 Codex Meter 版本"
            case .appUpdates: "軟體更新"
            case .automaticUpdateHint: "啟動時檢查，之後每 6 小時檢查一次"
            case .debugBuildUpdateHint: "除錯版本不檢查更新"
            case .checkForUpdates: "檢查更新"
            case .checkingForUpdates: "正在檢查更新..."
            case .upToDate: "已是最新版本"
            case .updateCheckFailed: "暫時無法檢查更新"
            }
        case .english:
            switch key {
            case .updates: "Updates"
            case .updatesHint: "Check for and download new Codex Meter versions"
            case .currentVersion: "Current version"
            case .currentVersionHint: "The installed Codex Meter version"
            case .appUpdates: "Software updates"
            case .automaticUpdateHint: "Checks at launch and every 6 hours afterward"
            case .debugBuildUpdateHint: "Update checks are disabled in debug builds"
            case .checkForUpdates: "Check for Updates"
            case .checkingForUpdates: "Checking for updates..."
            case .upToDate: "Codex Meter is up to date"
            case .updateCheckFailed: "Could not check for updates"
            }
        case .japanese:
            switch key {
            case .updates: "アップデート"
            case .updatesHint: "Codex Meter の新しいバージョンを確認してダウンロードします"
            case .currentVersion: "現在のバージョン"
            case .currentVersionHint: "インストール済みの Codex Meter バージョン"
            case .appUpdates: "ソフトウェアアップデート"
            case .automaticUpdateHint: "起動時と、その後 6 時間ごとに確認します"
            case .debugBuildUpdateHint: "デバッグ版ではアップデートを確認しません"
            case .checkForUpdates: "アップデートを確認"
            case .checkingForUpdates: "アップデートを確認中..."
            case .upToDate: "最新バージョンです"
            case .updateCheckFailed: "アップデートを確認できません"
            }
        case .korean:
            switch key {
            case .updates: "업데이트"
            case .updatesHint: "새 Codex Meter 버전을 확인하고 다운로드합니다"
            case .currentVersion: "현재 버전"
            case .currentVersionHint: "현재 설치된 Codex Meter 버전"
            case .appUpdates: "소프트웨어 업데이트"
            case .automaticUpdateHint: "실행 시 확인하고 이후 6시간마다 확인합니다"
            case .debugBuildUpdateHint: "디버그 빌드에서는 업데이트를 확인하지 않습니다"
            case .checkForUpdates: "업데이트 확인"
            case .checkingForUpdates: "업데이트 확인 중..."
            case .upToDate: "최신 버전입니다"
            case .updateCheckFailed: "업데이트를 확인할 수 없습니다"
            }
        case .spanish:
            switch key {
            case .updates: "Actualizaciones"
            case .updatesHint: "Busca y descarga nuevas versiones de Codex Meter"
            case .currentVersion: "Versión actual"
            case .currentVersionHint: "La versión instalada de Codex Meter"
            case .appUpdates: "Actualizaciones de software"
            case .automaticUpdateHint: "Comprueba al iniciar y después cada 6 horas"
            case .debugBuildUpdateHint: "Las actualizaciones están desactivadas en la versión de depuración"
            case .checkForUpdates: "Buscar actualizaciones"
            case .checkingForUpdates: "Buscando actualizaciones..."
            case .upToDate: "Codex Meter está actualizado"
            case .updateCheckFailed: "No se pudieron buscar actualizaciones"
            }
        }
    }

    static func updateAvailableStatus(version: String, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "发现新版本 \(version)"
        case .traditionalChinese: "發現新版本 \(version)"
        case .english: "Version \(version) is available"
        case .japanese: "バージョン \(version) を利用できます"
        case .korean: "버전 \(version) 사용 가능"
        case .spanish: "La versión \(version) está disponible"
        }
    }
}
