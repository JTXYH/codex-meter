import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexMeter

struct UsageStoreTests {
    @Test @MainActor
    func menuBarPrefersFiveHourQuotaAndFallsBackToWeeklyQuota() async throws {
        let suiteName = "CodexMeterTests.MenuBarQuota.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let fiveHour = RateLimitWindow(
            id: "five-hour",
            bucketID: "codex",
            bucketName: "Codex",
            kind: .primary,
            usedPercent: 30,
            windowDurationMinutes: 300,
            resetsAt: nil
        )
        let weekly = RateLimitWindow(
            id: "weekly",
            bucketID: "codex",
            bucketName: "Codex",
            kind: .secondary,
            usedPercent: 20,
            windowDurationMinutes: 10_080,
            resetsAt: nil
        )
        let mixedSnapshot = snapshot(windows: [fiveHour, weekly])
        let weeklyOnlySnapshot = snapshot(windows: [weekly])
        let sparkBucket = RateLimitBucket(
            id: "codex_bengalfox",
            name: "GPT-5.3-Codex-Spark",
            planType: nil,
            hasCredits: nil,
            unlimitedCredits: nil,
            creditBalance: nil,
            windows: [RateLimitWindow(
                id: "codex_bengalfox-primary",
                bucketID: "codex_bengalfox",
                bucketName: "GPT-5.3-Codex-Spark",
                kind: .primary,
                usedPercent: 5,
                windowDurationMinutes: 300,
                resetsAt: nil
            )]
        )
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [
                .success(mixedSnapshot),
                .success(weeklyOnlySnapshot),
                .success(snapshot(windows: [weekly], otherBuckets: [sparkBucket])),
                .success(snapshot(windows: [], otherBuckets: [sparkBucket])),
            ]),
            localUsageLoader: FixedLocalUsageLoader(),
            settings: AppSettings(defaults: defaults)
        )

        await store.refresh()
        #expect(store.menuBarText == "70%")
        #expect(store.menuBarRemainingPercent == 70)

        await store.refresh()
        #expect(store.menuBarText == "80%")
        #expect(store.menuBarRemainingPercent == 80)

        await store.refresh()
        #expect(store.menuBarText == "80%")
        #expect(store.menuBarRemainingPercent == 80)
        #expect(store.snapshot?.fiveHourWindow == nil)
        #expect(store.snapshot?.quotaCardSecondaryWindow == nil)

        await store.refresh()
        #expect(store.menuBarText == "--")
        #expect(store.menuBarRemainingPercent == nil)
        #expect(store.snapshot?.primaryWindow == nil)
        #expect(store.snapshot?.quotaCardPrimaryWindow == nil)
        #expect(store.snapshot?.quotaCardSecondaryWindow == nil)
    }

    @Test @MainActor
    func exposesRefreshFailureWithoutDiscardingTheLastSnapshot() async throws {
        let suiteName = "CodexMeterTests.UsageStore.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let snapshot = CodexUsageSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_786_600_000),
            account: nil,
            rateLimitBuckets: [],
            usageSummary: nil,
            dailyUsage: []
        )
        let loader = SequencedUsageLoader(results: [
            .success(snapshot),
            .failure(CodexMeterError.timeout),
            .success(snapshot),
        ])
        let store = UsageStore(
            loader: loader,
            localUsageLoader: FixedLocalUsageLoader(),
            settings: AppSettings(defaults: defaults)
        )

        await store.refresh()
        #expect(!store.isRefreshing)
        #expect(store.snapshot == snapshot)
        #expect(store.refreshErrorMessage == nil)

        await store.refresh()
        #expect(!store.isRefreshing)
        #expect(store.snapshot == snapshot)
        #expect(store.refreshErrorMessage?.isEmpty == false)

        await store.refresh()
        #expect(!store.isRefreshing)
        #expect(store.refreshErrorMessage == nil)
    }

    @Test @MainActor
    func remoteFailureKeepsOnlyTodaysRealtimeUsageAndNeverSynthesizesHistory() async throws {
        let suiteName = "CodexMeterTests.RemoteFailure.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        let today = UsageCalendar.calendar.startOfDay(for: Date())
        let yesterday = try #require(UsageCalendar.calendar.date(byAdding: .day, value: -1, to: today))
        let local = tokenUsage(317_651_611)
        let localLoader = RecordingLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: local, lifetime: local,
            dailyModelUsage: [DailyModelTokenUsage(day: yesterday, model: "local-history", usage: local)],
            monthlyUsage: [MonthlyTokenUsage(month: today, usage: local)],
            dailyUsage: [PeriodTokenUsage(start: yesterday, usage: local)]
        ))
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [.failure(CodexMeterError.timeout)]),
            localUsageLoader: localLoader,
            settings: AppSettings(defaults: defaults)
        )

        await store.refresh()
        #expect(!store.hasLoadedRemoteSnapshot)
        #expect(store.localTodayUsage.totalTokens == 317_651_611)
        #expect(store.hasLoadedLocalTodayUsage)
        #expect(store.refreshErrorMessage != nil)
        #expect(store.dashboardSnapshot == store.snapshot)
        #expect(store.dashboardSnapshot?.dailyUsage.isEmpty != false)
        #expect(store.dashboardSnapshot?.usageSummary == nil)
        #expect(store.currentMonthTokens == nil)
        for period in UsagePeriod.statisticsPeriods {
            #expect(store.statisticsUsage(period, count: period.defaultRange).allSatisfy { $0.tokens == nil })
            #expect(store.modelUsage(period, containing: yesterday).isEmpty)
        }
        let requestedDates = await localLoader.requestedDates
        #expect(requestedDates.count == 1)
    }

    @Test @MainActor
    func retryAfterInitialRemoteFailureLoadsAgainWithoutHidingCompletedLocalUsage() async throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let local = tokenUsage(12_300)
        let loader = ControlledRetryUsageLoader()
        let store = UsageStore(loader: loader,
            localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(today: local, lifetime: nil)),
            settings: AppSettings(defaults: SQLitePreferences(database: try SQLiteStore())))

        await store.refresh()
        #expect(store.snapshot != nil)
        #expect(store.snapshot?.dailyUsage.isEmpty == true)
        #expect(!store.hasLoadedRemoteSnapshot)
        #expect(store.refreshErrorMessage != nil)
        #expect(store.hasLoadedLocalTodayUsage)
        #expect(store.localTodayUsage == local)

        let retry = Task { await store.refresh() }
        await loader.waitForRetry()
        #expect(store.state == .loading)
        #expect(store.isRefreshing)
        #expect(!store.hasLoadedRemoteSnapshot)
        #expect(store.hasLoadedLocalTodayUsage)
        #expect(store.localTodayUsage == local)

        let recovered = CodexUsageSnapshot(fetchedAt: Date(),
            account: CodexAccount(type: "chatgpt", email: "test@example.com", planType: "pro"),
            rateLimitBuckets: [], usageSummary: nil, dailyUsage: [])
        await loader.completeRetry(with: recovered)
        await retry.value
        #expect(store.state == .loaded)
        #expect(!store.isRefreshing)
        #expect(store.hasLoadedRemoteSnapshot)
        #expect(store.snapshot == recovered)
        #expect(store.refreshErrorMessage == nil)
        #expect(store.localTodayUsage == local)
    }

    @Test @MainActor
    func allHistoricalStatisticsUseAccountAPIWhileTodayRemainsLocal() async throws {
        let suiteName = "CodexMeterTests.AccountStatistics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        let calendar = UsageCalendar.calendar
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let remoteYesterday: Int64 = 764_709_144
        let localYesterday = tokenUsage(317_651_611)
        let localToday = tokenUsage(12_300)
        let localLoader = RecordingLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: localToday, lifetime: localYesterday.adding(localToday),
            dailyModelUsage: [
                DailyModelTokenUsage(day: today, model: "today-model", usage: localToday),
                DailyModelTokenUsage(day: yesterday, model: "local-history", usage: localYesterday),
            ],
            monthlyUsage: [MonthlyTokenUsage(month: today, usage: localYesterday.adding(localToday))],
            dailyUsage: [
                PeriodTokenUsage(start: today, usage: localToday),
                PeriodTokenUsage(start: yesterday, usage: localYesterday),
            ]
        ))
        let remote = CodexUsageSnapshot(
            fetchedAt: Date(), account: nil, rateLimitBuckets: [],
            usageSummary: TokenUsageSummary(lifetimeTokens: 9_000_000_000, peakDailyTokens: remoteYesterday,
                                            longestRunningTurnSeconds: 600, currentStreakDays: 3,
                                            longestStreakDays: 6),
            dailyUsage: [DailyTokenUsage(date: yesterday, tokens: remoteYesterday),
                         DailyTokenUsage(date: today, tokens: 50)]
        )
        let store = UsageStore(loader: SequencedUsageLoader(results: [.success(remote)]),
                               localUsageLoader: localLoader, settings: AppSettings(defaults: defaults))

        await store.refresh()
        #expect(store.dashboardSnapshot == remote)
        #expect(store.dashboardSnapshot?.usageSummary?.lifetimeTokens == 9_000_000_000)
        #expect(store.statisticsUsage(.day, count: 7).first?.tokens == remoteYesterday)
        #expect(store.dashboardSnapshot?.tokens(on: yesterday) == remoteYesterday)
        #expect(store.periodUsage(.day, count: 1).first?.tokens == 50)
        for period in [UsagePeriod.week, .month, .year] {
            let interval = try #require(period.interval(containing: today))
            let expected = remote.dailyUsage.filter { interval.contains($0.date) }.reduce(Int64(0)) { $0 + $1.tokens }
            #expect(store.statisticsUsage(period, count: 3).first?.tokens == expected)
            #expect(store.modelUsage(period, containing: today).isEmpty)
        }
        #expect(store.currentMonthTokens == store.periodUsage(.month, count: 1).first?.tokens)
        #expect(store.localTodayUsage == localToday)
        #expect(store.modelUsage(.day, containing: today) == [ModelTokenUsage(model: "today-model", usage: localToday)])
        #expect(store.modelUsage(.day, containing: yesterday).isEmpty)
        #expect(store.modelUsage(.hour, containing: today).isEmpty)
        // Reading account statistics must never trigger another local scan for history.
        let requestedDates = await localLoader.requestedDates
        #expect(requestedDates.count == 1)
        #expect(requestedDates.allSatisfy { calendar.isDate($0, inSameDayAs: today) })
    }

    private func tokenUsage(_ tokens: Int64) -> LocalTokenUsage {
        LocalTokenUsage(totalTokens: tokens, inputTokens: tokens, cachedInputTokens: 0,
                        cacheWriteInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0)
    }

    private func snapshot(
        windows: [RateLimitWindow],
        otherBuckets: [RateLimitBucket] = []
    ) -> CodexUsageSnapshot {
        CodexUsageSnapshot(
            fetchedAt: Date(timeIntervalSince1970: 1_786_600_000),
            account: nil,
            rateLimitBuckets: [
                RateLimitBucket(
                    id: "codex",
                    name: "Codex",
                    planType: nil,
                    hasCredits: false,
                    unlimitedCredits: false,
                    creditBalance: nil,
                    windows: windows
                ),
            ] + otherBuckets,
            usageSummary: nil,
            dailyUsage: []
        )
    }
}

