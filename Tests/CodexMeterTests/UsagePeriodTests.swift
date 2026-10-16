import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct UsagePeriodTests {
    @Test
    func dailyBucketsRespectDSTAndKeepMissingDistinctFromZero() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        func date(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
        }
        let result = AccountUsageBuilder.periods(from: [
            DailyTokenUsage(date: date(9, 1), tokens: 0),
            DailyTokenUsage(date: date(8, 1), tokens: 100),
            DailyTokenUsage(date: date(8, 23), tokens: 200),
            DailyTokenUsage(date: date(10), tokens: 999),
        ], period: .day, count: 3, endingAt: date(9), calendar: calendar)
        #expect(result.map { calendar.component(.day, from: $0.start) } == [9, 8, 7])
        #expect(result[0].start.timeIntervalSince(result[1].start) == 23 * 60 * 60)
        #expect(result[0].tokens == 0)
        #expect(result[1].tokens == 300)
        #expect(result[2].tokens == nil)
        #expect(UsageStatisticsL10n.label(result[0].start, period: .day, now: date(9), language: .simplifiedChinese, calendar: calendar) == "今天")
        #expect(UsageStatisticsL10n.label(result[1].start, period: .day, now: date(9), language: .simplifiedChinese, calendar: calendar) == "昨天")
    }

    @Test
    func weeklyBucketsUseLocalMondaysAcrossYearBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        calendar.firstWeekday = 1
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        let now = date(2026, 1, 5, 12)
        let records = [
            DailyTokenUsage(date: date(2026, 1, 5), tokens: 0),
            DailyTokenUsage(date: date(2026, 1, 4, 23), tokens: 100),
            DailyTokenUsage(date: date(2025, 12, 29), tokens: 200),
            DailyTokenUsage(date: date(2025, 12, 28, 23), tokens: 40),
            DailyTokenUsage(date: date(2026, 1, 6), tokens: 999),
        ]
        let weeks = AccountUsageBuilder.periods(from: records, period: .week, count: 4, endingAt: now, calendar: calendar)
        #expect(weeks.map(\.start) == [date(2026, 1, 5), date(2025, 12, 29), date(2025, 12, 22), date(2025, 12, 15)])
        #expect(weeks.map { $0.tokens } == [0, 300, 40, nil])
        #expect(weeks[0].tokens == 0)
        #expect(UsageStatisticsL10n.label(weeks[0].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "本周")
        #expect(UsageStatisticsL10n.label(weeks[1].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "上周")
        #expect(UsageStatisticsL10n.label(weeks[1].start, period: .week, now: date(2026, 1, 4, 23), language: .english, calendar: calendar) == "This week")
        #expect(UsageStatisticsL10n.label(weeks[2].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "12/22–12/28")
        #expect(UsageStatisticsL10n.dateCaption(weeks[1].start, period: .week, language: .simplifiedChinese, calendar: calendar) == "2025/12/29–2026/1/4")

    }

    @Test
    func weeklyBucketsRespectBothDaylightSavingTransitions() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        for (month, monday, previousMonday, sunday, hours) in [(3, 9, 2, 8, 167), (11, 2, 26, 1, 169)] {
            let previousMonth = month == 11 ? 10 : month
            let current = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: monday)))
            let previous = try #require(calendar.date(from: DateComponents(year: 2026, month: previousMonth, day: previousMonday)))
            let sundayStart = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: sunday)))
            let sundayEnd = try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: sunday, hour: 23)))
            let weeks = AccountUsageBuilder.periods(from: [
                DailyTokenUsage(date: current, tokens: 0),
                DailyTokenUsage(date: previous, tokens: 50),
                DailyTokenUsage(date: sundayStart, tokens: 100),
                DailyTokenUsage(date: sundayEnd, tokens: 200),
            ], period: .week, count: 2, endingAt: current, calendar: calendar)
            #expect(weeks.map(\.start) == [current, previous])
            #expect(weeks.map { $0.tokens } == [0, 350])
            #expect(current.timeIntervalSince(previous) == Double(hours * 3_600))
            #expect(UsagePeriod.week.interval(containing: sundayEnd, calendar: calendar)?.end == current)
        }
    }

    @Test
    func allYearsAggregatesMonthsAndRetainsGapsAcrossLeapYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        func date(_ year: Int, _ month: Int, _ day: Int = 1) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        let now = date(2026, 1)
        let records = [
            DailyTokenUsage(date: date(2024, 2, 29), tokens: 100),
            DailyTokenUsage(date: date(2024, 12), tokens: 200),
            DailyTokenUsage(date: now, tokens: 40),
            DailyTokenUsage(date: date(2027, 1), tokens: 999),
        ]
        let result = AccountUsageBuilder.periods(from: records, period: .year, count: 0, endingAt: now, calendar: calendar)
        #expect(result.map { calendar.component(.year, from: $0.start) } == [2026, 2025, 2024])
        #expect(result.map { $0.tokens } == [40, nil, 300])
        let empty = AccountUsageBuilder.periods(from: [], period: .year, count: 0, endingAt: now, calendar: calendar)
        #expect(empty.count == 1 && empty[0].tokens == nil)
        let months = AccountUsageBuilder.periods(from: records, period: .month, count: 3, endingAt: now, calendar: calendar)
        #expect(months.map { calendar.component(.month, from: $0.start) } == [1, 12, 11])
        #expect(UsageStatisticsL10n.label(months[1].start, period: .month, now: now, language: .english, calendar: calendar).contains("2025"))
    }

    @Test @MainActor
    func preservesLegacyMonthlySettingsAndPersistsEachPeriodRange() throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let database = try SQLiteStore()
        let defaults = SQLitePreferences(database: database)
        defaults.set(12, forKey: "monthlyUsageMonthCount")
        defaults.set(false, forKey: "showMonthlyUsageCard")
        defaults.set(["monthlyUsage", "quota"], forKey: "dashboardSectionOrder")
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: PeriodTestLoginManager())
        #expect(settings.usageStatisticsPeriod == .day)
        #expect(settings.usageStatisticsRange(for: .month) == 12)
        #expect(!settings.showMonthlyUsageCard)
        #expect(settings.dashboardSectionOrder.first == .monthlyUsage)
        #expect(settings.usageStatisticsRange(for: .hour) == 24)
        #expect(settings.usageStatisticsRange(for: .week) == 4)
        settings.usageStatisticsPeriod = .hour
        #expect(settings.usageStatisticsPeriod == .day)
        settings.usageStatisticsPeriod = .week
        settings.setUsageStatisticsRange(6, for: .hour)
        settings.setUsageStatisticsRange(30, for: .day)
        settings.setUsageStatisticsRange(8, for: .week)
        settings.setUsageStatisticsRange(0, for: .year)
        let restored = AppSettings(defaults: defaults, launchAtLoginManager: PeriodTestLoginManager())
        #expect(restored.usageStatisticsPeriod == .week)
        #expect(restored.usageStatisticsRange(for: .hour) == 6)
        #expect(restored.usageStatisticsRange(for: .year) == 0)
        #expect(restored.usageStatisticsRange(for: .month) == 12)
        #expect(restored.usageStatisticsRange(for: .day) == 30)
        #expect(restored.usageStatisticsRange(for: .week) == 8)
        restored.setUsageStatisticsRange(-1, for: .day)
        restored.setUsageStatisticsRange(12, for: .year)
        restored.setUsageStatisticsRange(7, for: .hour)
        restored.setUsageStatisticsRange(-1, for: .week)
        #expect(restored.usageStatisticsRange(for: .day) == 7)
        #expect(restored.usageStatisticsRange(for: .year) == 3)
        #expect(restored.usageStatisticsRange(for: .hour) == 24)
        #expect(restored.usageStatisticsRange(for: .week) == 4)
    }

    @Test @MainActor
    func migratesHourlySelectionToDailyAndPreservesOtherPeriods() throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let defaults = SQLitePreferences(database: try SQLiteStore())
        defaults.set(14, forKey: "usageStatisticsDayCount")
        for period in UsagePeriod.allCases {
            defaults.set(period.rawValue, forKey: "usageStatisticsPeriod")
            let settings = AppSettings(defaults: defaults, launchAtLoginManager: PeriodTestLoginManager())
            let expected: UsagePeriod = period == .hour ? .day : period
            #expect(settings.usageStatisticsPeriod == expected)
            #expect(defaults.string(forKey: "usageStatisticsPeriod") == expected.rawValue)
            #expect(settings.usageStatisticsRange(for: .day) == 14)
        }
    }
}

private struct PeriodTestLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
