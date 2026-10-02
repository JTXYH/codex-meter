import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct UsagePeriodTests {
    @Test
    func hourlyBucketsCrossMidnightAndKeepMissingDistinctFromZero() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-01-01T16:30:00Z"))
        let hour = try #require(calendar.dateInterval(of: .hour, for: now)?.start)
        let result = PeriodUsageBuilder.periods(from: [
            PeriodTokenUsage(start: hour, usage: .zero),
            PeriodTokenUsage(start: hour.addingTimeInterval(-3_600), usage: usage(100, cost: 1)),
            PeriodTokenUsage(start: hour.addingTimeInterval(-1_800), usage: usage(200, cost: 2)),
            PeriodTokenUsage(start: hour.addingTimeInterval(3_600), usage: usage(999, cost: 9)),
        ], period: .hour, count: 6, endingAt: now, calendar: calendar)
        #expect(result.map { calendar.component(.hour, from: $0.start) } == [0, 23, 22, 21, 20, 19])
        #expect(result[0].usage == .zero)
        #expect(result[1].usage?.totalTokens == 300)
        #expect(result[1].usage?.apiEquivalentCostUSD == 3)
        #expect(result.dropFirst(2).allSatisfy { $0.usage == nil })
        #expect(UsageStatisticsL10n.label(hour, period: .hour, now: now, language: .simplifiedChinese, calendar: calendar) == "本小时")
        #expect(UsageStatisticsL10n.label(result[1].start, period: .hour, now: now, language: .simplifiedChinese, calendar: calendar) == "23:00")
        #expect(UsageStatisticsL10n.dateCaption(hour, period: .hour, language: .english, calendar: calendar).contains("00:00"))
    }

    @Test
    func hourlyBucketsSkipSpringGapAndSeparateRepeatedAutumnHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let spring = try #require(ISO8601DateFormatter().date(from: "2026-03-08T11:30:00Z"))
        let springHours = PeriodUsageBuilder.periods(from: [], period: .hour, count: 4, endingAt: spring, calendar: calendar)
        #expect(springHours.map { calendar.component(.hour, from: $0.start) } == [4, 3, 1, 0])
        let autumn = try #require(ISO8601DateFormatter().date(from: "2026-11-01T10:30:00Z"))
        let firstOne = autumn.addingTimeInterval(-2 * 3_600)
        let secondOne = autumn.addingTimeInterval(-3_600)
        let hours = PeriodUsageBuilder.periods(from: [
            PeriodTokenUsage(start: firstOne, usage: usage(100, cost: 1)),
            PeriodTokenUsage(start: secondOne, usage: usage(200, cost: 2)),
        ], period: .hour, count: 4, endingAt: autumn, calendar: calendar)
        #expect(hours.map { calendar.component(.hour, from: $0.start) } == [2, 1, 1, 0])
        #expect(Set(hours.map(\.start)).count == 4)
        #expect(hours.map { $0.usage?.totalTokens } == [nil, 200, 100, nil])
        let firstLabel = UsageStatisticsL10n.label(hours[2].start, period: .hour, now: secondOne, language: .english, calendar: calendar)
        let secondLabel = UsageStatisticsL10n.label(hours[1].start, period: .hour, now: autumn, language: .english, calendar: calendar)
        #expect(firstLabel != "This hour")
        #expect(firstLabel != secondLabel)
    }

    @Test
    func dailyBucketsRespectDSTAndKeepMissingDistinctFromZero() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        func date(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
        }
        let result = PeriodUsageBuilder.periods(from: [
            PeriodTokenUsage(start: date(9, 1), usage: .zero),
            PeriodTokenUsage(start: date(8, 1), usage: usage(100, cost: 1)),
            PeriodTokenUsage(start: date(8, 23), usage: usage(200, cost: 2)),
            PeriodTokenUsage(start: date(10), usage: usage(999, cost: 9)),
        ], period: .day, count: 3, endingAt: date(9), calendar: calendar)
        #expect(result.map { calendar.component(.day, from: $0.start) } == [9, 8, 7])
        #expect(result[0].start.timeIntervalSince(result[1].start) == 23 * 60 * 60)
        #expect(result[0].usage == .zero)
        #expect(result[1].usage?.totalTokens == 300)
        #expect(result[1].usage?.apiEquivalentCostUSD == 3)
        #expect(result[2].usage == nil)
        #expect(UsageStatisticsL10n.label(result[0].start, period: .day, now: date(9), language: .simplifiedChinese, calendar: calendar) == "今天")
        #expect(UsageStatisticsL10n.label(result[1].start, period: .day, now: date(9), language: .simplifiedChinese, calendar: calendar) == "昨天")
    }

    @Test
    func weeklyBucketsUseLocalMondaysAcrossYearBoundaryAndMatchModels() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        calendar.firstWeekday = 1
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        }
        let now = date(2026, 1, 5, 12)
        let records = [
            PeriodTokenUsage(start: date(2026, 1, 5), usage: .zero),
            PeriodTokenUsage(start: date(2026, 1, 4, 23), usage: usage(100, cost: 1)),
            PeriodTokenUsage(start: date(2025, 12, 29), usage: usage(200, cost: 2)),
            PeriodTokenUsage(start: date(2025, 12, 28, 23), usage: usage(40, cost: 0.5)),
            PeriodTokenUsage(start: date(2026, 1, 6), usage: usage(999, cost: 9)),
        ]
        let weeks = PeriodUsageBuilder.periods(from: records, period: .week, count: 4, endingAt: now, calendar: calendar)
        #expect(weeks.map(\.start) == [date(2026, 1, 5), date(2025, 12, 29), date(2025, 12, 22), date(2025, 12, 15)])
        #expect(weeks.map { $0.usage?.totalTokens } == [0, 300, 40, nil])
        #expect(weeks[0].usage == .zero)
        #expect(weeks[1].usage?.apiEquivalentCostUSD == 3)
        let models = ModelUsageBuilder.models(from: records.compactMap { record in
            record.usage.map { DailyModelTokenUsage(day: record.start, model: "test-model", usage: $0) }
        }, period: .week, containing: date(2026, 1, 4), calendar: calendar)
        #expect(models == [ModelTokenUsage(model: "test-model", usage: usage(300, cost: 3))])
        #expect(UsageStatisticsL10n.label(weeks[0].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "本周")
        #expect(UsageStatisticsL10n.label(weeks[1].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "上周")
        #expect(UsageStatisticsL10n.label(weeks[1].start, period: .week, now: date(2026, 1, 4, 23), language: .english, calendar: calendar) == "This week")
        #expect(UsageStatisticsL10n.label(weeks[2].start, period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "12/22–12/28")
        #expect(UsageStatisticsL10n.dateCaption(weeks[1].start, period: .week, language: .simplifiedChinese, calendar: calendar) == "2025/12/29–2026/1/4")
        #expect(UsageStatisticsL10n.footer(weeks[0], period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "本周统计截至当前时刻 · 周一至周日")
        #expect(UsageStatisticsL10n.footer(weeks[3], period: .week, now: now, language: .simplifiedChinese, calendar: calendar) == "该周暂无本机用量记录")
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
            let weeks = PeriodUsageBuilder.periods(from: [
                PeriodTokenUsage(start: current, usage: .zero),
                PeriodTokenUsage(start: previous, usage: usage(50, cost: 0.5)),
                PeriodTokenUsage(start: sundayStart, usage: usage(100, cost: 1)),
                PeriodTokenUsage(start: sundayEnd, usage: usage(200, cost: 2)),
            ], period: .week, count: 2, endingAt: current, calendar: calendar)
            #expect(weeks.map(\.start) == [current, previous])
            #expect(weeks.map { $0.usage?.totalTokens } == [0, 350])
            #expect(current.timeIntervalSince(previous) == Double(hours * 3_600))
            #expect(UsagePeriod.week.interval(containing: sundayEnd, calendar: calendar)?.end == current)
        }
    }

    @Test
    func quotaPercentageFollowsTheSelectedHourDayAndMonth() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parser = ISO8601DateFormatter()
        func date(_ value: String) -> Date { parser.date(from: value)! }
        let reset = date("2026-09-30T00:00:00Z")
        let readings = [
            ("2026-09-24T08:00:00Z", 30.0),
            ("2026-09-24T23:00:00Z", 32.0),
            ("2026-09-25T09:00:00Z", 33.0),
            ("2026-09-25T10:00:00Z", 40.0),
            ("2026-09-25T11:00:00Z", 49.0),
        ].map { time, used in
            LocalQuotaReading(date: date(time), bucketID: "codex", windowDurationMinutes: 10_080,
                              resetsAt: reset, usedPercent: used)
        }
        func amount(_ period: UsagePeriod, _ time: String) -> Double? {
            let interval = calendar.dateInterval(of: period.component, for: date(time))!
            return QuotaUsageBuilder.percentagePoints(from: readings, bucketID: "codex",
                                                      windowDurationMinutes: 10_080, in: interval)
        }
        #expect(amount(.day, "2026-09-24T12:00:00Z") == 2)
        #expect(amount(.day, "2026-09-25T12:00:00Z") == 17)
        #expect(amount(.hour, "2026-09-25T10:30:00Z") == 7)
        #expect(amount(.hour, "2026-09-25T11:30:00Z") == 9)
        #expect(amount(.month, "2026-09-25T12:00:00Z") == 49)
        #expect(amount(.day, "2026-09-23T12:00:00Z") == nil)
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
            PeriodTokenUsage(start: date(2024, 2, 29), usage: usage(100, cost: 1)),
            PeriodTokenUsage(start: date(2024, 12), usage: usage(200, cost: 2)),
            PeriodTokenUsage(start: now, usage: usage(40, cost: 0.4)),
            PeriodTokenUsage(start: date(2027, 1), usage: usage(999, cost: 9)),
        ]
        let result = PeriodUsageBuilder.periods(from: records, period: .year, count: 0, endingAt: now, calendar: calendar)
        #expect(result.map { calendar.component(.year, from: $0.start) } == [2026, 2025, 2024])
        #expect(result.map { $0.usage?.totalTokens } == [40, nil, 300])
        #expect(result[2].usage?.apiEquivalentCostUSD == 3)
        let empty = PeriodUsageBuilder.periods(from: [], period: .year, count: 0, endingAt: now, calendar: calendar)
        #expect(empty.count == 1 && empty[0].usage == nil)
        let months = PeriodUsageBuilder.periods(from: records, period: .month, count: 3, endingAt: now, calendar: calendar)
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
        #expect(settings.usageStatisticsPeriod == .month)
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

    private func usage(_ tokens: Int64, cost: Double) -> LocalTokenUsage {
        LocalTokenUsage(totalTokens: tokens, inputTokens: tokens, cachedInputTokens: 0,
                        cacheWriteInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0,
                        apiEquivalentCostUSD: cost)
    }
}

private struct PeriodTestLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