private actor ControlledRetryUsageLoader: CodexUsageLoading {
    private var hasFailed = false
    private var retry: CheckedContinuation<CodexUsageSnapshot, Never>?
    private var retryWaiter: CheckedContinuation<Void, Never>?

    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        if !hasFailed {
            hasFailed = true
            throw CodexMeterError.timeout
        }
        return await withCheckedContinuation { continuation in
            retry = continuation
            retryWaiter?.resume()
            retryWaiter = nil
        }
    }

    func waitForRetry() async {
        guard retry == nil else { return }
        await withCheckedContinuation { retryWaiter = $0 }
    }

    func completeRetry(with snapshot: CodexUsageSnapshot) {
        retry?.resume(returning: snapshot)
        retry = nil
    }
}

private actor RecordingLocalUsageLoader: LocalTokenUsageLoading {
    let value: LocalTokenUsageSnapshot
    private(set) var requestedDates: [Date] = []

    init(value: LocalTokenUsageSnapshot) { self.value = value }

    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        requestedDates.append(now)
        return value
    }
}

struct FixedLocalUsageLoader: LocalTokenUsageLoading {
    var value = LocalTokenUsageSnapshot(today: .zero, lifetime: .zero)

    func usage(at now: Date) async -> LocalTokenUsageSnapshot { value }
}

private final class SequencedUsageLoader: CodexUsageLoading {
    private var results: [Result<CodexUsageSnapshot, Error>]

    init(results: [Result<CodexUsageSnapshot, Error>]) {
        self.results = results
    }

    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        guard !results.isEmpty else {
            throw CodexMeterError.invalidResponse("No test result remains")
        }
        return try results.removeFirst().get()
    }
}
