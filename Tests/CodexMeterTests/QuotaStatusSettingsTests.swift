import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct QuotaStatusSettingsTests {
    @Test @MainActor
    func persistsCustomMessagesAndKeepsEmptyDefaultsLanguageAware() throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let preferences = SQLitePreferences(database: try SQLiteStore())
        func makeSettings() -> AppSettings {
            AppSettings(defaults: preferences, preferredLanguages: ["zh-Hans"],
                        launchAtLoginManager: QuotaStatusStartupStub(),
                        codexLifecycleManager: QuotaStatusStartupStub())
        }
        let settings = makeSettings()
        #expect(settings.quotaStatusMessages == QuotaStatusMessages())
        #expect(preferences.object(forKey: "quotaStatusMessages") == nil)
        settings.quotaStatusMessages.ready = "继续写"
        settings.quotaStatusMessages.low = "保留空间"
        settings.quotaStatusMessages.exhausted = "休息一下"
        let restored = makeSettings()
        #expect(restored.quotaStatusMessages == settings.quotaStatusMessages)
        restored.language = .english
        #expect(restored.quotaStatusMessages.text(for: .ready, language: restored.language) == "继续写")
        restored.quotaStatusMessages.ready = " \n\t "
        #expect(restored.quotaStatusMessages.text(for: .ready, language: .english) == "Ready to use")
        #expect(restored.quotaStatusMessages.text(for: .ready, language: .simplifiedChinese) == "可以继续使用")
        restored.quotaStatusMessages = QuotaStatusMessages()
        #expect(makeSettings().quotaStatusMessages == QuotaStatusMessages())
    }

    @Test
    func sanitizesMultilineAndLongMessagesWithoutSplittingCharacters() {
        var messages = QuotaStatusMessages()
        messages.ready = "  Ready\nfor\twork\u{0007} "
        #expect(messages.sanitized.ready == "  Ready for work ")
        #expect(messages.text(for: .ready, language: .english) == "Ready for work")
        let family = "👩‍👩‍👧‍👦"
        messages.low = String(repeating: family, count: 50)
        #expect(messages.sanitized.low == String(repeating: family, count: 40))
        for language in AppLanguage.allCases {
            for status in QuotaStatus.allCases {
                #expect(!QuotaStatusMessages().text(for: status, language: language).isEmpty)
            }
        }
    }

    @Test
    func selectsTheSameQuotaStateAtThresholds() {
        #expect(QuotaStatus(remainingPercent: 100) == .ready)
        #expect(QuotaStatus(remainingPercent: 30) == .ready)
        #expect(QuotaStatus(remainingPercent: 29.99) == .low)
        #expect(QuotaStatus(remainingPercent: 0.01) == .low)
        #expect(QuotaStatus(remainingPercent: 0) == .exhausted)
    }
}

private struct QuotaStatusStartupStub: LaunchAtLoginManaging, CodexLifecycleManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
