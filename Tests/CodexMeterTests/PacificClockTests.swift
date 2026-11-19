import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct PacificClockTests {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test(arguments: [
        ("2026-10-28T14:32:08Z", "Asia/Taipei", "2026-10-28", "07:32:08", "PDT", "22:32:08"),
        ("2026-10-28T02:32:08Z", "Asia/Taipei", "2026-10-27", "19:32:08", "PDT", "2026-10-28 · 10:32:08"),
        ("2026-10-28T18:32:08Z", "Asia/Taipei", "2026-10-28", "11:32:08", "PDT", "2026-10-29 · 02:32:08"),
        ("2026-12-31T23:59:59Z", "Asia/Kathmandu", "2026-12-31", "15:59:59", "PST", "2027-01-01 · 05:44:59"),
        ("2027-01-01T00:00:00Z", "America/Los_Angeles", "2026-12-31", "16:00:00", "PST", "16:00:00"),
        ("2028-02-29T08:00:01Z", "Etc/UTC", "2028-02-29", "00:00:01", "PST", "08:00:01"),
        ("2026-03-08T09:59:59Z", "America/Los_Angeles", "2026-03-08", "01:59:59", "PST", "01:59:59"),
        ("2026-03-08T10:00:00Z", "America/Los_Angeles", "2026-03-08", "03:00:00", "PDT", "03:00:00"),
        ("2026-11-01T08:59:59Z", "America/Los_Angeles", "2026-11-01", "01:59:59", "PDT", "01:59:59"),
        ("2026-11-01T09:00:00Z", "America/Los_Angeles", "2026-11-01", "01:00:00", "PST", "01:00:00"),
    ])
    func formatsOneInstantAcrossDateBoundariesAndDaylightSaving(
        instant: String, zone: String, pacificDay: String, pacificTime: String, abbreviation: String, localTime: String
    ) {
        let value = PacificClockReadout(date: date(instant), language: .simplifiedChinese,
                                   localTimeZone: TimeZone(identifier: zone)!)
        #expect(value.pacificDate.hasPrefix(pacificDay + " · "))
        #expect(value.pacificTime == pacificTime)
        #expect(value.timeZoneAbbreviation == abbreviation)
        #expect(value.localTime == localTime)
        #expect(!value.localTime.contains("UTC"))
        #expect(value.accessibilityValue.contains(pacificTime + " " + abbreviation))
    }

    @Test
    func localizesWeekdayWhileKeepingAnUnambiguous24HourClock() {
        let instant = date("2026-10-28T02:32:08Z")
        let value = PacificClockReadout(date: instant, language: .simplifiedChinese)
        #expect(value.pacificDate == "2026-10-27 · 周二")
        for language in AppLanguage.allCases {
            let localized = PacificClockReadout(date: instant, language: language)
            #expect(localized.pacificTime == "19:32:08")
            #expect(SettingsCopy.text("pacificClock", language: language) != "pacificClock")
            #expect(SettingsCopy.text("localTime", language: language) != "localTime")
        }
    }

    @Test @MainActor
    func keepsPreferencesFromTheInstalledUTCClock() throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let preferences = SQLitePreferences(database: try SQLiteStore())
        preferences.set(["quota", "tokenActivity", "utcClock"], forKey: "dashboardSectionOrder")
        preferences.set(false, forKey: "showUTCClockCard")
        let fonts = MeterFontSettings(overrides: ["utcClock": MeterFontSizes(value: 20)])
        preferences.set(try JSONEncoder().encode(fonts), forKey: "meterFontSettings")
        let settings = makeSettings(preferences)
        #expect(!settings.isDashboardSectionVisible(.pacificClock))
        let clockIndex = try #require(settings.dashboardSectionOrder.firstIndex(of: .pacificClock))
        let activityIndex = try #require(settings.dashboardSectionOrder.firstIndex(of: .tokenActivity))
        #expect(clockIndex > activityIndex)
        #expect(settings.dashboardSectionOrder.filter { $0 == .pacificClock }.count == 1)
        #expect(settings.fontSettings.sizes(for: .pacificClock).value == 20)
        #expect(SettingsCopy.text(SettingsCopy.sectionKey(.pacificClock), language: .simplifiedChinese) == "太平洋时间")
    }

    @Test @MainActor
    func migratesOldOrderOnceAndPersistsClockVisibilityOrderAndFonts() throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let preferences = SQLitePreferences(database: try SQLiteStore())
        let previous: [DashboardSection] = [.monthlyUsage, .quota, .tokenActivity, .resetCredits,
                                            .activityOverview, .usageHeatmap, .usageSummary, .creditsBalance]
        preferences.set(previous.map(\.rawValue), forKey: "dashboardSectionOrder")
        let settings = makeSettings(preferences)
        #expect(settings.dashboardSectionOrder.filter { $0 != .pacificClock } == previous)
        #expect(settings.dashboardSectionOrder[2] == .pacificClock)
        #expect(settings.showPacificClockCard)
        settings.showPacificClockCard = false
        settings.moveDashboardSections(fromOffsets: IndexSet(integer: 2), toOffset: settings.dashboardSectionOrder.count)
        settings.fontSettings.setSize(20, role: .value, section: .pacificClock)
        let restored = makeSettings(preferences)
        #expect(restored.dashboardSectionOrder == settings.dashboardSectionOrder)
        #expect(restored.dashboardSectionOrder.last == .pacificClock)
        #expect(!restored.isDashboardSectionVisible(.pacificClock))
        #expect(restored.fontSettings.sizes(for: .pacificClock).value == 20)
        #expect(restored.fontSettings.sizes(for: .tokenActivity).value == 16)
    }

    @Test @MainActor
    func nativeLayoutFitsThemesLanguagesAndLargeTextWithoutAnAccount() throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let settings = makeSettings(SQLitePreferences(database: try SQLiteStore()))
        let instant = date("2026-12-31T23:59:59Z")
        for theme in PanelTheme.allCases {
            for language in AppLanguage.allCases {
                settings.language = language
                for large in [false, true] {
                    settings.fontSettings = MeterFontSettings()
                    if large {
                        for role in MeterTextRole.allCases {
                            settings.fontSettings.setSize(role.range.upperBound, role: role, section: .pacificClock)
                        }
                    }
                    let content = PacificClockCard(fixedDate: instant)
                        .meterTypography(for: .pacificClock)
                        .environmentObject(settings)
                        .environment(\.meterTheme, theme)
                        .frame(width: 418)
                    let hosting = NSHostingView(rootView: content)
                    let size = hosting.fittingSize
                    #expect(size.width == 418)
                    #expect(size.height.isFinite && size.height >= 120 && size.height < 230)
                }
            }
        }
    }

    @MainActor private func makeSettings(_ preferences: SQLitePreferences) -> AppSettings {
        AppSettings(defaults: preferences, preferredLanguages: ["zh-Hans"],
                    launchAtLoginManager: PacificClockLoginManager(), codexLifecycleManager: PacificClockLifecycleManager())
    }
}

private struct PacificClockLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
private struct PacificClockLifecycleManager: CodexLifecycleManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
