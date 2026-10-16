import Foundation

enum UsageDayL10n {
    static func title(language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: "统计时区：UTC"
        case .traditionalChinese: "統計時區：UTC"
        case .english: "Usage time zone: UTC"
        case .japanese: "集計タイムゾーン：UTC"
        case .korean: "사용량 집계 시간대: UTC"
        case .spanish: "Zona horaria del uso: UTC"
        }
    }

    static func date(_ date: Date, template: String, language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = UsageCalendar.calendar
        formatter.timeZone = UsageCalendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func help(containing date: Date, period: UsagePeriod = .day, language: AppLanguage,
                     localTimeZone: TimeZone = .current) -> String {
        guard let interval = period.interval(containing: date, calendar: UsageCalendar.calendar) else { return title(language: language) }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = localTimeZone
        formatter.calendar = localCalendar
        formatter.timeZone = localTimeZone
        formatter.setLocalizedDateFormatFromTemplate("yMMMdHHmm")
        let start = formatter.string(from: interval.start) + " (\(offset(localTimeZone, at: interval.start)))"
        let end = formatter.string(from: interval.end) + " (\(offset(localTimeZone, at: interval.end)))"
        let range = "\(start) – \(end)"
        let zone = localTimeZone.identifier
        switch language {
        case .simplifiedChinese:
            return "按 UTC 00:00 换日。\n本地时间（\(zone)）：\n\(range)\n不含结束时刻。"
        case .traditionalChinese:
            return "以 UTC 00:00 換日。\n本地時間（\(zone)）：\n\(range)\n不含結束時刻。"
        case .english:
            return "Usage days change at 00:00 UTC.\nLocal time (\(zone)):\n\(range)\nThe end time is not included."
        case .japanese:
            return "使用量の日付は UTC 00:00 に切り替わります。\n現地時間（\(zone)）：\n\(range)\n終了時刻は含みません。"
        case .korean:
            return "사용량 날짜는 UTC 00:00에 바뀝니다.\n현지 시간 (\(zone)):\n\(range)\n종료 시각은 포함하지 않습니다."
        case .spanish:
            return "El día de uso cambia a las 00:00 UTC.\nHora local (\(zone)):\n\(range)\nLa hora de fin no está incluida."
        }
    }

    private static func offset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let minutes = abs(seconds) / 60
        return String(format: "UTC%@%02d:%02d", seconds < 0 ? "-" : "+", minutes / 60, minutes % 60)
    }
}
