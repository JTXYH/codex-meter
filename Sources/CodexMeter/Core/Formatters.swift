import Foundation

enum MeterFormatters {
    private static let usdPerCredit = Decimal(4) / Decimal(100)

    static func credits(
        _ balance: CreditBalance,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        switch balance {
        case .amount(let amount):
            let usdAmount = amount * usdPerCredit
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            formatter.positivePrefix = "$"
            formatter.negativePrefix = "-$"
            formatter.usesGroupingSeparator = true
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSDecimalNumber(decimal: usdAmount)) ?? "$0.00"
        case .unlimited:
            return L10n.text(.unlimitedCredits, language: language)
        case .unavailable:
            return L10n.text(.creditsBalanceUnavailable, language: language)
        }
    }

    static func quotaTitle(
        for window: RateLimitWindow,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        guard let minutes = window.windowDurationMinutes, minutes > 0 else {
            let name = window.bucketName.trimmingCharacters(in: .whitespacesAndNewlines)
            return switch language {
            case .simplifiedChinese: name.isEmpty ? "额度" : "\(name) 额度"
            case .traditionalChinese: name.isEmpty ? "額度" : "\(name) 額度"
            case .english: name.isEmpty ? "Quota" : "\(name) quota"
            case .japanese: name.isEmpty ? "割り当て" : "\(name) の割り当て"
            case .korean: name.isEmpty ? "할당량" : "\(name) 할당량"
            case .spanish: name.isEmpty ? "Cuota" : "Cuota de \(name)"
            }
        }
        switch language {
        case .simplifiedChinese:
            if minutes == 10_080 { return "周额度" }
            if minutes == 1_440 { return "每日额度" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440) 天额度" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
            return "\(minutes) 分钟额度"
        case .traditionalChinese:
            if minutes == 10_080 { return "週額度" }
            if minutes == 1_440 { return "每日額度" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440) 天額度" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) 小時額度" }
            return "\(minutes) 分鐘額度"
        case .english:
            if minutes == 10_080 { return "Weekly quota" }
            if minutes == 1_440 { return "Daily quota" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440)-day quota" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60)-hour quota" }
            return "\(minutes)-minute quota"
        case .japanese:
            if minutes == 10_080 { return "週間割り当て" }
            if minutes == 1_440 { return "1 日の割り当て" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440) 日間の割り当て" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) 時間の割り当て" }
            return "\(minutes) 分間の割り当て"
        case .korean:
            if minutes == 10_080 { return "주간 할당량" }
            if minutes == 1_440 { return "일일 할당량" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440)일 할당량" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60)시간 할당량" }
            return "\(minutes)분 할당량"
        case .spanish:
            if minutes == 10_080 { return "Cuota semanal" }
            if minutes == 1_440 { return "Cuota diaria" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "Cuota de \(minutes / 1_440) días" }
            if minutes >= 60, minutes % 60 == 0 { return "Cuota de \(minutes / 60) horas" }
            return "Cuota de \(minutes) minutos"
        }
    }

    static func day(
        _ date: Date,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        date.formatted(Date.FormatStyle(locale: language.locale, calendar: UsageCalendar.calendar,
                                        timeZone: UsageCalendar.timeZone).year().month().day())
    }

}
