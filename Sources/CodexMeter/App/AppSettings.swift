import AppKit
import Foundation
import ServiceManagement
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var nativeName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .spanish: "Español"
        }
    }

    var searchTerms: [String] {
        switch self {
        case .simplifiedChinese:
            [nativeName, "Chinese", "Simplified Chinese", "zh-Hans", "中文", "简体"]
        case .traditionalChinese:
            [nativeName, "Chinese", "Traditional Chinese", "zh-Hant", "中文", "繁体", "繁體"]
        case .english:
            [nativeName, "English", "en", "英语", "英語", "영어", "inglés"]
        case .japanese:
            [nativeName, "Japanese", "ja", "日语", "日語", "일본어", "japonés"]
        case .korean:
            [nativeName, "Korean", "ko", "韩语", "韓語", "한국어", "coreano"]
        case .spanish:
            [nativeName, "Spanish", "es", "西班牙语", "スペイン語", "스페인어", "español"]
        }
    }

    static func systemDefault(from preferredLanguages: [String]) -> AppLanguage {
        guard let identifier = preferredLanguages.first else { return .english }
        let components = identifier
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map { $0.lowercased() }

        guard let languageCode = components.first else { return .english }
        switch languageCode {
        case "zh":
            if components.contains("hant")
                || components.contains("tw")
                || components.contains("hk")
                || components.contains("mo") {
                return .traditionalChinese
            }
            return .simplifiedChinese
        case "en":
            return .english
        case "ja":
            return .japanese
        case "ko":
            return .korean
        case "es":
            return .spanish
        default:
            return .english
        }
    }
}

protocol LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws
}

struct SystemLaunchAtLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {
#if DEBUG
        // Debug executables are launched from changing SwiftPM build paths. Registering
        // each path makes macOS keep a separate Login Item for every debug run.
        return
#else
        let service = SMAppService.mainApp

        if isEnabled {
            guard service.status != .enabled, service.status != .requiresApproval else { return }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
#endif
    }
}

enum AutomaticRefreshInterval: String, CaseIterable, Identifiable, Sendable {
    case oneMinute
    case twoMinutes
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case custom

    var id: String { rawValue }

    var presetMinutes: Int? {
        switch self {
        case .oneMinute: 1
        case .twoMinutes: 2
        case .fiveMinutes: 5
        case .tenMinutes: 10
        case .fifteenMinutes: 15
        case .thirtyMinutes: 30
        case .custom: nil
        }
    }

    static func preset(for minutes: Int) -> AutomaticRefreshInterval? {
        allCases.first { $0.presetMinutes == minutes }
    }
}

enum DashboardSection: String, CaseIterable, Identifiable, Sendable {
    case quota
    case tokenActivity
    case activityOverview
    case monthlyUsage
    case usageHeatmap
    case usageSummary
    case creditsBalance

    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let menuBarIconSizeRange: ClosedRange<Double> = 12...22
    static let defaultMenuBarIconSize: Double = 18

    @Published var fontSettings: MeterFontSettings {
        didSet {
            let sanitized = fontSettings.sanitized
            if sanitized != fontSettings { fontSettings = sanitized }
            guard sanitized != oldValue else { return }
            if let data = try? JSONEncoder().encode(sanitized) {
                defaults.set(data, forKey: Keys.fontSettings)
            }
        }
    }

    @Published var menuBarIconSize: Double {
        didSet {
            let sanitized = Self.sanitizedMenuBarIconSize(menuBarIconSize)
            if sanitized != menuBarIconSize {
                menuBarIconSize = sanitized
            }
            defaults.set(sanitized, forKey: Keys.menuBarIconSize)
        }
    }

    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isRestoringLaunchAtLogin else { return }

