import AppKit
import Foundation
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
