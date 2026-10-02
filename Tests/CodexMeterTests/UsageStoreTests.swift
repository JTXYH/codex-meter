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
        #expect(store.snapshot == snapshot)
        #expect(store.refreshErrorMessage == nil)

        await store.refresh()
        #expect(store.snapshot == snapshot)
        #expect(store.refreshErrorMessage?.isEmpty == false)

        await store.refresh()
        #expect(store.refreshErrorMessage == nil)
    }

    @Test @MainActor
    func keepsLocalCardsAvailableWhenTheFirstQuotaRequestFails() async throws {
        let suiteName = "CodexMeterTests.RemoteFallback.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        let day = Calendar.current.startOfDay(for: Date())
        let local = LocalTokenUsage(
            totalTokens: 120, inputTokens: 100, cachedInputTokens: 0,
            cacheWriteInputTokens: 0, outputTokens: 20, reasoningOutputTokens: 0,
            apiEquivalentCostUSD: 0.01
        )
        let localLoader = FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: local, lifetime: local,
            dailyUsage: [PeriodTokenUsage(start: day, usage: local)]
        ))
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [
                .failure(CodexMeterError.server("rate limit request failed")),
                .success(snapshot(windows: [])),
            ]),
            localUsageLoader: localLoader,
            lifetimeUsageLoader: localLoader,
            settings: AppSettings(defaults: defaults)
        )
        await store.refreshLifetimeUsage()
        await store.refresh()
        #expect(!store.hasLoadedRemoteSnapshot)
        #expect(store.snapshot != nil)
        #expect(store.dashboardSnapshot?.dailyUsage.map(\.tokens) == [120])
        #expect(store.localTodayTokens == 120)
        #expect(store.refreshErrorMessage != nil)

        await store.refresh()
        #expect(store.hasLoadedRemoteSnapshot)
        #expect(store.refreshErrorMessage == nil)
        #expect(store.dashboardSnapshot == store.snapshot)
    }

    @Test @MainActor
    func publishesTodayWithoutWaitingForLifetimeUsage() async throws {
        let suiteName = "CodexMeterTests.LocalUsage.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        let lifetime = LocalTokenUsage(
            totalTokens: 1_100_000, inputTokens: 1_000_000, cachedInputTokens: 0,
            cacheWriteInputTokens: 0, outputTokens: 100_000, reasoningOutputTokens: 0,
            apiEquivalentCostUSD: 6
        )
        let historyLoader = SuspendedLocalUsageLoader(value: LocalTokenUsageSnapshot(today: .zero, lifetime: lifetime))
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [.success(snapshot(windows: []))]),
            localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
                today: lifetime, lifetime: nil
            )),
            lifetimeUsageLoader: historyLoader,
            settings: AppSettings(defaults: defaults)
        )
        #expect(store.localLifetimeUsage == nil)
        await store.refresh()
        await historyLoader.waitUntilStarted()
        #expect(store.localTodayTokens == lifetime.totalTokens)
        #expect(store.hasLoadedLocalTodayUsage)
        #expect(!store.hasLoadedLocalLifetimeUsage)
        #expect(!store.isRefreshing)
        #expect(store.localLifetimeUsage == nil)
        await historyLoader.resume()
        // Observe the published completion without imposing machine-speed timing thresholds.
        while !store.hasLoadedLocalLifetimeUsage { await Task.yield() }
        #expect(store.localLifetimeUsage == lifetime)
    }

    @Test @MainActor
    func publishesTodayTokenAndQuotaSummary() async throws {
        let suiteName = "CodexMeterTests.TodayQuota.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let reset = Date().addingTimeInterval(3 * 60 * 60)
        let weeklyReset = Date().addingTimeInterval(5 * 24 * 60 * 60)
        func windows(_ fiveHourUsed: Double, _ weeklyUsed: Double) -> [RateLimitWindow] {
            [
                RateLimitWindow(id: "five-hour", bucketID: "codex", bucketName: "Codex",
                                kind: .primary, usedPercent: fiveHourUsed,
                                windowDurationMinutes: 300, resetsAt: reset),
                RateLimitWindow(id: "weekly", bucketID: "codex", bucketName: "Codex",
                                kind: .secondary, usedPercent: weeklyUsed,
                                windowDurationMinutes: 10_080, resetsAt: weeklyReset),
            ]
        }
        let tokens = LocalTokenUsage(
            totalTokens: 121_200, inputTokens: 100_000, cachedInputTokens: 70_000,
            cacheWriteInputTokens: 0, outputTokens: 21_200, reasoningOutputTokens: 8_000,
            apiEquivalentCostUSD: 0.52
        )
        let localLoader = FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: tokens,
            lifetime: nil,
            todayQuotaUsage: [
                TodayQuotaUsage(bucketID: "codex", windowDurationMinutes: 300, usedPercentagePoints: 0.5),
                TodayQuotaUsage(bucketID: "codex", windowDurationMinutes: 10_080, usedPercentagePoints: 0.1),
            ]
        ))
        let settings = AppSettings(defaults: defaults)
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [.success(snapshot(windows: windows(10.5, 20.1)))]),
            localUsageLoader: localLoader,
            lifetimeUsageLoader: FixedLocalUsageLoader(),
            settings: settings
        )

        await store.refresh()
        #expect(store.localTodayTokens == 121_200)
        #expect(store.localTodayQuotaPercent == 0.5)
        #expect(TodayQuotaUsageL10n.title(.simplifiedChinese) == "额度消耗")
        #expect(TodayQuotaUsageL10n.summary(
            tokens: store.localTodayTokens,
            percent: store.localTodayQuotaPercent,
            language: .simplifiedChinese
        ) == "0.5%")
        let weeklyOnlyStore = UsageStore(
            loader: SequencedUsageLoader(results: [.success(snapshot(windows: [windows(10.5, 20.1)[1]]))]),
            localUsageLoader: localLoader,
            lifetimeUsageLoader: FixedLocalUsageLoader(),
            settings: settings
        )
        await weeklyOnlyStore.refresh()
        #expect(weeklyOnlyStore.localTodayQuotaPercent == 0.1)

        if let path = ProcessInfo.processInfo.environment["CODEX_METER_TODAY_QUOTA_SNAPSHOT"] {
            settings.language = .simplifiedChinese
            settings.appearance = .light
            let currentSnapshot = try #require(store.snapshot)
            let renderer = ImageRenderer(content:
                TokenActivityCard(snapshot: currentSnapshot)
                    .frame(width: 392)
                    .padding(14)
                    .background(Color.meterPanel)
                    .foregroundStyle(Color.meterPrimary)
                    .environmentObject(settings)
                    .environmentObject(store)
                    .environment(\.colorScheme, .light)
            )
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @Test @MainActor
    func quotaSummaryUsesTheSelectedStatisticsPeriod() async throws {
        let suiteName = "CodexMeterTests.PeriodQuota.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let calendar = Calendar.current
        let firstDay = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 24)))
        let secondDay = try #require(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let sunday = try #require(calendar.date(byAdding: .day, value: 3, to: firstDay))
        let monday = try #require(calendar.date(byAdding: .day, value: 4, to: firstDay))
        let reset = try #require(calendar.date(byAdding: .day, value: 6, to: firstDay))
        let readings = [
            (firstDay.addingTimeInterval(8 * 3_600), 30.0),
            (firstDay.addingTimeInterval(23 * 3_600), 32.0),
            (secondDay.addingTimeInterval(9 * 3_600), 33.0),
            (secondDay.addingTimeInterval(10 * 3_600), 40.0),
            (secondDay.addingTimeInterval(11 * 3_600), 49.0),
            (sunday.addingTimeInterval(23 * 3_600), 60.0),
            (monday, 80.0),
        ].map { time, used in
            LocalQuotaReading(date: time, bucketID: "codex", windowDurationMinutes: 10_080,
                              resetsAt: reset, usedPercent: used)
        }
        let window = RateLimitWindow(id: "weekly", bucketID: "codex", bucketName: "Codex",
                                     kind: .primary, usedPercent: 49,
                                     windowDurationMinutes: 10_080, resetsAt: reset)
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [.success(snapshot(windows: [window]))]),
            localUsageLoader: FixedLocalUsageLoader(),
            lifetimeUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
                today: .zero, lifetime: .zero, quotaReadings: readings
            )),
            settings: AppSettings(defaults: defaults)
        )
        await store.refreshLifetimeUsage()
        await store.refresh()
        #expect(store.quotaPercent(for: .day, containing: firstDay) == 2)
        #expect(store.quotaPercent(for: .day, containing: secondDay) == 17)
        #expect(store.quotaPercent(for: .hour, containing: secondDay.addingTimeInterval(10 * 3_600)) == 7)
        #expect(store.quotaPercent(for: .week, containing: sunday) == 60)
        #expect(store.quotaPercent(for: .week, containing: monday) == 20)
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

private actor SuspendedLocalUsageLoader: LocalTokenUsageLoading {
    let value: LocalTokenUsageSnapshot
    private var continuation: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    init(value: LocalTokenUsageSnapshot) { self.value = value }

    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
        return value
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
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
