import Foundation

enum TodayQuotaUsageL10n {
    static func title(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "额度消耗"
        case .traditionalChinese: "額度消耗"
        case .english: "Quota used"
        case .japanese: "利用枠消費"
        case .korean: "한도 사용"
        case .spanish: "Cuota usada"
        }
    }

    static func summary(tokens: Int64?, percent: Double?, language: AppLanguage) -> String {
        guard tokens != nil else { return L10n.text(.calculatingUsage, language: language) }
        guard let percent, percent.isFinite, percent >= 0 else { return "—" }
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(0...2))
            .locale(language.locale)
        let amount = percent > 0 && percent < 0.01
            ? "<\(0.01.formatted(style))"
            : percent.formatted(style)
        return "\(amount)%"
    }

    static func explanation(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "根据所选时段的额度变化估算，其他设备用量也可能计入。"
        case .traditionalChinese: "根據所選時段的額度變化估算，其他裝置用量也可能計入。"
        case .english: "Estimated from quota changes during the selected period; usage from other devices may be included."
        case .japanese: "選択した期間の利用枠の変化から推定します。他の端末の使用量も含まれる場合があります。"
        case .korean: "선택한 기간의 한도 변화로 추정하며, 다른 기기 사용량도 포함될 수 있습니다."
        case .spanish: "Estimación basada en los cambios de cuota del periodo seleccionado; puede incluir otros dispositivos."
        }
    }

    static func unavailable(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "该时段暂无可计算的额度记录。"
        case .traditionalChinese: "該時段暫無可計算的額度紀錄。"
        case .english: "No usable quota records for this period."
        case .japanese: "この期間には利用できる利用枠の記録がありません。"
        case .korean: "이 기간에 계산 가능한 한도 기록이 없습니다."
        case .spanish: "No hay registros de cuota utilizables para este periodo."
        }
    }
}
