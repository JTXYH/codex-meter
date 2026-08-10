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

        let settings = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())

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

        let settings = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())

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

        let settings = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())
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

    @Test
    func selectsTheFirstSupportedSystemLanguageAndFallsBackToEnglish() {
        #expect(AppLanguage.systemDefault(from: ["zh-Hans-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.systemDefault(from: ["zh-Hant-TW"]) == .traditionalChinese)
        #expect(AppLanguage.systemDefault(from: ["zh-HK"]) == .traditionalChinese)
        #expect(AppLanguage.systemDefault(from: ["ja-JP"]) == .japanese)
        #expect(AppLanguage.systemDefault(from: ["ko-KR"]) == .korean)
        #expect(AppLanguage.systemDefault(from: ["es-ES"]) == .spanish)
        #expect(AppLanguage.systemDefault(from: ["fr-FR", "zh-Hans-CN"]) == .english)
        #expect(AppLanguage.systemDefault(from: []) == .english)
    }

    @Test @MainActor
    func usesSystemPreferencesAndEnablesLaunchAtLoginOnFirstRun() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let launchAtLoginManager = LaunchAtLoginManagerSpy()
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            defaults: defaults,
            preferredLanguages: ["ja-JP"],
            launchAtLoginManager: launchAtLoginManager
        )

        #expect(settings.appearance == .system)
        #expect(settings.language == .japanese)
        #expect(defaults.string(forKey: "appLanguage") == "ja")
        #expect(settings.launchAtLogin)
        #expect(defaults.bool(forKey: "launchAtLogin"))
        #expect(launchAtLoginManager.values == [true])
    }

    @Test @MainActor
    func persistsAndAppliesLaunchAtLoginChanges() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(false, forKey: "launchAtLogin")
        let launchAtLoginManager = LaunchAtLoginManagerSpy()
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            defaults: defaults,
            launchAtLoginManager: launchAtLoginManager
        )
        settings.launchAtLogin = true

        #expect(defaults.bool(forKey: "launchAtLogin"))
        #expect(launchAtLoginManager.values == [false, true])
    }
}

private final class LaunchAtLoginManagerSpy: LaunchAtLoginManaging {
    private(set) var values: [Bool] = []

    func setEnabled(_ isEnabled: Bool) throws {
        values.append(isEnabled)
    }
}
