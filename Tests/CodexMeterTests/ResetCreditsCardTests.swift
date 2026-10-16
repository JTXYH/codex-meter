import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct ResetCreditsCardTests {
    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    private func card(_ id: String, expiresAt: Date?, resetType: String = "codexRateLimits",
                      title: String? = nil, description: String? = nil) -> RateLimitResetCredit {
        RateLimitResetCredit(id: id, resetType: resetType, status: "available",
                             grantedAt: date("2026-10-01T00:00:00Z"), expiresAt: expiresAt,
                             title: title, description: description)
    }

    @Test
    func countStaysAuthoritativeWhenTheDetailListIsMissingOrIncomplete() {
        let absent = ResetCreditsPresentation(credits: nil, language: .simplifiedChinese)
        #expect(absent.count == nil)
        #expect(absent.groups.isEmpty)
        let countOnly = ResetCreditsPresentation(credits: .init(availableCount: 5, credits: nil), language: .simplifiedChinese)
        #expect(countOnly.count == 5)
        #expect(countOnly.groups.isEmpty)
        let partial = ResetCreditsPresentation(credits: .init(availableCount: 5, credits: [
            card("second", expiresAt: date("2026-11-06T23:22:24Z")),
            card("first", expiresAt: date("2026-10-29T18:50:24Z")),
        ]), language: .simplifiedChinese)
        #expect(partial.count == 5)
        #expect(partial.missingCount == 3)
        #expect(partial.groups.count == 1)
        #expect(partial.groups[0].rows.map(\.id) == ["first", "second"])
        let empty = ResetCreditsPresentation(credits: .init(availableCount: 0, credits: []), language: .simplifiedChinese)
        #expect(empty.count == 0)
        #expect(empty.groups.isEmpty)
    }

    @Test
    func localExpiryCrossesDaysAndYearsWithoutUsingTheUsageCalendar() {
        let credits = RateLimitResetCredits(availableCount: 2, credits: [
            card("day", expiresAt: date("2026-10-29T18:50:24Z")),
            card("year", expiresAt: date("2026-12-31T16:05:00Z")),
        ])
        let value = ResetCreditsPresentation(credits: credits, language: .simplifiedChinese,
                                            now: date("2026-10-16T00:00:00Z"), timeZone: TimeZone(identifier: "Asia/Taipei")!)
        let rows = value.groups.flatMap(\.rows)
        #expect(rows[0].date == "10 月 30 日")
        #expect(rows[0].time == "02:50")
        #expect(rows[1].date == "2027 年 1 月 1 日")
        #expect(rows[1].time == "00:05")
        #expect(rows[0].accessibilityDate.contains("GMT+8"))
        #expect(rows[0].accessibilityDate.contains("2026"))

        let daylightSaving = ResetCreditsPresentation(credits: credits, language: .english,
                                                     now: date("2026-10-16T00:00:00Z"), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
        #expect(daylightSaving.groups[0].rows[0].accessibilityDate.contains("GMT−7"))
        #expect(daylightSaving.groups[0].rows[1].accessibilityDate.contains("GMT−8"))
        #expect(daylightSaving.groups[0].rows[0].time == "11:50")
    }

    @Test
    func unknownCardTypesUseServerCopyAndNullExpiryNeverInventsADate() {
        let credits = RateLimitResetCredits(availableCount: 2, credits: [
            card("full", expiresAt: date("2026-10-29T18:50:24Z")),
            card("future", expiresAt: nil, resetType: "futureType", title: "Special reset", description: "A different limit"),
        ])
        let value = ResetCreditsPresentation(credits: credits, language: .english)
        #expect(value.groups.count == 2)
        #expect(value.groups[0].title == "Full reset")
        #expect(value.groups[1].title == "Special reset")
        #expect(value.groups[1].detail == "A different limit")
        #expect(value.groups[1].rows[0].date == "Never expires")
        #expect(value.groups[1].rows[0].time == nil)
        #expect(value.groups[1].rows[0].index == "02")
    }

    @Test @MainActor
    func nativeCardRendersBothThemesAndAccountStates() throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let settings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()),
                                   preferredLanguages: ["zh-Hans"],
                                   launchAtLoginManager: ResetCardTestLoginManager(),
                                   codexLifecycleManager: ResetCardTestLifecycleManager())
        let fixture = try CodexResponseParser.parse(
            accountData: Data(#"{"result":{"account":null}}"#.utf8),
            rateLimitsData: Data(#"{"result":{"rateLimitResetCredits":{"availableCount":2,"credits":[{"id":"card-one","resetType":"codexRateLimits","status":"available","grantedAt":1790707824,"expiresAt":1793299824,"title":"Full reset","description":null},{"id":"card-two","resetType":"codexRateLimits","status":"available","grantedAt":1791415344,"expiresAt":1794007344,"title":"Full reset","description":null}]}}}"#.utf8),
            usageData: Data(#"{"result":{}}"#.utf8))
        let cards = try #require(fixture.resetCredits?.credits)
        #expect(cards.count == 2)
        let exportDirectory = ProcessInfo.processInfo.environment["CODEX_METER_RESET_CARDS_SNAPSHOT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let exportDirectory {
            try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        }

        @MainActor func render(_ name: String, credits: RateLimitResetCredits?, theme: PanelTheme = .quiet,
                               appearance: AppAppearance = .light, language: AppLanguage = .simplifiedChinese,
                               maximumFonts: Bool = false) throws -> CGFloat {
            settings.panelTheme = theme
            settings.appearance = appearance
            settings.language = language
            settings.fontSettings = MeterFontSettings()
            if maximumFonts {
                for role in MeterTextRole.allCases {
                    settings.fontSettings.setSize(role.range.upperBound, role: role, section: .resetCredits)
                }
            }
            let snapshot = CodexUsageSnapshot(fetchedAt: fixture.fetchedAt, account: nil, rateLimitBuckets: [],
                                              usageSummary: nil, dailyUsage: [], resetCredits: credits)
            let view = ResetCreditsCard(snapshot: snapshot)
                .meterTypography(for: .resetCredits)
                .environmentObject(settings)
                .environment(\.meterTheme, theme)
                .environment(\.meterCardHasBottomBorder, false)
                .environment(\.colorScheme, appearance == .dark ? .dark : .light)
                .foregroundStyle(Color.meterPrimary)
            let renderer = ImageRenderer(content: view)
            renderer.proposedSize = ProposedViewSize(width: 420, height: nil)
            renderer.scale = 2
            let image = try #require(renderer.nsImage)
            #expect(image.size.width == 420)
            #expect(image.size.height.isFinite && image.size.height > 100)
            if let exportDirectory {
                let tiff = try #require(image.tiffRepresentation)
                let bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: exportDirectory.appendingPathComponent("reset-cards-\(theme.rawValue)-\(appearance.rawValue)-\(name).png"), options: .atomic)
            }
            return image.size.height
        }

        var baseline: CGFloat = 0
        for theme in PanelTheme.allCases {
            for appearance in [AppAppearance.light, .dark] {
                let height = try render("available", credits: fixture.resetCredits, theme: theme, appearance: appearance)
                #expect(height > 180 && height < 220)
                baseline = height
            }
        }
        _ = try render("partial", credits: .init(availableCount: 5, credits: cards))
        _ = try render("count-only", credits: .init(availableCount: 5, credits: nil))
        _ = try render("empty", credits: .init(availableCount: 0, credits: []))
        _ = try render("unavailable", credits: nil)
        let five = cards + (3...5).map { index in
            card("card-\(index)", expiresAt: Date(timeIntervalSince1970: 1_794_007_344 + Double(index * 86_400)))
        }
        let expanded = try render("five", credits: .init(availableCount: 5, credits: five))
        #expect(expanded >= baseline + 3 * 48)
        for theme in PanelTheme.allCases {
            let large = try render("spanish-max-fonts", credits: fixture.resetCredits, theme: theme,
                                   language: .spanish, maximumFonts: true)
            #expect(large > baseline)
        }
    }
}

private struct ResetCardTestLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}

private struct ResetCardTestLifecycleManager: CodexLifecycleManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
