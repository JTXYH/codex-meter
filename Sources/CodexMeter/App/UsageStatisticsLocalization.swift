import Foundation

enum UsageStatisticsL10n {
    enum Key: Int {
        case period, daily, monthly, yearly, today, yesterday, thisYear, allYears
        case currentDay, currentYear, noDay, noYear, localRecords, rangeHint
        case hourly, thisHour, currentHour, noHour
    }

    static func text(_ key: Key, language: AppLanguage) -> String {
        let values: [String]
        switch language {
        case .simplifiedChinese:
            values = ["统计周期", "每日", "每月", "每年", "今天", "昨天", "今年", "全部年份", "今日统计截至当前时刻", "今年统计截至当前时刻", "该日暂无本机用量记录", "该年暂无本机用量记录", "本机用量记录", "包含当前周期，从新到旧排列；分别记住各周期的范围"]
        case .traditionalChinese:
            values = ["統計週期", "每日", "每月", "每年", "今天", "昨天", "今年", "全部年份", "今日統計截至目前", "今年統計截至目前", "該日暫無本機用量紀錄", "該年暫無本機用量紀錄", "本機用量紀錄", "包含目前週期，由新到舊排列；分別記住各週期的範圍"]
        case .english:
            values = ["Period", "Daily", "Monthly", "Yearly", "Today", "Yesterday", "This year", "All years", "Today, up to now", "This year, up to now", "No local usage records for this day", "No local usage records for this year", "Local usage records", "Includes the current period, newest first. Ranges are saved separately."]
        case .japanese:
            values = ["集計単位", "日別", "月別", "年別", "今日", "昨日", "今年", "すべての年", "本日の現在までの集計", "今年の現在までの集計", "この日のローカル使用記録はありません", "この年のローカル使用記録はありません", "ローカル使用記録", "現在の期間を含め、新しい順に表示。範囲は単位ごとに保存します。"]
        case .korean:
            values = ["집계 단위", "일별", "월별", "연도별", "오늘", "어제", "올해", "전체 연도", "오늘 현재까지의 통계", "올해 현재까지의 통계", "이 날짜의 로컬 사용 기록이 없습니다", "이 연도의 로컬 사용 기록이 없습니다", "로컬 사용 기록", "현재 기간을 포함하여 최신순으로 표시하며 범위를 각각 저장합니다."]
        case .spanish:
            values = ["Agrupación", "Diario", "Mensual", "Anual", "Hoy", "Ayer", "Este año", "Todos los años", "Hoy, hasta ahora", "Este año, hasta ahora", "Sin registros locales de uso de este día", "Sin registros locales de uso de este año", "Registros de uso local", "Incluye el periodo actual, del más reciente al más antiguo. Cada rango se guarda por separado."]
        }
        if key.rawValue < values.count { return values[key.rawValue] }
        let hourly: [String]
        switch language {
        case .simplifiedChinese: hourly = ["每小时", "本小时", "本小时统计截至当前时刻", "该小时暂无本机用量记录"]
        case .traditionalChinese: hourly = ["每小時", "本小時", "本小時統計截至目前", "該小時暫無本機用量紀錄"]
        case .english: hourly = ["Hourly", "This hour", "This hour, up to now", "No local usage records for this hour"]
        case .japanese: hourly = ["時間別", "現在", "この時間の現在までの集計", "この時間のローカル使用記録はありません"]
        case .korean: hourly = ["시간별", "현재 시간", "현재 시간의 지금까지 통계", "이 시간의 로컬 사용 기록이 없습니다"]
        case .spanish: hourly = ["Por hora", "Esta hora", "Esta hora, hasta ahora", "Sin registros locales de uso de esta hora"]
        }
        return hourly[key.rawValue - values.count]
    }

    static func period(_ period: UsagePeriod, language: AppLanguage) -> String {
        let key: Key
        switch period {
        case .hour: key = .hourly
        case .day: key = .daily
        case .month: key = .monthly
        case .year: key = .yearly
        }
        return text(key, language: language)
    }

