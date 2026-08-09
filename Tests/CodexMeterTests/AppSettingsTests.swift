import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct AppSettingsTests {
    @Test @MainActor
    func appliesAppearanceToTheWholeApplication() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)

        settings.appearance = .dark
        #expect(
            NSApplication.shared.appearance?.bestMatch(from: [.darkAqua, .aqua])
                == .darkAqua
        )

        settings.appearance = .system
        #expect(NSApplication.shared.appearance == nil)

        settings.appearance = .light
        #expect(
            NSApplication.shared.appearance?.bestMatch(from: [.darkAqua, .aqua])
                == .aqua
        )

        settings.appearance = .system
        #expect(NSApplication.shared.appearance == nil)
    }

    @Test @MainActor
    func migratesALegacyCustomRefreshInterval() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(17, forKey: "automaticRefreshIntervalMinutes")

        let settings = AppSettings(defaults: defaults)

        #expect(settings.automaticRefreshInterval == .custom)
        #expect(settings.customRefreshIntervalMinutes == 17)
        #expect(settings.automaticRefreshIntervalMinutes == 17)
    }

    @Test @MainActor
    func persistsAndClampsCustomRefreshMinutes() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        settings.automaticRefreshInterval = .custom
        settings.customRefreshIntervalMinutes = 45

        #expect(settings.automaticRefreshIntervalMinutes == 45)
        #expect(defaults.integer(forKey: "automaticRefreshIntervalMinutes") == 45)
        #expect(defaults.string(forKey: "automaticRefreshIntervalOption") == "custom")

        settings.customRefreshIntervalMinutes = 0
        #expect(settings.customRefreshIntervalMinutes == 1)

        settings.customRefreshIntervalMinutes = 2_000
        #expect(settings.customRefreshIntervalMinutes == 1_440)
    }

    @Test
    func includesAllSupportedLanguages() {
        #expect(
            AppLanguage.allCases.map(\.rawValue)
                == ["zh-Hans", "zh-Hant", "en", "ja", "ko", "es"]
        )
    }
}
