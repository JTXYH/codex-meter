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
        let hosting = NSHostingView(rootView: content)
        hosting.setFrameSize(NSSize(width: 760, height: 552))
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        #expect(bitmap.pixelsWide > 0)
        if let path = ProcessInfo.processInfo.environment["CODEX_METER_VISIBILITY_SETTINGS_SNAPSHOT"] {
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        window.contentView = nil

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
    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(today: .zero, lifetime: .zero)
    }
}

private struct CreditsVisibilityLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
