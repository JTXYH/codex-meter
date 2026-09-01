import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct CreditsVisibilitySettingsTests {
    @Test @MainActor
    func rendersAllVisibilityTogglesInDisplaySettings() throws {
        let suiteName = "CodexMeterTests.CreditsVisibility.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            defaults: defaults,
            preferredLanguages: ["zh-Hans-CN"],
            launchAtLoginManager: CreditsVisibilityLoginManager()
        )
        settings.appearance = .light
        settings.showCreditsBalanceCard = false
        let store = UsageStore(
            loader: CreditsVisibilityUsageLoader(),
            localUsageLoader: CreditsVisibilityLocalUsageLoader(),
            settings: settings
        )
        let backgrounds = QuotaBackgroundStore(
            defaults: defaults,
            storageDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("CodexMeterCreditsVisibility-\(UUID().uuidString)")
        )
        let content = SettingsPanelView(showDisplayInitially: true)
            .environmentObject(settings)
            .environmentObject(store)
            .environmentObject(UpdateController())
            .environmentObject(backgrounds)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: 760, height: 552)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        #expect(image.size == NSSize(width: 760, height: 552))

        if let path = ProcessInfo.processInfo.environment["CODEX_METER_VISIBILITY_SETTINGS_SNAPSHOT"] {
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}

private struct CreditsVisibilityUsageLoader: CodexUsageLoading {
    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        CodexUsageSnapshot(
            fetchedAt: Date(), account: nil, rateLimitBuckets: [],
            usageSummary: nil, dailyUsage: []
        )
    }
}

private struct CreditsVisibilityLocalUsageLoader: LocalTokenUsageLoading {
    func todayUsage(at now: Date) async -> LocalTokenUsage { .zero }
}

private struct CreditsVisibilityLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
