import Foundation

enum QuotaStatusSettingsL10n {
    enum Key { case title, hint, restore }

    static func text(_ key: Key, language: AppLanguage) -> String {
        switch (language, key) {
        case (.simplifiedChinese, .title): "额度状态文案"
        case (.simplifiedChinese, .hint): "留空使用当前语言的默认文案，每项最多 40 个字符。"
        case (.simplifiedChinese, .restore): "恢复默认"
        case (.traditionalChinese, .title): "額度狀態文案"
        case (.traditionalChinese, .hint): "留空使用目前語言的預設文案，每項最多 40 個字元。"
        case (.traditionalChinese, .restore): "恢復預設"
        case (.english, .title): "Quota status messages"
        case (.english, .hint): "Leave blank to use the current language's defaults. Up to 40 characters each."
        case (.english, .restore): "Restore defaults"
        case (.japanese, .title): "割り当ての状態メッセージ"
        case (.japanese, .hint): "空欄の場合は現在の言語の既定文を使用します。各項目は40文字までです。"
        case (.japanese, .restore): "既定に戻す"
        case (.korean, .title): "할당량 상태 문구"
        case (.korean, .hint): "비워 두면 현재 언어의 기본 문구를 사용합니다. 항목당 최대 40자입니다."
        case (.korean, .restore): "기본값 복원"
        case (.spanish, .title): "Mensajes de estado de cuota"
        case (.spanish, .hint): "Déjalo vacío para usar el texto predeterminado del idioma actual. Máximo 40 caracteres por campo."
        case (.spanish, .restore): "Restablecer valores"
        }
    }
}
