import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct CreditsBalanceCardTests {
    @Test @MainActor
    func rendersBalanceStatesInEveryLanguageAndAppearance() async throws {
        let suiteName = "CodexMeterTests.CreditsCard.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: CreditsPreviewLoginManager())
        let store = UsageStore(localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: .zero,
            lifetime: LocalTokenUsage(
                totalTokens: 128_640_000, inputTokens: 120_000_000, cachedInputTokens: 96_000_000,
                cacheWriteInputTokens: 0, outputTokens: 8_640_000, reasoningOutputTokens: 0,
                apiEquivalentCostUSD: 307.20
            )
        )), settings: settings)
        await store.refreshLocalUsage()
        await store.refreshLifetimeUsage()
        let states: [(name: String, balance: String?, unlimited: Bool)] = [
            ("amount", "1905", false),
            ("zero", "0", false),
            ("unlimited", nil, true),
            ("unavailable", nil, false),
        ]
        let exportDirectory = ProcessInfo.processInfo.environment["CODEX_METER_CREDITS_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let exportDirectory {
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        }

        for appearance in [AppAppearance.light, .dark] {
            settings.appearance = appearance
            let colorScheme: ColorScheme = appearance == .dark ? .dark : .light
            for language in AppLanguage.allCases {
                settings.language = language
                for state in states {
                    let snapshot = CodexUsageSnapshot(
                        fetchedAt: Date(timeIntervalSince1970: 1_788_177_600),
                        account: nil,
                        rateLimitBuckets: [RateLimitBucket(
                            id: "codex", name: "Codex", planType: nil,
                            hasCredits: nil, unlimitedCredits: state.unlimited,
                            creditBalance: state.balance, windows: []
                        )],
                        usageSummary: TokenUsageSummary(
                            lifetimeTokens: 128_640_000, peakDailyTokens: nil,
                            longestRunningTurnSeconds: 7_842,
                            currentStreakDays: 18, longestStreakDays: 31
                        ),
                        dailyUsage: []
                    )
                    let card = CreditsBalanceCard(snapshot: snapshot)
                        .environmentObject(settings)
                        .environment(\.colorScheme, colorScheme)
                        .frame(width: 392)
                        .foregroundStyle(Color.meterPrimary)
                    let image = try #require(ImageRenderer(content: card).nsImage)
                    #expect(image.size.width == 392)
                    #expect(image.size.height > 60 && image.size.height < 130)

                    if let exportDirectory {
                        let renderer = ImageRenderer(content:
                            VStack(spacing: 12) {
                                UsageSummaryCard(snapshot: snapshot)
                                CreditsBalanceCard(snapshot: snapshot)
                            }
                            .padding(14)
                            .frame(width: 420)
                            .background(Color.meterPanel)
                            .foregroundStyle(Color.meterPrimary)
                            .environmentObject(settings)
                            .environmentObject(store)
                            .environment(\.colorScheme, colorScheme)
                        )
                        renderer.scale = 2
                        let rendered = try #require(renderer.nsImage)
                        let tiff = try #require(rendered.tiffRepresentation)
                        let bitmap = try #require(NSBitmapImageRep(data: tiff))
                        let png = try #require(bitmap.representation(using: .png, properties: [:]))
                        let filename = "credits-\(language.rawValue)-\(appearance.rawValue)-\(state.name).png"
                        try png.write(to: exportDirectory.appendingPathComponent(filename), options: .atomic)
                    }
                }
            }
        }
    }
}

private struct CreditsPreviewLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
