import Foundation

struct QuotaResetReadout: Equatable {
    let primary: String
    let secondary: String

    init(date: Date?, language: AppLanguage, now: Date = Date(), calendar: Calendar = .current) {
        guard let date else { primary = "—"; secondary = ""; return }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) {
            primary = time
            secondary = RedesignL10n.text(.today, language: language)
        } else {
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "yMMMd")
            primary = formatter.string(from: date)
            secondary = time
        }
    }
}
