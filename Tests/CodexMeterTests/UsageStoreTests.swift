import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct UsageStoreTests {
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
