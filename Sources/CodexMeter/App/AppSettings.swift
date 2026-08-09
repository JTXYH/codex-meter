import AppKit
import Foundation
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

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

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

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = defaults.string(forKey: Keys.appearance)
            .flatMap(AppAppearance.init(rawValue:)) ?? .system
        language = defaults.string(forKey: Keys.language)
            .flatMap(AppLanguage.init(rawValue:)) ?? .simplifiedChinese
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
        applyAppearance()
    }

    var automaticRefreshIntervalMinutes: Int {
        automaticRefreshInterval.presetMinutes ?? customRefreshIntervalMinutes
    }

    var automaticRefreshIntervalNanoseconds: UInt64 {
        UInt64(automaticRefreshIntervalMinutes) * 60 * 1_000_000_000
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

    private static func sanitizedRefreshMinutes(_ minutes: Int) -> Int {
        min(max(minutes, 1), 1_440)
    }

    private enum Keys {
        static let appearance = "appAppearance"
        static let language = "appLanguage"
        static let automaticRefreshIntervalOption = "automaticRefreshIntervalOption"
        static let automaticRefreshIntervalMinutes = "automaticRefreshIntervalMinutes"
        static let customRefreshIntervalMinutes = "customRefreshIntervalMinutes"
    }
}
