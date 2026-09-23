import Foundation

enum FontL10n {
    enum Key: Int {
        case title, hint, contentCards, quotaCard, quotaHint, scope, allContent,
             value, heading, detail, reset, apply, preview, contentHint
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["字体", "实时调整主面板字号，额度卡片可独立设置。", "内容卡片", "额度卡片", "只调整额度卡片，不影响其他内容。", "调整范围", "全部内容卡片", "数值", "标题", "标签 / 说明", "恢复默认", "统一内容卡片", "实时预览", "包含面板标题和用量统计，不含额度卡片。"]
        case .traditionalChinese:
            values = ["字體", "即時調整主面板字級，額度卡片可獨立設定。", "內容卡片", "額度卡片", "只調整額度卡片，不影響其他內容。", "調整範圍", "全部內容卡片", "數值", "標題", "標籤 / 說明", "恢復預設", "統一內容卡片", "即時預覽", "包含面板標題和用量統計，不含額度卡片。"]
        case .english:
            values = ["Fonts", "Adjust panel text live, with separate sizes for the quota card.", "Content cards", "Quota card", "Only changes the quota card. Other content is unaffected.", "Apply to", "All content cards", "Values", "Titles", "Labels / notes", "Reset defaults", "Unify content cards", "Live preview", "Includes the panel heading and usage statistics, excluding quota."]
        case .japanese:
            values = ["文字", "パネルの文字サイズを即時変更。上限カードは個別に設定できます。", "統計カード", "上限カード", "上限カードのみ変更し、ほかの内容には影響しません。", "変更範囲", "すべての統計カード", "数値", "見出し", "ラベル / 説明", "初期値に戻す", "統計カードを統一", "プレビュー", "パネル見出しと使用統計を含み、上限カードは除きます。"]
        case .korean:
            values = ["글꼴", "패널 글자 크기를 즉시 변경하며 한도 카드는 별도로 설정합니다.", "통계 카드", "한도 카드", "한도 카드만 변경하며 다른 내용에는 영향을 주지 않습니다.", "적용 범위", "모든 통계 카드", "수치", "제목", "레이블 / 설명", "기본값 복원", "통계 카드 통일", "미리 보기", "패널 제목과 사용 통계를 포함하며 한도 카드는 제외합니다."]
        case .spanish:
            values = ["Texto", "Ajusta el texto del panel, con tamaños independientes para la cuota.", "Tarjetas de uso", "Tarjeta de cuota", "Solo cambia la tarjeta de cuota, sin afectar al resto.", "Aplicar a", "Todas las tarjetas de uso", "Valores", "Títulos", "Etiquetas / notas", "Restablecer", "Unificar tarjetas de uso", "Vista previa", "Incluye el título del panel y las estadísticas, sin la cuota."]
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

    static func section(_ section: DashboardSection, language: AppLanguage) -> String {
        let key: L10n.Key = switch section {
        case .quota: .showQuotaCard
        case .tokenActivity: .todayDetails
        case .activityOverview: .activityOverview
        case .monthlyUsage: .monthlyUsage
        case .usageHeatmap: .lastOneHundredTwentyDays
        case .usageSummary: .usageOverview
        case .creditsBalance: .creditsBalance
        }
        return L10n.text(key, language: language)
    }
}
