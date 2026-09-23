import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct AppSettingsTests {
    @Test @MainActor
    func persistsMenuBarSizeAcrossLaunches() {
        let suiteName = "CodexMeterTests.MenuBarSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())
        #expect(settings.menuBarIconSize == 18)

        settings.menuBarIconSize = 22

        let restored = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())
        #expect(restored.menuBarIconSize == 22)
    }

    @Test @MainActor
    func recoversInvalidMenuBarSizesAndPersistsClampedSizes() {
        let suiteName = "CodexMeterTests.MenuBarSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(100, forKey: "menuBarIconSize")

        let settings = AppSettings(defaults: defaults, launchAtLoginManager: LaunchAtLoginManagerSpy())
        #expect(settings.menuBarIconSize == 22)

        settings.menuBarIconSize = 0
        #expect(settings.menuBarIconSize == 12)
        #expect(defaults.double(forKey: "menuBarIconSize") == 12)
        settings.menuBarIconSize = 100
        #expect(settings.menuBarIconSize == 22)
        #expect(defaults.double(forKey: "menuBarIconSize") == 22)
        settings.menuBarIconSize = .nan
        #expect(settings.menuBarIconSize == 18)
        #expect(defaults.double(forKey: "menuBarIconSize") == 18)
    }

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

    @Test @MainActor
    func persistsDashboardSectionVisibilityAndDefaultsAllSectionsToShown() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstSettings = AppSettings(
            defaults: defaults,
            launchAtLoginManager: LaunchAtLoginManagerSpy()
        )
        #expect(firstSettings.showQuotaCard)
        #expect(firstSettings.showTokenActivityCard)
        #expect(firstSettings.showActivityOverviewCard)
        #expect(firstSettings.showMonthlyUsageCard)
        #expect(firstSettings.monthlyUsageMonthCount == 6)
        #expect(firstSettings.showUsageHeatmapCard)
        #expect(firstSettings.showUsageSummaryCard)
        #expect(firstSettings.showCreditsBalanceCard)
        #expect(firstSettings.dashboardSectionOrder == DashboardSection.allCases)

        firstSettings.showQuotaCard = false
        firstSettings.showTokenActivityCard = false
        firstSettings.showActivityOverviewCard = false
        firstSettings.showMonthlyUsageCard = false
        firstSettings.monthlyUsageMonthCount = 12
        firstSettings.showUsageHeatmapCard = false
        firstSettings.showUsageSummaryCard = false
        firstSettings.showCreditsBalanceCard = false
        #expect(!defaults.bool(forKey: "showQuotaCard"))
        #expect(!defaults.bool(forKey: "showTokenActivityCard"))
        #expect(!defaults.bool(forKey: "showUsageHeatmapCard"))
        #expect(!defaults.bool(forKey: "showUsageSummaryCard"))
        #expect(!defaults.bool(forKey: "showCreditsBalanceCard"))

        let reorderedSections: [DashboardSection] = [
            .creditsBalance, .usageSummary, .quota, .usageHeatmap, .tokenActivity, .activityOverview, .monthlyUsage,
        ]
        firstSettings.dashboardSectionOrder = reorderedSections
        #expect(
            defaults.stringArray(forKey: "dashboardSectionOrder")
                == reorderedSections.map(\.rawValue)
        )

        let restoredSettings = AppSettings(
            defaults: defaults,
            launchAtLoginManager: LaunchAtLoginManagerSpy()
        )
        #expect(!restoredSettings.showQuotaCard)
        #expect(!restoredSettings.showTokenActivityCard)
        #expect(!restoredSettings.showActivityOverviewCard)
        #expect(!restoredSettings.showMonthlyUsageCard)
        #expect(restoredSettings.monthlyUsageMonthCount == 12)
        restoredSettings.monthlyUsageMonthCount = 4
        #expect(restoredSettings.monthlyUsageMonthCount == 6)
        #expect(!restoredSettings.showUsageHeatmapCard)
        #expect(!restoredSettings.showUsageSummaryCard)
        #expect(!restoredSettings.showCreditsBalanceCard)
        #expect(restoredSettings.dashboardSectionOrder == reorderedSections)
    }

    @Test @MainActor
    func sanitizesAndMovesDashboardSections() {
        let suiteName = "CodexMeterTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let originalAppearance = NSApplication.shared.appearance
        defer {
            NSApplication.shared.appearance = originalAppearance
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(
            ["creditsBalance", "creditsBalance", "unknown", "quota"],
            forKey: "dashboardSectionOrder"
        )

        let settings = AppSettings(
            defaults: defaults,
            launchAtLoginManager: LaunchAtLoginManagerSpy()
        )
        #expect(settings.dashboardSectionOrder == [
            .creditsBalance, .quota, .tokenActivity, .activityOverview, .monthlyUsage, .usageHeatmap, .usageSummary,
        ])

        settings.moveDashboardSections(fromOffsets: IndexSet(integer: 0), toOffset: 5)
        #expect(settings.dashboardSectionOrder == [
            .quota, .tokenActivity, .activityOverview, .monthlyUsage, .creditsBalance, .usageHeatmap, .usageSummary,
        ])

        settings.moveDashboardSections(fromOffsets: IndexSet(integer: 5), toOffset: 0)
        #expect(settings.dashboardSectionOrder == [
            .usageHeatmap, .quota, .tokenActivity, .activityOverview, .monthlyUsage, .creditsBalance, .usageSummary,
        ])
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