    static func range(_ count: Int, period: UsagePeriod, language: AppLanguage) -> String {
        if period == .month { return L10n.monthRange(count, language: language) }
        if period == .year && count == 0 { return text(.allYears, language: language) }
        if period == .hour {
            switch language {
            case .simplifiedChinese: return "近 \(count) 小时"
            case .traditionalChinese: return "近 \(count) 小時"
            case .english: return "Last \(count) hours"
            case .japanese: return "直近 \(count) 時間"
            case .korean: return "최근 \(count)시간"
            case .spanish: return "Últimas \(count) horas"
            }
        }
        let isDay = period == .day
        switch language {
        case .simplifiedChinese, .traditionalChinese: return "近 \(count) \(isDay ? "天" : "年")"
        case .english: return "Last \(count) \(isDay ? "days" : "years")"
        case .japanese: return "直近 \(count) \(isDay ? "日" : "年")"
        case .korean: return "최근 \(count)\(isDay ? "일" : "년")"
        case .spanish: return "Últimos \(count) \(isDay ? "días" : "años")"
        }
    }

    static func label(
        _ date: Date, period: UsagePeriod, now: Date = Date(), language: AppLanguage,
        calendar: Calendar = .current, compact: Bool = false
    ) -> String {
        if period == .hour {
            if !compact, calendar.isDate(date, equalTo: now, toGranularity: .hour) {
                return text(.thisHour, language: language)
            }
            return hourLabel(date, language: language, calendar: calendar, compact: compact)
        }
        if calendar.isDate(date, equalTo: now, toGranularity: period.component) {
            if period == .month { return L10n.text(.thisMonth, language: language) }
            return text(period == .day ? .today : .thisYear, language: language)
        }
        if period == .day, !compact,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return text(.yesterday, language: language)
        }
        let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
        if period == .month && (sameYear || compact) {
            return L10n.monthLabel(date, now: now, language: language, calendar: calendar)
        }
        let template: String
        switch period {
        case .hour: template = "Hm"
        case .day: template = compact ? "d" : sameYear ? "Md" : "yMd"
        case .month: template = "yMMM"
        case .year: template = "y"
        }
        return formattedDate(date, template: template, language: language, calendar: calendar)
    }

    static func dateCaption(_ date: Date, period: UsagePeriod, language: AppLanguage, calendar: Calendar = .current) -> String {
        let template: String
        switch period {
        case .hour, .day: template = "yMd"
        case .month: template = "yMMM"
        case .year: template = "y"
        }
        let day = formattedDate(date, template: template, language: language, calendar: calendar)
        return period == .hour ? "\(day) \(hourLabel(date, language: language, calendar: calendar))" : day
    }

    static func footer(
        _ record: PeriodTokenUsage, period: UsagePeriod, now: Date = Date(), language: AppLanguage
    ) -> String {
        guard record.usage != nil else {
            if period == .hour { return text(.noHour, language: language) }
            return period == .month ? L10n.text(.monthStatisticsUnavailable, language: language)
                : text(period == .day ? .noDay : .noYear, language: language)
        }
        if Calendar.current.isDate(record.start, equalTo: now, toGranularity: period.component) {
            if period == .hour { return text(.currentHour, language: language) }
            return period == .month ? L10n.text(.monthStatisticsCurrent, language: language)
                : text(period == .day ? .currentDay : .currentYear, language: language)
        }
        return "\(dateCaption(record.start, period: period, language: language)) · \(text(.localRecords, language: language))"
    }

    private static func hourLabel(_ date: Date, language: AppLanguage, calendar: Calendar, compact: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        // Distinguish the two occurrences of a repeated hour when daylight saving time ends.
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour]
        let repeated = [-3_600.0, 3_600.0].contains { offset in
            calendar.dateComponents(components, from: date) == calendar.dateComponents(components, from: date.addingTimeInterval(offset))
        }
        formatter.dateFormat = compact ? "HH" : repeated ? "HH:mm z" : "HH:mm"
        return formatter.string(from: date)
    }

    private static func formattedDate(_ date: Date, template: String, language: AppLanguage, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
}
