import Foundation

extension L10n {
    static func monthRange(_ count: Int, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "近 \(count) 个月"
        case .traditionalChinese: "近 \(count) 個月"
        case .english: "Last \(count) months"
        case .japanese: "直近 \(count) か月"
        case .korean: "최근 \(count)개월"
        case .spanish: "Últimos \(count) meses"
        }
    }

    static func monthLabel(
        _ date: Date, now: Date = Date(), language: AppLanguage,
        calendar: Calendar = UsageCalendar.calendar
    ) -> String {
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return text(.thisMonth, language: language)
        }
        let month = calendar.component(.month, from: date)
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            return "\(month) 月"
        case .japanese:
            return "\(month)月"
        case .korean:
            return "\(month)월"
        case .english, .spanish:
            let formatter = DateFormatter()
            formatter.locale = language.locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMM")
            return formatter.string(from: date)
        }
    }

    static func monthUsageTitle(_ month: String, language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese: "\(month)用量"
        case .english: "\(month) usage"
        case .japanese: "\(month)の使用量"
        case .korean: "\(month) 사용량"
        case .spanish: "Uso de \(month)"
        }
    }
}
