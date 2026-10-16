import Foundation
import Testing
@testable import CodexMeter

struct AccountUsageTests {
    @Test
    func aggregatesOnlyReturnedDaysAndDistinguishesMissingFromZero() throws {
        let calendar = calendar("Asia/Taipei")
        let now = date(2026, 10, 15, calendar: calendar)
        let records = [
            DailyTokenUsage(date: date(2026, 10, 14, calendar: calendar), tokens: 764_709_144),
            DailyTokenUsage(date: date(2026, 10, 13, calendar: calendar), tokens: 0),
            DailyTokenUsage(date: date(2026, 10, 16, calendar: calendar), tokens: 999),
        ]
        let days = AccountUsageBuilder.periods(from: records, period: .day, count: 4, endingAt: now, calendar: calendar)
        #expect(days.map(\.tokens) == [nil, 764_709_144, 0, nil])
        #expect(days.map(\.recordedDays) == [0, 1, 1, 0])
        let month = try #require(AccountUsageBuilder.periods(
            from: records, period: .month, count: 1, endingAt: now, calendar: calendar
        ).first)
        #expect(month.tokens == 764_709_144)
        #expect(month.recordedDays == 2)
        #expect(month.expectedDays == 15)
        #expect(month.isPartial)
        #expect(AccountUsageBuilder.periods(from: records, period: .hour, count: 24).isEmpty)
    }

    @Test
    func preservesCalendarDayBucketsAcrossDSTAndYearBoundaries() throws {
        let calendar = calendar("America/Los_Angeles")
        let now = date(2026, 3, 9, calendar: calendar)
        let monday = date(2026, 3, 2, calendar: calendar)
        let records = (0..<7).map { offset in
            DailyTokenUsage(date: calendar.date(byAdding: .day, value: offset, to: monday)!, tokens: 100)
        }
        let weeks = AccountUsageBuilder.periods(from: records, period: .week, count: 2, endingAt: now, calendar: calendar)
        #expect(weeks[0].tokens == nil)
        #expect(weeks[1].tokens == 700)
        #expect(weeks[1].recordedDays == 7)
        #expect(weeks[1].expectedDays == 7)
        #expect(!weeks[1].isPartial)
        let years = AccountUsageBuilder.periods(from: [
            DailyTokenUsage(date: date(2024, 2, 29, calendar: calendar), tokens: 50),
            DailyTokenUsage(date: date(2026, 1, 1, calendar: calendar), tokens: 100),
        ], period: .year, count: 0, endingAt: now, calendar: calendar)
        #expect(years.map(\.tokens) == [100, nil, 50])
        #expect(years[2].expectedDays == 366)
    }

    @Test
    func normalizesSameDayBucketsWithoutInventingBreakdowns() throws {
        let calendar = calendar("Asia/Taipei")
        let day = date(2026, 10, 14, calendar: calendar)
        // The parser represents date-only buckets at noon, even on a morning refresh.
        let buckets = [
            DailyTokenUsage(date: day.addingTimeInterval(12 * 3_600), tokens: .max),
            DailyTokenUsage(date: day, tokens: 10),
        ]
        let result = try #require(AccountUsageBuilder.periods(
            from: buckets, period: .day, count: 1,
            endingAt: day.addingTimeInterval(8 * 3_600), calendar: calendar
        ).first)
        #expect(result.tokens == .max)
        #expect(result.recordedDays == 1)
        #expect(!result.isPartial)
    }

    private func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
