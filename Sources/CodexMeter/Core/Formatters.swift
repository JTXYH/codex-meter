import Foundation

enum MeterFormatters {
    static func tokens(
        _ value: Int64?,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        guard let value else { return L10n.text(.notAvailable, language: language) }
        let number = Double(value)
        let absolute = abs(number)
        let divisor: Double
        let suffix: String

        if language == .english || language == .spanish {
            switch absolute {
            case 1_000_000_000...:
                divisor = 1_000_000_000
                suffix = "B"
            case 1_000_000...:
                divisor = 1_000_000
                suffix = "M"
            case 1_000...:
                divisor = 1_000
                suffix = "K"
            default:
                return value.formatted(.number.locale(language.locale))
            }
        } else {
            switch absolute {
            case 100_000_000...:
                divisor = 100_000_000
                suffix = switch language {
                case .simplifiedChinese: "亿"
                case .traditionalChinese, .japanese: "億"
                case .korean: "억"
                case .english, .spanish: ""
                }
            case 10_000_000...:
                divisor = 10_000_000
                suffix = switch language {
                case .simplifiedChinese, .japanese: "千万"
                case .traditionalChinese: "千萬"
                case .korean: "천만"
                case .english, .spanish: ""
                }
            case 1_000_000...:
                divisor = 1_000_000
                suffix = switch language {
                case .simplifiedChinese, .japanese: "百万"
                case .traditionalChinese: "百萬"
                case .korean: "백만"
                case .english, .spanish: ""
                }
            case 10_000...:
                divisor = 10_000
                suffix = switch language {
                case .simplifiedChinese, .japanese: "万"
                case .traditionalChinese: "萬"
                case .korean: "만"
                case .english, .spanish: ""
                }
            case 1_000...:
                divisor = 1_000
                suffix = language == .korean ? "천" : "千"
            default:
                return value.formatted(.number.locale(language.locale))
            }
        }

        let scaled = number / divisor
        return scaled.formatted(
            .number.precision(.fractionLength(0...1)).locale(language.locale)
        ) + suffix
    }

    static func usd(_ value: Double) -> String {
        let safeValue = value.isFinite ? max(value, 0) : 0
        let fractionDigits = safeValue > 0 && safeValue < 0.01 ? 4 : 2
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: NSNumber(value: safeValue)) ?? "0.00"
        return "$\(number)"
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
            if minutes == 10_080 { return "每周额度" }
            if minutes == 1_440 { return "每日额度" }
            if minutes >= 1_440, minutes % 1_440 == 0 { return "\(minutes / 1_440) 天额度" }
            if minutes >= 60, minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
            return "\(minutes) 分钟额度"
        case .traditionalChinese:
            if minutes == 10_080 { return "每週額度" }
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

    static func resetCountdown(
        to date: Date,
        now: Date = Date(),
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        if interval <= 1 {
            switch language {
            case .simplifiedChinese: return "即将重置"
            case .traditionalChinese: return "即將重設"
            case .english: return "Resetting soon"
            case .japanese: return "まもなくリセット"
            case .korean: return "곧 재설정됩니다"
            case .spanish: return "Se restablecerá pronto"
            }
        }

        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / 1_440
        let hours = (totalMinutes % 1_440) / 60
        let minutes = totalMinutes % 60

        switch language {
        case .simplifiedChinese:
            if days > 0 { return hours > 0 ? "\(days) 天 \(hours) 小时后重置" : "\(days) 天后重置" }
            if hours > 0 { return minutes > 0 ? "\(hours) 小时 \(minutes) 分后重置" : "\(hours) 小时后重置" }
            return "\(max(1, minutes)) 分钟后重置"
        case .traditionalChinese:
            if days > 0 { return hours > 0 ? "\(days) 天 \(hours) 小時後重設" : "\(days) 天後重設" }
            if hours > 0 { return minutes > 0 ? "\(hours) 小時 \(minutes) 分後重設" : "\(hours) 小時後重設" }
            return "\(max(1, minutes)) 分鐘後重設"
        case .english:
            if days > 0 {
                let dayText = unit(days, singular: "day", plural: "days")
                return hours > 0 ? "Resets in \(dayText) \(unit(hours, singular: "hour", plural: "hours"))" : "Resets in \(dayText)"
            }
            if hours > 0 {
                let hourText = unit(hours, singular: "hour", plural: "hours")
                return minutes > 0 ? "Resets in \(hourText) \(unit(minutes, singular: "min", plural: "min"))" : "Resets in \(hourText)"
            }
            return "Resets in \(unit(max(1, minutes), singular: "min", plural: "min"))"
        case .japanese:
            if days > 0 { return hours > 0 ? "\(days) 日 \(hours) 時間後にリセット" : "\(days) 日後にリセット" }
            if hours > 0 { return minutes > 0 ? "\(hours) 時間 \(minutes) 分後にリセット" : "\(hours) 時間後にリセット" }
            return "\(max(1, minutes)) 分後にリセット"
        case .korean:
            if days > 0 { return hours > 0 ? "\(days)일 \(hours)시간 후 재설정" : "\(days)일 후 재설정" }
            if hours > 0 { return minutes > 0 ? "\(hours)시간 \(minutes)분 후 재설정" : "\(hours)시간 후 재설정" }
            return "\(max(1, minutes))분 후 재설정"
        case .spanish:
            if days > 0 {
                let dayText = unit(days, singular: "día", plural: "días")
                return hours > 0 ? "Se restablece en \(dayText) y \(unit(hours, singular: "hora", plural: "horas"))" : "Se restablece en \(dayText)"
            }
            if hours > 0 {
                let hourText = unit(hours, singular: "hora", plural: "horas")
                return minutes > 0 ? "Se restablece en \(hourText) y \(unit(minutes, singular: "min", plural: "min"))" : "Se restablece en \(hourText)"
            }
            return "Se restablece en \(unit(max(1, minutes), singular: "min", plural: "min"))"
        }
    }

    static func resetDate(
        _ date: Date,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        date.formatted(
            .dateTime.month(.abbreviated).day().hour().minute().locale(language.locale)
        )
    }

    static func day(
        _ date: Date,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        date.formatted(.dateTime.year().month().day().locale(language.locale))
    }

    static func elapsed(
        seconds: Int?,
        language: AppLanguage = .simplifiedChinese
    ) -> String {
        guard let seconds else { return L10n.text(.notAvailable, language: language) }
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        switch language {
        case .simplifiedChinese:
            if hours > 0 { return "\(hours) 小时 \(minutes) 分" }
            return "\(max(1, minutes)) 分钟"
        case .traditionalChinese:
            if hours > 0 { return "\(hours) 小時 \(minutes) 分" }
            return "\(max(1, minutes)) 分鐘"
        case .english:
            if hours > 0 {
                return "\(unit(hours, singular: "hr", plural: "hr")) \(unit(minutes, singular: "min", plural: "min"))"
            }
            return unit(max(1, minutes), singular: "min", plural: "min")
        case .japanese:
            if hours > 0 { return "\(hours) 時間 \(minutes) 分" }
            return "\(max(1, minutes)) 分"
        case .korean:
            if hours > 0 { return "\(hours)시간 \(minutes)분" }
            return "\(max(1, minutes))분"
        case .spanish:
            if hours > 0 {
                return "\(unit(hours, singular: "h", plural: "h")) \(unit(minutes, singular: "min", plural: "min"))"
            }
            return unit(max(1, minutes), singular: "min", plural: "min")
        }
    }

    private static func unit(_ value: Int, singular: String, plural: String) -> String {
        "\(value) \(value == 1 ? singular : plural)"
    }
}
