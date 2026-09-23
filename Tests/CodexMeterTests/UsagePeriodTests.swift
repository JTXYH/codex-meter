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
        settings.usageStatisticsPeriod = .hour
        settings.setUsageStatisticsRange(6, for: .hour)
        settings.setUsageStatisticsRange(30, for: .day)
        settings.setUsageStatisticsRange(0, for: .year)
        let restored = AppSettings(defaults: defaults, launchAtLoginManager: PeriodTestLoginManager())
        #expect(restored.usageStatisticsPeriod == .hour)
        #expect(restored.usageStatisticsRange(for: .hour) == 6)
        #expect(restored.usageStatisticsRange(for: .year) == 0)
        #expect(restored.usageStatisticsRange(for: .month) == 12)
        #expect(restored.usageStatisticsRange(for: .day) == 30)
        restored.setUsageStatisticsRange(-1, for: .day)
        restored.setUsageStatisticsRange(12, for: .year)
        restored.setUsageStatisticsRange(7, for: .hour)
        #expect(restored.usageStatisticsRange(for: .day) == 7)
        #expect(restored.usageStatisticsRange(for: .year) == 3)
        #expect(restored.usageStatisticsRange(for: .hour) == 24)
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
