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
        let store = UsageStore(
            loader: SequencedUsageLoader(results: [
                .success(mixedSnapshot),
                .success(weeklyOnlySnapshot),
            ]),
            settings: AppSettings(defaults: defaults)
        )

        await store.refresh()
        #expect(store.menuBarText == "70%")

        await store.refresh()
        #expect(store.menuBarText == "80%")
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

    private func snapshot(windows: [RateLimitWindow]) -> CodexUsageSnapshot {
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
            ],
            usageSummary: nil,
            dailyUsage: []
        )
    }
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
