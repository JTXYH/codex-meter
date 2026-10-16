import Foundation

enum FontL10n {
    enum Key: Int {
        case scope, allContent, value, heading, detail, reset, preview
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["调整范围", "全部内容卡片", "数值", "标题", "标签 / 说明", "恢复默认", "实时预览"]
        case .traditionalChinese:
            values = ["調整範圍", "全部內容卡片", "數值", "標題", "標籤 / 說明", "恢復預設", "即時預覽"]
        case .english:
            values = ["Apply to", "All content cards", "Values", "Titles", "Labels / notes", "Reset defaults", "Live preview"]
        case .japanese:
            values = ["変更範囲", "すべての統計カード", "数値", "見出し", "ラベル / 説明", "初期値に戻す", "プレビュー"]
        case .korean:
            values = ["적용 범위", "모든 통계 카드", "수치", "제목", "레이블 / 설명", "기본값 복원", "미리 보기"]
        case .spanish:
            values = ["Aplicar a", "Todas las tarjetas de uso", "Valores", "Títulos", "Etiquetas / notas", "Restablecer", "Vista previa"]
        }
        return values[key.rawValue]
    }

    static func role(_ role: MeterTextRole, language: AppLanguage) -> String {
        let key: Key = switch role {
        case .value: .value
        case .title: .heading
        case .detail: .detail
        }
        return text(key, language: language)
    }

}
