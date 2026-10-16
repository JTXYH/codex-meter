import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexMeter

struct MonthlyUsageTests {
    @Test @MainActor
    func statisticsUseAPICalendarPeriodsAndOnlyTodaysModelsUseLocalData() async throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let settings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()),
                                   launchAtLoginManager: MonthlyPreviewLoginManager())
        let calendar = UsageCalendar.calendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let todayUsage = modelUsage(tokens: 330)
        let yesterdayUsage = modelUsage(tokens: 220)
        let remote = CodexUsageSnapshot(
            fetchedAt: now, account: nil, rateLimitBuckets: [], usageSummary: nil,
            dailyUsage: [DailyTokenUsage(date: today, tokens: 3_300),
                         DailyTokenUsage(date: yesterday, tokens: 764_709_144)]
        )
        let store = UsageStore(
            loader: MonthlyPreviewUsageLoader(value: remote),
            localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
                today: todayUsage, lifetime: todayUsage.adding(yesterdayUsage),
                dailyModelUsage: [
                    DailyModelTokenUsage(day: today, model: "today-model", usage: todayUsage),
                    DailyModelTokenUsage(day: yesterday, model: "yesterday-model", usage: yesterdayUsage),
                ],
                dailyUsage: [
                    PeriodTokenUsage(start: today, usage: todayUsage),
                    PeriodTokenUsage(start: yesterday, usage: yesterdayUsage),
                ]
            )), settings: settings
        )
        await store.refresh()
        await store.refreshLocalUsage(at: now)

        for count in UsagePeriod.day.ranges {
            let days = store.statisticsUsage(.day, count: count, at: now)
            #expect(days.count == count)
            #expect(days.first?.start == yesterday)
            #expect(days.first?.tokens == 764_709_144)
            #expect(days.last?.start == calendar.date(byAdding: .day, value: -count, to: today))
            #expect(days.allSatisfy { $0.start < today })
            #expect(days.dropFirst().allSatisfy { $0.tokens == nil })
        }
        for period in [UsagePeriod.month, .year] {
            #expect(store.statisticsUsage(period, count: 3, at: now).first?.tokens == 3_300)
            #expect(store.statisticsUsage(period, count: 3, at: now)[1].tokens == 764_709_144)
            #expect(store.modelUsage(period, containing: now).isEmpty)
        }
        for count in UsagePeriod.week.ranges {
            let weeks = store.statisticsUsage(.week, count: count, at: now)
            #expect(weeks.count == count)
            #expect(weeks.first?.start == calendar.date(from: DateComponents(year: 2025, month: 12, day: 29)))
            #expect(weeks.first?.tokens == 764_712_444)
            #expect(weeks.dropFirst().allSatisfy { $0.tokens == nil })
        }
        #expect(store.modelUsage(.week, containing: now).isEmpty)
        #expect(store.modelUsage(.day, containing: yesterday).isEmpty)
        #expect(store.modelUsage(.day, containing: now) == [ModelTokenUsage(model: "today-model", usage: todayUsage)])
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: today))
        #expect(store.statisticsUsage(.day, count: 7, at: tomorrow).first?.tokens == 3_300)
        #expect(store.modelUsage(.day, containing: tomorrow).isEmpty)
    }

    @Test
    func buildsCalendarMonthsAcrossYearBoundaryAndKeepsMissingMonthsUnavailable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let january = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)))
        let december = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 20)))
        let result = AccountUsageBuilder.periods(from: [
            DailyTokenUsage(date: january, tokens: 0),
            DailyTokenUsage(date: december, tokens: 100),
            DailyTokenUsage(date: december, tokens: 200),
        ], period: .month, count: 3, endingAt: january, calendar: calendar)
        #expect(result.map { calendar.component(.month, from: $0.start) } == [1, 12, 11])
        #expect(result[0].tokens == 0)
        #expect(result[1].tokens == 300)
        #expect(result[2].tokens == nil)
        #expect(L10n.monthLabel(result[0].start, now: january, language: .simplifiedChinese, calendar: calendar) == "本月")
        #expect(L10n.monthLabel(result[1].start, now: january, language: .simplifiedChinese, calendar: calendar) == "12 月")
        let september = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        #expect(L10n.monthLabel(result[0].start, now: september, language: .simplifiedChinese, calendar: calendar) == "1 月")
        #expect(AccountUsageBuilder.periods(from: [], period: .month, count: 12, endingAt: january, calendar: calendar).count == 12)
    }

    @Test @MainActor
    func rendersStatisticsCardAtEveryPeriodRangeAndLanguage() async throws {
        let suite = "CodexMeterTests.MonthlyPreview.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            defaults.removePersistentDomain(forName: suite)
            NSApplication.shared.appearance = originalAppearance
        }
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: MonthlyPreviewLoginManager())
        let calendar = UsageCalendar.calendar
        let today = calendar.startOfDay(for: Date())
        let days = (0..<180).map { offset in
            DailyTokenUsage(date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                            tokens: 764_709_144 - Int64(offset) * 2_000_000)
        }
        let quota = RateLimitWindow(
            id: "codex-primary", bucketID: "codex", bucketName: "Codex", kind: .primary,
            usedPercent: 68, windowDurationMinutes: 300, resetsAt: Date().addingTimeInterval(3 * 3_600)
        )
        let remote = CodexUsageSnapshot(
            fetchedAt: Date(), account: nil,
            rateLimitBuckets: [RateLimitBucket(
                id: "codex", name: "Codex", planType: nil, hasCredits: nil,
                unlimitedCredits: nil, creditBalance: nil, windows: [quota]
            )],
            usageSummary: TokenUsageSummary(lifetimeTokens: 48_000_000_000, peakDailyTokens: 1_020_000_000,
                                            longestRunningTurnSeconds: 28_800, currentStreakDays: 13,
                                            longestStreakDays: 39),
            dailyUsage: days
        )
        let store = UsageStore(
            loader: MonthlyPreviewUsageLoader(value: remote),
            localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
                today: usage(tokens: 317_651_611), lifetime: nil
            )), settings: settings
        )
        await store.refresh()
        #expect(store.statisticsUsage(.day, count: 7).first?.tokens == days[1].tokens)
        #expect(store.periodUsage(.day, count: 7).first?.tokens == days[0].tokens)
        let currentMonth = try #require(calendar.dateInterval(of: .month, for: today))
        let monthTokens = days.filter { currentMonth.contains($0.date) }.reduce(Int64(0)) { $0 + $1.tokens }
        #expect(store.currentMonthTokens == monthTokens)
        #expect(store.periodUsage(.month, count: 12).suffix(5).allSatisfy { $0.tokens == nil })
        let currentYear = try #require(calendar.dateInterval(of: .year, for: today))
        let yearTokens = days.filter { currentYear.contains($0.date) }.reduce(Int64(0)) { $0 + $1.tokens }
        #expect(store.periodUsage(.year, count: 3).first?.tokens == yearTokens)
        let exportDirectory = ProcessInfo.processInfo.environment["CODEX_METER_MONTHLY_SNAPSHOTS"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let exportDirectory { try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true) }
        for dark in [false, true] {
            settings.appearance = dark ? .dark : .light
            for language in AppLanguage.allCases {
                settings.language = language
                for theme in PanelTheme.allCases {
                settings.panelTheme = theme
                let overview = ImageRenderer(content:
                    ActivityOverviewCard(snapshot: remote)
                        .padding(14)
                        .frame(width: 420)
                        .background(Color.meterPanel)
                        .foregroundStyle(Color.meterPrimary)
                        .environmentObject(settings)
                        .environmentObject(store)
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .environment(\.meterTheme, theme)
                )
                overview.scale = 2
                let overviewImage = try #require(overview.nsImage)
                #expect(overviewImage.size.width == 420)
                #expect(overviewImage.size.height > 100 && overviewImage.size.height < 500)
                if let exportDirectory {
                    let tiff = try #require(overviewImage.tiffRepresentation)
                    let bitmap = try #require(NSBitmapImageRep(data: tiff))
                    let data = try #require(bitmap.representation(using: .png, properties: [:]))
                    try data.write(to: exportDirectory.appendingPathComponent(
                        "overview-\(theme.rawValue)-\(language.rawValue)-\(dark ? "dark" : "light").png"
                    ))
                }
                for period in UsagePeriod.statisticsPeriods {
                    settings.usageStatisticsPeriod = period
                    for count in period.ranges {
                        settings.setUsageStatisticsRange(count, for: period)
                        let content = MonthlyUsageCard()
                            .padding(14)
                            .frame(width: 420)
                            .background(Color.meterPanel)
                            .foregroundStyle(Color.meterPrimary)
                            .environmentObject(settings)
                            .environmentObject(store)
                            .environment(\.colorScheme, dark ? .dark : .light)
                        .environment(\.meterTheme, theme)
                        let renderer = ImageRenderer(content: content)
                        renderer.scale = 2
                        let image = try #require(renderer.nsImage)
                        #expect(image.size.width == 420)
                        #expect(image.size.height > 250 && image.size.height < 900)
                        if let exportDirectory, count == period.defaultRange {
                            // NSHostingView also renders the native horizontal date scroller.
                            let hosting = NSHostingView(rootView: content)
                            hosting.setFrameSize(NSSize(width: 420, height: hosting.fittingSize.height))
                            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                            window.contentView = hosting
                            defer { window.contentView = nil }
                            hosting.layoutSubtreeIfNeeded()
                            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                            let data = try #require(bitmap.representation(using: .png, properties: [:]))
                            try data.write(to: exportDirectory.appendingPathComponent("statistics-\(theme.rawValue)-\(period.rawValue)-\(language.rawValue)-\(dark ? "dark" : "light").png"))
                        }
                    }
                }
                }
            }
        }
    }

    @Test
    func dashboardTokenAmountsKeepMissingDistinctFromZeroAndMatchApprovedUnits() {
        #expect(PanelTokenAmount(nil, language: .simplifiedChinese).text == "—")
        #expect(PanelTokenAmount(0, language: .simplifiedChinese).text == "0")
        #expect(PanelTokenAmount(764_709_144, language: .simplifiedChinese).text == "7.65亿")
        #expect(PanelTokenAmount(31_760_000, language: .simplifiedChinese).text == "3176万")
        #expect(PanelTokenAmount(4_280_000_000, language: .simplifiedChinese).text == "42.8亿")
        #expect(PanelTokenAmount(764_709_144, language: .english).text == "764.7M")
    }

    private func usage(tokens: Int64) -> LocalTokenUsage {
        LocalTokenUsage(totalTokens: tokens, inputTokens: tokens, cachedInputTokens: 0,
                        cacheWriteInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0)
    }

    private func modelUsage(tokens: Int64) -> LocalTokenUsage {
        let output = tokens / 10
        return LocalTokenUsage(totalTokens: tokens, inputTokens: tokens - output, cachedInputTokens: 0,
                               cacheWriteInputTokens: 0, outputTokens: output, reasoningOutputTokens: 0)
    }
}

private struct MonthlyPreviewLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}

private struct MonthlyPreviewUsageLoader: CodexUsageLoading {
    let value: CodexUsageSnapshot
    func fetchSnapshot() async throws -> CodexUsageSnapshot { value }
}
