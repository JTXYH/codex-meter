import Foundation

extension L10n {
    enum UpdateKey {
        case currentVersion
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
            case .currentVersion: "当前版本"
            case .debugBuildUpdateHint: "调试版本不检查更新"
            case .checkForUpdates: "检查更新"
            case .checkingForUpdates: "正在检查更新..."
            case .upToDate: "已是最新版本"
            case .updateCheckFailed: "暂时无法检查更新"
            }
        case .traditionalChinese:
            switch key {
            case .currentVersion: "目前版本"
            case .debugBuildUpdateHint: "除錯版本不檢查更新"
            case .checkForUpdates: "檢查更新"
            case .checkingForUpdates: "正在檢查更新..."
            case .upToDate: "已是最新版本"
            case .updateCheckFailed: "暫時無法檢查更新"
            }
        case .english:
            switch key {
            case .currentVersion: "Current version"
            case .debugBuildUpdateHint: "Update checks are disabled in debug builds"
            case .checkForUpdates: "Check for Updates"
            case .checkingForUpdates: "Checking for updates..."
            case .upToDate: "Codex Meter is up to date"
            case .updateCheckFailed: "Could not check for updates"
            }
        case .japanese:
            switch key {
            case .currentVersion: "現在のバージョン"
            case .debugBuildUpdateHint: "デバッグ版ではアップデートを確認しません"
            case .checkForUpdates: "アップデートを確認"
            case .checkingForUpdates: "アップデートを確認中..."
            case .upToDate: "最新バージョンです"
            case .updateCheckFailed: "アップデートを確認できません"
            }
        case .korean:
            switch key {
            case .currentVersion: "현재 버전"
            case .debugBuildUpdateHint: "디버그 빌드에서는 업데이트를 확인하지 않습니다"
            case .checkForUpdates: "업데이트 확인"
            case .checkingForUpdates: "업데이트 확인 중..."
            case .upToDate: "최신 버전입니다"
            case .updateCheckFailed: "업데이트를 확인할 수 없습니다"
            }
        case .spanish:
            switch key {
            case .currentVersion: "Versión actual"
            case .debugBuildUpdateHint: "Las actualizaciones están desactivadas en la versión de depuración"
            case .checkForUpdates: "Buscar actualizaciones"
            case .checkingForUpdates: "Buscando actualizaciones..."
            case .upToDate: "Codex Meter está actualizado"
            case .updateCheckFailed: "No se pudieron buscar actualizaciones"
            }
        }
    }

}
