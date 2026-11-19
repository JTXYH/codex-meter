import Foundation

/// Pacific and local readouts always describe the same instant, including at midnight.
struct PacificClockReadout: Equatable {
    let pacificDate: String
    let pacificTime: String
    let timeZoneAbbreviation: String
    let localTime: String
    let accessibilityValue: String

    init(date: Date, language: AppLanguage, localTimeZone: TimeZone = .autoupdatingCurrent) {
        // Named zone follows PST/PDT transitions; a fixed UTC offset cannot do this.
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let calendar = Calendar(identifier: .gregorian)
        let locale = Locale(identifier: "en_US_POSIX")
        func dateText(in timeZone: TimeZone) -> String {
            date.formatted(Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                locale: locale, timeZone: timeZone, calendar: calendar))
        }
        func timeText(in timeZone: TimeZone) -> String {
            date.formatted(Date.VerbatimFormatStyle(
                format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
                locale: locale, timeZone: timeZone, calendar: calendar))
        }
        let pacificDay = dateText(in: pacific)
        let localDay = dateText(in: localTimeZone)
        let weekday = date.formatted(Date.FormatStyle(locale: language.locale, calendar: calendar, timeZone: pacific)
            .weekday(.abbreviated))
        pacificDate = "\(pacificDay) · \(weekday)"
        pacificTime = timeText(in: pacific)
        // Foundation's abbreviation can be localized as GMT-7/GMT-8; retain the Pacific names.
        timeZoneAbbreviation = pacific.isDaylightSavingTime(for: date) ? "PDT" : "PST"
        let localClock = timeText(in: localTimeZone)
        localTime = localDay == pacificDay ? localClock : "\(localDay) · \(localClock)"
        accessibilityValue = "\(pacificDate), \(pacificTime) \(timeZoneAbbreviation). \(SettingsCopy.text("localTime", language: language)), \(localDay), \(localClock)"
    }
}
