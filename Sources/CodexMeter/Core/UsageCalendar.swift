import Foundation

/// A shared day boundary for account buckets and this device's live tokens.
/// The official clients perform usage-bucket date arithmetic in UTC. The profile
/// API supplies date-only labels, so a device's time zone must not reinterpret them.
enum UsageCalendar {
    static let timeZone = TimeZone(secondsFromGMT: 0)!
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    static func dayInterval(containing date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(start: start, duration: 86_400)
    }
}