            do {
                try launchAtLoginManager.setEnabled(launchAtLogin)
                defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
                launchAtLoginErrorDescription = nil
            } catch {
                launchAtLoginErrorDescription = error.localizedDescription
                isRestoringLaunchAtLogin = true
                launchAtLogin = oldValue
                isRestoringLaunchAtLogin = false
            }
        }
    }

    @Published private(set) var launchAtLoginErrorDescription: String?

    @Published var showQuotaCard: Bool {
        didSet { defaults.set(showQuotaCard, forKey: Keys.showQuotaCard) }
    }

    @Published var showTokenActivityCard: Bool {
        didSet { defaults.set(showTokenActivityCard, forKey: Keys.showTokenActivityCard) }
    }

    @Published var showActivityOverviewCard: Bool {
        didSet { defaults.set(showActivityOverviewCard, forKey: Keys.showActivityOverviewCard) }
    }

    @Published var showMonthlyUsageCard: Bool {
        didSet { defaults.set(showMonthlyUsageCard, forKey: Keys.showMonthlyUsageCard) }
    }

    @Published var monthlyUsageMonthCount: Int {
        didSet {
            let sanitized = Self.sanitizedMonthlyUsageMonthCount(monthlyUsageMonthCount)
            if sanitized != monthlyUsageMonthCount { monthlyUsageMonthCount = sanitized }
            defaults.set(sanitized, forKey: Keys.monthlyUsageMonthCount)
        }
    }

    @Published var usageStatisticsPeriod: UsagePeriod {
        didSet { defaults.set(usageStatisticsPeriod.rawValue, forKey: Keys.usageStatisticsPeriod) }
    }

    @Published var usageStatisticsDayCount: Int {
        didSet {
            let sanitized = UsagePeriod.day.sanitizedRange(usageStatisticsDayCount)
            if sanitized != usageStatisticsDayCount { usageStatisticsDayCount = sanitized }
            defaults.set(sanitized, forKey: Keys.usageStatisticsDayCount)
        }
    }

    @Published var usageStatisticsHourCount: Int {
        didSet {
            let sanitized = UsagePeriod.hour.sanitizedRange(usageStatisticsHourCount)
            if sanitized != usageStatisticsHourCount { usageStatisticsHourCount = sanitized }
            defaults.set(sanitized, forKey: Keys.usageStatisticsHourCount)
        }
    }

    @Published var usageStatisticsYearCount: Int {
        didSet {
            let sanitized = UsagePeriod.year.sanitizedRange(usageStatisticsYearCount)
            if sanitized != usageStatisticsYearCount { usageStatisticsYearCount = sanitized }
            defaults.set(sanitized, forKey: Keys.usageStatisticsYearCount)
        }
    }

    func usageStatisticsRange(for period: UsagePeriod) -> Int {
        switch period {
        case .hour: usageStatisticsHourCount
        case .day: usageStatisticsDayCount
        case .month: monthlyUsageMonthCount
        case .year: usageStatisticsYearCount
        }
    }

    func setUsageStatisticsRange(_ count: Int, for period: UsagePeriod) {
        switch period {
        case .hour: usageStatisticsHourCount = count
        case .day: usageStatisticsDayCount = count
        case .month: monthlyUsageMonthCount = count
        case .year: usageStatisticsYearCount = count
        }
    }

    @Published var showUsageHeatmapCard: Bool {
        didSet { defaults.set(showUsageHeatmapCard, forKey: Keys.showUsageHeatmapCard) }
    }

    @Published var showUsageSummaryCard: Bool {
        didSet { defaults.set(showUsageSummaryCard, forKey: Keys.showUsageSummaryCard) }
    }

    @Published var showCreditsBalanceCard: Bool {
        didSet { defaults.set(showCreditsBalanceCard, forKey: Keys.showCreditsBalanceCard) }
    }

    @Published var dashboardSectionOrder: [DashboardSection] {
        didSet {
            let sanitized = Self.sanitizedDashboardSectionOrder(dashboardSectionOrder)
            guard sanitized == dashboardSectionOrder else {
                dashboardSectionOrder = sanitized
                return
            }
            defaults.set(dashboardSectionOrder.map(\.rawValue), forKey: Keys.dashboardSectionOrder)
        }
    }

    @Published var automaticRefreshInterval: AutomaticRefreshInterval {
        didSet {
            defaults.set(automaticRefreshInterval.rawValue, forKey: Keys.automaticRefreshIntervalOption)
            persistEffectiveRefreshInterval()
        }
    }

    @Published var customRefreshIntervalMinutes: Int {
        didSet {
            let sanitized = Self.sanitizedRefreshMinutes(customRefreshIntervalMinutes)
            guard sanitized == customRefreshIntervalMinutes else {
                customRefreshIntervalMinutes = sanitized
                return
            }
            defaults.set(customRefreshIntervalMinutes, forKey: Keys.customRefreshIntervalMinutes)
            if automaticRefreshInterval == .custom {
                persistEffectiveRefreshInterval()
            }
        }
    }

    private let defaults: any PreferencesStore
    private let launchAtLoginManager: any LaunchAtLoginManaging
    private var isRestoringLaunchAtLogin = false

    init(
        defaults: any PreferencesStore = SQLitePreferences.shared,
        preferredLanguages: [String] = Locale.preferredLanguages,
        launchAtLoginManager: any LaunchAtLoginManaging = SystemLaunchAtLoginManager()
    ) {
        self.defaults = defaults
        self.launchAtLoginManager = launchAtLoginManager
        fontSettings = (defaults.object(forKey: Keys.fontSettings) as? Data)
            .flatMap { try? JSONDecoder().decode(MeterFontSettings.self, from: $0) }?
            .sanitized ?? MeterFontSettings()
        menuBarIconSize = Self.sanitizedMenuBarIconSize(
            (defaults.object(forKey: Keys.menuBarIconSize) as? NSNumber)?.doubleValue
                ?? Self.defaultMenuBarIconSize
        )
        appearance = defaults.string(forKey: Keys.appearance)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        language = defaults.string(forKey: Keys.language)
            .flatMap(AppLanguage.init(rawValue:))
            ?? AppLanguage.systemDefault(from: preferredLanguages)
        launchAtLogin = (defaults.object(forKey: Keys.launchAtLogin) as? NSNumber)?.boolValue ?? true
        showQuotaCard = (defaults.object(forKey: Keys.showQuotaCard) as? NSNumber)?.boolValue ?? true
        showTokenActivityCard = (
            defaults.object(forKey: Keys.showTokenActivityCard) as? NSNumber
        )?.boolValue ?? true
        showActivityOverviewCard = (defaults.object(forKey: Keys.showActivityOverviewCard) as? NSNumber)?.boolValue
            ?? (defaults.object(forKey: Keys.showTokenActivityCard) as? NSNumber)?.boolValue ?? true
        showMonthlyUsageCard = (defaults.object(forKey: Keys.showMonthlyUsageCard) as? NSNumber)?.boolValue ?? true
        monthlyUsageMonthCount = Self.sanitizedMonthlyUsageMonthCount(
            (defaults.object(forKey: Keys.monthlyUsageMonthCount) as? NSNumber)?.intValue ?? 6
        )
        usageStatisticsPeriod = defaults.string(forKey: Keys.usageStatisticsPeriod)
            .flatMap(UsagePeriod.init(rawValue:)) ?? .month
        usageStatisticsHourCount = UsagePeriod.hour.sanitizedRange(
            (defaults.object(forKey: Keys.usageStatisticsHourCount) as? NSNumber)?.intValue ?? 24
        )
        usageStatisticsDayCount = UsagePeriod.day.sanitizedRange(
            (defaults.object(forKey: Keys.usageStatisticsDayCount) as? NSNumber)?.intValue ?? 7
        )
        usageStatisticsYearCount = UsagePeriod.year.sanitizedRange(
            (defaults.object(forKey: Keys.usageStatisticsYearCount) as? NSNumber)?.intValue ?? 3
        )
        showUsageHeatmapCard = (
            defaults.object(forKey: Keys.showUsageHeatmapCard) as? NSNumber
        )?.boolValue ?? true
        showUsageSummaryCard = (
            defaults.object(forKey: Keys.showUsageSummaryCard) as? NSNumber
        )?.boolValue ?? true
        showCreditsBalanceCard = (
            defaults.object(forKey: Keys.showCreditsBalanceCard) as? NSNumber
        )?.boolValue ?? true
        dashboardSectionOrder = Self.sanitizedDashboardSectionOrder(
            (defaults.stringArray(forKey: Keys.dashboardSectionOrder) ?? [])
                .compactMap(DashboardSection.init(rawValue:))
        )
        let legacyMinutes = defaults.integer(forKey: Keys.automaticRefreshIntervalMinutes)
        let legacyPreset = AutomaticRefreshInterval.preset(for: legacyMinutes)
        let storedCustomMinutes = (defaults.object(forKey: Keys.customRefreshIntervalMinutes) as? NSNumber)?.intValue
        customRefreshIntervalMinutes = Self.sanitizedRefreshMinutes(
            storedCustomMinutes ?? (legacyMinutes > 0 && legacyPreset == nil ? legacyMinutes : 20)
        )
        if let storedOption = defaults.string(forKey: Keys.automaticRefreshIntervalOption)
            .flatMap(AutomaticRefreshInterval.init(rawValue:)) {
            automaticRefreshInterval = storedOption
        } else if let legacyPreset {
            automaticRefreshInterval = legacyPreset
        } else if legacyMinutes > 0 {
            automaticRefreshInterval = .custom
        } else {
            automaticRefreshInterval = .twoMinutes
        }

        defaults.set(language.rawValue, forKey: Keys.language)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(showQuotaCard, forKey: Keys.showQuotaCard)
        defaults.set(showTokenActivityCard, forKey: Keys.showTokenActivityCard)
        defaults.set(showActivityOverviewCard, forKey: Keys.showActivityOverviewCard)
        defaults.set(showMonthlyUsageCard, forKey: Keys.showMonthlyUsageCard)
        defaults.set(monthlyUsageMonthCount, forKey: Keys.monthlyUsageMonthCount)
        defaults.set(usageStatisticsPeriod.rawValue, forKey: Keys.usageStatisticsPeriod)
        defaults.set(usageStatisticsHourCount, forKey: Keys.usageStatisticsHourCount)
        defaults.set(usageStatisticsDayCount, forKey: Keys.usageStatisticsDayCount)
        defaults.set(usageStatisticsYearCount, forKey: Keys.usageStatisticsYearCount)
        defaults.set(showUsageHeatmapCard, forKey: Keys.showUsageHeatmapCard)
        defaults.set(showUsageSummaryCard, forKey: Keys.showUsageSummaryCard)
        defaults.set(showCreditsBalanceCard, forKey: Keys.showCreditsBalanceCard)
        defaults.set(dashboardSectionOrder.map(\.rawValue), forKey: Keys.dashboardSectionOrder)
        do {
            try launchAtLoginManager.setEnabled(launchAtLogin)
        } catch {
            launchAtLoginErrorDescription = error.localizedDescription
        }
        applyAppearance()
    }

    var automaticRefreshIntervalMinutes: Int {
        automaticRefreshInterval.presetMinutes ?? customRefreshIntervalMinutes
    }

    var automaticRefreshIntervalNanoseconds: UInt64 {
        UInt64(automaticRefreshIntervalMinutes) * 60 * 1_000_000_000
    }

    func isDashboardSectionVisible(_ section: DashboardSection) -> Bool {
        switch section {
        case .quota: showQuotaCard
        case .tokenActivity: showTokenActivityCard
        case .activityOverview: showActivityOverviewCard
        case .monthlyUsage: showMonthlyUsageCard
        case .usageHeatmap: showUsageHeatmapCard
        case .usageSummary: showUsageSummaryCard
        case .creditsBalance: showCreditsBalanceCard
        }
    }

    func moveDashboardSections(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let sourceIndices = offsets.sorted()
        guard !sourceIndices.isEmpty,
              sourceIndices.allSatisfy(dashboardSectionOrder.indices.contains)
        else { return }

        let movingSections = sourceIndices.map { dashboardSectionOrder[$0] }
        let remainingSections = dashboardSectionOrder.enumerated().compactMap { index, section in
            offsets.contains(index) ? nil : section
        }
        let removedBeforeDestination = sourceIndices.filter { $0 < destination }.count
        let insertionIndex = min(
            max(destination - removedBeforeDestination, 0),
            remainingSections.count
        )

        var reordered = remainingSections
        reordered.insert(contentsOf: movingSections, at: insertionIndex)
        dashboardSectionOrder = reordered
    }

    func applyAppearance() {
        switch appearance {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }

        // Every window inherits the single application-level appearance. Clearing
        // stale per-window overrides is essential when returning to system mode.
        for window in NSApplication.shared.windows {
            window.appearance = nil
        }
    }

    private func persistEffectiveRefreshInterval() {
        defaults.set(automaticRefreshIntervalMinutes, forKey: Keys.automaticRefreshIntervalMinutes)
    }

    private static func sanitizedMenuBarIconSize(_ size: Double) -> Double {
        guard size.isFinite else { return defaultMenuBarIconSize }
        return min(max(size, menuBarIconSizeRange.lowerBound), menuBarIconSizeRange.upperBound)
    }

    private static func sanitizedMonthlyUsageMonthCount(_ count: Int) -> Int {
        [3, 6, 12].contains(count) ? count : 6
    }

    private static func sanitizedRefreshMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 1), 1_440)
    }

    private static func sanitizedDashboardSectionOrder(
        _ sections: [DashboardSection]
    ) -> [DashboardSection] {
        var seen = Set<DashboardSection>()
        var result = sections.filter { seen.insert($0).inserted }
        // Insert the new card beside token activity when migrating an existing order.
        if !result.isEmpty, !seen.contains(.monthlyUsage), let index = result.firstIndex(of: .tokenActivity) {
            result.insert(.monthlyUsage, at: index + 1)
            seen.insert(.monthlyUsage)
        }
        if !result.isEmpty, !seen.contains(.activityOverview), let index = result.firstIndex(of: .tokenActivity) {
            result.insert(.activityOverview, at: index + 1)
            seen.insert(.activityOverview)
        }
        result.append(contentsOf: DashboardSection.allCases.filter { seen.insert($0).inserted })
        return result
    }

    private enum Keys {
        static let fontSettings = "meterFontSettings"
        static let menuBarIconSize = "menuBarIconSize"
        static let appearance = "appAppearance"
        static let language = "appLanguage"
        static let launchAtLogin = "launchAtLogin"
        static let showQuotaCard = "showQuotaCard"
        static let showTokenActivityCard = "showTokenActivityCard"
        static let showActivityOverviewCard = "showActivityOverviewCard"
        static let showMonthlyUsageCard = "showMonthlyUsageCard"
        static let monthlyUsageMonthCount = "monthlyUsageMonthCount"
        static let usageStatisticsPeriod = "usageStatisticsPeriod"
        static let usageStatisticsHourCount = "usageStatisticsHourCount"
        static let usageStatisticsDayCount = "usageStatisticsDayCount"
        static let usageStatisticsYearCount = "usageStatisticsYearCount"
        static let showUsageHeatmapCard = "showUsageHeatmapCard"
        static let showUsageSummaryCard = "showUsageSummaryCard"
        static let showCreditsBalanceCard = "showCreditsBalanceCard"
        static let dashboardSectionOrder = "dashboardSectionOrder"
        static let automaticRefreshIntervalOption = "automaticRefreshIntervalOption"
        static let automaticRefreshIntervalMinutes = "automaticRefreshIntervalMinutes"
        static let customRefreshIntervalMinutes = "customRefreshIntervalMinutes"
    }
}
