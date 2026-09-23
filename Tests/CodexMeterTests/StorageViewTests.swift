import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct StorageViewTests {
    @Test @MainActor
    func rendersDataManagementInEveryLanguageAndAppearance() throws {
        let database = try SQLiteStore()
        let preferences = SQLitePreferences(database: database)
        let settings = AppSettings(defaults: preferences, launchAtLoginManager: StorageViewLoginManager())
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let store = UsageStore(loader: StorageViewLoader(), localUsageLoader: StorageViewLocalLoader(), settings: settings)
        let info = StorageInfo(bytes: 2_415_616, imageBytes: 1_064_960, dailyRows: 1_194, checkpoints: 1_195,
                               oldest: Date(timeIntervalSince1970: 1_780_000_000), newest: Date())
        for language in AppLanguage.allCases {
            settings.language = language
            for appearance in [AppAppearance.light, .dark] {
                settings.appearance = appearance
                let content = VStack(alignment: .leading, spacing: 18) {
                    Text(StorageL10n.text(.title, language: language)).font(.system(size: 22, weight: .medium))
                    DataSettingsView(database: database, initialInfo: info)
                }
                .padding(24)
                .frame(width: 580)
                .background(Color.meterPanel)
                .environmentObject(settings)
                .environmentObject(store)
                .environment(\.colorScheme, appearance == .dark ? .dark : .light)
                // NSHostingView renders AppKit-backed controls that ImageRenderer omits.
                let hosting = NSHostingView(rootView: content)
                hosting.setFrameSize(NSSize(width: 580, height: hosting.fittingSize.height))
                let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = hosting
                hosting.layoutSubtreeIfNeeded()
                let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                #expect(bitmap.pixelsWide > 0)
                if let directory = ProcessInfo.processInfo.environment["CODEX_METER_STORAGE_SNAPSHOTS"] {
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: directory)
                        .appendingPathComponent("storage-\(language.rawValue)-\(appearance.rawValue).png"))
                }
                window.contentView = nil
            }
        }
    }
}
private struct StorageViewLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
private struct StorageViewLoader: CodexUsageLoading {
    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        CodexUsageSnapshot(fetchedAt: Date(), account: nil, rateLimitBuckets: [], usageSummary: nil, dailyUsage: [])
    }
}
private struct StorageViewLocalLoader: LocalTokenUsageLoading {
    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(today: .zero, lifetime: .zero)
    }
}
