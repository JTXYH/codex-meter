import Foundation
import Testing
@testable import CodexMeter

struct CodexResponseParserTests {
    @Test
    func parsesAccountWindowsAndUsage() throws {
        let account = Data(#"{"id":1,"result":{"account":{"type":"chatgpt","email":"tester@example.com","planType":"plus"},"requiresOpenaiAuth":true}}"#.utf8)
        let limits = Data(#"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1786604934},"secondary":{"usedPercent":78,"windowDurationMins":10080,"resetsAt":1786704934},"credits":{"hasCredits":false,"unlimited":false,"balance":"0"},"planType":"plus"},"rateLimitsByLimitId":{"codex":{"limitId":"codex","limitName":null,"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1786604934},"secondary":{"usedPercent":78,"windowDurationMins":10080,"resetsAt":1786704934},"credits":{"hasCredits":false,"unlimited":false,"balance":"0"},"planType":"plus"}}}}"#.utf8)
        let usage = Data(#"{"id":3,"result":{"summary":{"lifetimeTokens":1253637101,"peakDailyTokens":105004229,"longestRunningTurnSec":22847,"currentStreakDays":15,"longestStreakDays":25},"dailyUsageBuckets":[{"startDate":"2026-08-05","tokens":16593809},{"startDate":"2026-08-06","tokens":105004229}]}}"#.utf8)

        let snapshot = try CodexResponseParser.parse(
            accountData: account,
            rateLimitsData: limits,
            usageData: usage,
            fetchedAt: Date(timeIntervalSince1970: 1_786_600_000)
        )

        #expect(snapshot.account?.email == "tester@example.com")
        #expect(snapshot.account?.displayPlan == "Plus")
        #expect(snapshot.rateLimitBuckets.count == 1)
        #expect(snapshot.rateLimitBuckets.first?.hasCredits == false)
        #expect(snapshot.rateLimitBuckets.first?.unlimitedCredits == false)
        #expect(snapshot.rateLimitBuckets.first?.creditBalance == "0")
        #expect(snapshot.creditsBalance == .amount(0))
        #expect(snapshot.allLimitWindows.count == 2)
        #expect(snapshot.primaryWindow?.windowDurationMinutes == 300)
        #expect(snapshot.primaryWindow?.remainingPercent == 75)
        #expect(snapshot.fiveHourWindow?.remainingPercent == 75)
        #expect(snapshot.weeklyWindow?.windowDurationMinutes == 10_080)
        #expect(snapshot.featuredWindow?.remainingPercent == 22)
        #expect(snapshot.quotaCardPrimaryWindow?.remainingPercent == 75)
        #expect(snapshot.quotaCardSecondaryWindow?.remainingPercent == 22)
        #expect(snapshot.usageSummary?.lifetimeTokens == 1_253_637_101)
        #expect(snapshot.dailyUsage.count == 2)
        #expect(snapshot.tokenUsage(on: DateOnlyParser.date(from: "2026-08-06")!)?.tokens == 105_004_229)
    }

    @Test
    func fallsBackToSingleRateLimitView() throws {
        let account = Data(#"{"id":1,"result":{"account":null,"requiresOpenaiAuth":false}}"#.utf8)
        let limits = Data(#"{"id":2,"result":{"rateLimits":{"limitId":null,"limitName":null,"primary":{"usedPercent":120,"windowDurationMins":60,"resetsAt":1786604934},"secondary":null,"credits":null,"planType":null}}}"#.utf8)
        let usage = Data(#"{"id":3,"result":{"summary":null,"dailyUsageBuckets":null}}"#.utf8)

        let snapshot = try CodexResponseParser.parse(
            accountData: account,
            rateLimitsData: limits,
            usageData: usage
        )

        #expect(snapshot.rateLimitBuckets.first?.id == "codex")
        #expect(snapshot.creditsBalance == .unavailable)
        #expect(snapshot.primaryWindow?.clampedUsedPercent == 100)
        #expect(snapshot.primaryWindow?.remainingPercent == 0)
        #expect(snapshot.dailyUsage.isEmpty)
    }

    @Test
    func promotesWeeklyCodexQuotaWithoutBorrowingSparkFiveHourWindow() throws {
        let account = Data(#"{"id":1,"result":{"account":{"type":"chatgpt"}}}"#.utf8)
        let limits = Data(#"""
        {"id":2,"result":{"rateLimitsByLimitId":{
            "codex_bengalfox":{
                "limitName":"GPT-5.3-Codex-Spark",
                "primary":{"usedPercent":0,"windowDurationMins":300},
                "secondary":{"usedPercent":10,"windowDurationMins":10080}
            },
            "codex":{
                "primary":{"usedPercent":38,"windowDurationMins":10080,"resetsAt":1786704934},
                "secondary":null
            }
        }}}
        """#.utf8)
        let usage = Data(#"{"id":3,"result":{"summary":null}}"#.utf8)

        let snapshot = try CodexResponseParser.parse(
            accountData: account,
            rateLimitsData: limits,
            usageData: usage
        )

        #expect(snapshot.allLimitWindows.count == 3)
        #expect(snapshot.fiveHourWindow == nil)
        #expect(snapshot.primaryWindow?.bucketID == "codex")
        #expect(snapshot.quotaCardPrimaryWindow?.windowDurationMinutes == 10_080)
        #expect(snapshot.quotaCardPrimaryWindow?.remainingPercent == 62)
        #expect(snapshot.quotaCardSecondaryWindow == nil)
        #expect(snapshot.featuredWindow?.remainingPercent == 62)
        let window = try #require(snapshot.quotaCardPrimaryWindow)
        #expect(MeterFormatters.quotaTitle(for: window) == "周额度")
    }

    @Test
    func doesNotBorrowWeeklyWindowFromAnotherBucket() throws {
        let snapshot = try CodexResponseParser.parse(
            accountData: Data(#"{"result":{"account":null}}"#.utf8),
            rateLimitsData: Data(#"""
            {"result":{"rateLimitsByLimitId":{
                "codex":{"primary":{"usedPercent":25,"windowDurationMins":300}},
                "codex_bengalfox":{"secondary":{"usedPercent":80,"windowDurationMins":10080}}
            }}}
            """#.utf8),
            usageData: Data(#"{"result":{}}"#.utf8)
        )

        #expect(snapshot.fiveHourWindow?.remainingPercent == 75)
        #expect(snapshot.weeklyWindow == nil)
        #expect(snapshot.quotaCardPrimaryWindow?.bucketID == "codex")
        #expect(snapshot.quotaCardSecondaryWindow == nil)
        #expect(snapshot.featuredWindow?.bucketID == "codex")
    }

    @Test
    func keepsFallbackWindowsInOneBucketWhenCodexBucketIsMissing() throws {
        let snapshot = try CodexResponseParser.parse(
            accountData: Data(#"{"result":{"account":null}}"#.utf8),
            rateLimitsData: Data(#"""
            {"result":{"rateLimitsByLimitId":{
                "other_a":{"secondary":{"usedPercent":40,"windowDurationMins":10080}},
                "other_b":{"primary":{"usedPercent":5,"windowDurationMins":300}}
            }}}
            """#.utf8),
            usageData: Data(#"{"result":{}}"#.utf8)
        )

        #expect(snapshot.primaryWindow?.bucketID == "other_a")
        #expect(snapshot.fiveHourWindow == nil)
        #expect(snapshot.weeklyWindow?.bucketID == "other_a")
        #expect(snapshot.quotaCardPrimaryWindow?.remainingPercent == 60)
        #expect(snapshot.quotaCardSecondaryWindow == nil)
    }

    @Test
    func keepsWindowsWithMissingOptionalMetadata() throws {
        let account = Data(#"{"id":1,"result":{"account":null}}"#.utf8)
        let limits = Data(#"{"id":2,"result":{"rateLimits":null,"rateLimitsByLimitId":{"codex":{"limitName":null,"primary":{"usedPercent":25,"windowDurationMins":null},"secondary":{"usedPercent":40,"resetsAt":null}}}}}"#.utf8)
        let usage = Data(#"{"id":3,"result":{"summary":null}}"#.utf8)

        let snapshot = try CodexResponseParser.parse(
            accountData: account,
            rateLimitsData: limits,
            usageData: usage
        )
        let primary = try #require(snapshot.primaryWindow)
        let secondary = try #require(
            snapshot.allLimitWindows.first(where: { $0.kind == .secondary })
        )

        #expect(snapshot.rateLimitBuckets.first?.id == "codex")
        #expect(snapshot.allLimitWindows.count == 2)
        #expect(primary.remainingPercent == 75)
        #expect(primary.windowDurationMinutes == nil)
        #expect(primary.resetsAt == nil)
        #expect(secondary.remainingPercent == 60)
        #expect(secondary.windowDurationMinutes == nil)
        #expect(secondary.resetsAt == nil)
        #expect(MeterFormatters.quotaTitle(for: primary, language: .english) == "Codex quota")
    }

    @Test
    func buildsOneHundredTwentyDayHeatmap() {
        let end = DateOnlyParser.date(from: "2026-08-07")!
        let usage = [
            DailyTokenUsage(date: end, tokens: 1_000),
            DailyTokenUsage(date: end, tokens: 500),
            DailyTokenUsage(date: DateOnlyParser.date(from: "2026-08-01")!, tokens: 10_000),
        ]

        let columns = HeatmapBuilder.columns(from: usage, endingAt: end, dayCount: 120)
        let visibleDays = columns.flatMap { $0 }.compactMap { $0 }

        #expect(columns.count == 18)
        #expect(visibleDays.count == 120)
        #expect(visibleDays.last?.tokens == 1_500)
        #expect(visibleDays.contains(where: { $0.tokens == 10_000 && $0.level == .peak }))
    }

    @Test
    func ignoresUsageOutsideTheHeatmapRangeWhenNormalizing() {
        let end = DateOnlyParser.date(from: "2026-08-07")!
        let usage = [
            DailyTokenUsage(date: end, tokens: 100),
            DailyTokenUsage(date: DateOnlyParser.date(from: "2026-07-31")!, tokens: 1_000_000_000),
            DailyTokenUsage(date: DateOnlyParser.date(from: "2026-08-08")!, tokens: 2_000_000_000),
        ]

        let columns = HeatmapBuilder.columns(from: usage, endingAt: end, dayCount: 7)
        let visibleDays = columns.flatMap { $0 }.compactMap { $0 }

        #expect(visibleDays.count == 7)
        #expect(visibleDays.map(\.tokens).max() == 100)
        #expect(visibleDays.last?.tokens == 100)
        #expect(visibleDays.last?.level == .peak)
    }

    @Test
    func keepsDateOnlyValuesOnTheSameCalendarDay() {
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = DateOnlyParser.date(from: "2026-08-06", timeZone: timeZone)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 6)
        #expect(DateOnlyParser.date(from: "2026-02-30", timeZone: timeZone) == nil)
    }

    @Test
    func saturatesTokenTotalsInsteadOfOverflowing() {
        let end = DateOnlyParser.date(from: "2026-08-07")!
        let snapshot = CodexUsageSnapshot(
            fetchedAt: end,
            account: nil,
            rateLimitBuckets: [],
            usageSummary: nil,
            dailyUsage: [
                DailyTokenUsage(date: end, tokens: .max),
                DailyTokenUsage(date: end, tokens: 1),
            ]
        )

        #expect(snapshot.tokensInLastDays(1, endingAt: end) == .max)
    }

    @Test
    func replacesDelayedTodayUsageWithLocalTokens() {
        let today = DateOnlyParser.date(from: "2026-08-11")!
        let yesterday = DateOnlyParser.date(from: "2026-08-10")!
        let snapshot = CodexUsageSnapshot(
            fetchedAt: today,
            account: nil,
            rateLimitBuckets: [],
            usageSummary: nil,
            dailyUsage: [
                DailyTokenUsage(date: yesterday, tokens: 50),
                DailyTokenUsage(date: today, tokens: 10),
                DailyTokenUsage(date: today, tokens: 15),
            ]
        )

        let updated = snapshot.replacingTokenUsage(on: today, with: 120)

        #expect(updated.dailyUsage.count == 2)
        #expect(updated.tokens(on: today) == 120)
        #expect(updated.tokensInLastDays(2, endingAt: today) == 170)
    }

    @Test
    func formatsQuotaDurations() {
        let now = Date(timeIntervalSince1970: 1_786_600_000)
        let weekly = RateLimitWindow(
            id: "weekly",
            bucketID: "codex",
            bucketName: "Codex",
            kind: .primary,
            usedPercent: 50,
            windowDurationMinutes: 10_080,
            resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60)
        )
        let fiveHour = RateLimitWindow(
            id: "five-hour",
            bucketID: "codex",
            bucketName: "Codex",
            kind: .primary,
            usedPercent: 50,
            windowDurationMinutes: 300,
            resetsAt: now.addingTimeInterval(2 * 60 * 60 + 17 * 60)
        )
        #expect(MeterFormatters.quotaTitle(for: weekly) == "周额度")
        #expect(MeterFormatters.tokens(1_253_637_101) == "12亿5千万")
        #expect(MeterFormatters.tokens(22_000_000) == "2千2百万")
        #expect(MeterFormatters.tokens(5_400_000) == "540万")
        #expect(MeterFormatters.tokens(845_000) == "84.5万")
        #expect(MeterFormatters.tokens(8_200) == "8.2千")
        #expect(
            MeterFormatters.quotaTitle(for: weekly, language: .traditionalChinese)
                == "週額度"
        )
        #expect(
            MeterFormatters.quotaTitle(for: weekly, language: .english)
                == "Weekly quota"
        )
        #expect(
            MeterFormatters.tokens(1_253_637_101, language: .traditionalChinese)
                == "12億5千萬"
        )
        #expect(
            MeterFormatters.tokens(1_253_637_101, language: .english)
                == "1.3B"
        )
        #expect(MeterFormatters.usd(2.47) == "$2.47")
        #expect(MeterFormatters.usd(0.0042) == "$0.0042")
        #expect(MeterFormatters.quotaStatus(remainingPercent: 88) == "剩余额度")
        #expect(MeterFormatters.quotaStatus(remainingPercent: 16) == "额度偏低")
        #expect(MeterFormatters.quotaStatus(remainingPercent: 0) == "额度已用完")
        #expect(MeterFormatters.weeklyRemainingLabel() == "周额度剩余")
        #expect(
            MeterFormatters.quotaResetDescription(for: weekly, now: now)
                == "\(MeterFormatters.resetDate(weekly.resetsAt!, now: now)) 重置"
        )
        #expect(MeterFormatters.quotaResetDescription(for: weekly, now: now)?.contains("2026") == false)
        #expect(
            MeterFormatters.quotaResetDescription(for: fiveHour, now: now)
                == "2 小时 17 分后重置 · \(MeterFormatters.resetTime(fiveHour.resetsAt!))"
        )
    }
}
