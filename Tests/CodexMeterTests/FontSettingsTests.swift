import AppKit
import SwiftUI
import Testing
@testable import CodexMeter

struct FontSettingsTests {
    @Test @MainActor
    func persistsScopesInSQLiteAndKeepsQuotaIndependent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.sqlite")
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let settings = makeSettings(try SQLiteStore(url: url))
        #expect(settings.fontSettings.sizes(for: nil) == MeterFontSizes())
        settings.fontSettings.setSize(22, role: .value, section: .quota)
        settings.fontSettings.setSize(14, role: .value, section: nil)
        settings.fontSettings.setSize(19, role: .value, section: .activityOverview)
        settings.fontSettings.setSize(9.5, role: .detail, section: nil)

        let restored = makeSettings(try SQLiteStore(url: url))
        #expect(restored.fontSettings.sizes(for: .quota).value == 22)
        #expect(restored.fontSettings.sizes(for: .activityOverview).value == 19)
        #expect(restored.fontSettings.sizes(for: .activityOverview).detail == 9.5)
        #expect(restored.fontSettings.sizes(for: .monthlyUsage).value == 14)
        #expect(restored.fontSettings.quota.detail == 10)

        restored.fontSettings.applyToContentCards(from: .activityOverview)
        #expect(MeterFontSettings.contentSections.allSatisfy {
            restored.fontSettings.sizes(for: $0).value == 19
        })
        #expect(restored.fontSettings.quota.value == 22)
        restored.fontSettings.reset(section: .quota)
        #expect(restored.fontSettings.quota == MeterFontSizes())
        #expect(restored.fontSettings.content.value == 19)
        restored.fontSettings.setSize(23, role: .value, section: .quota)
        restored.fontSettings.reset(section: nil)
        #expect(restored.fontSettings.content == MeterFontSizes())
        #expect(restored.fontSettings.overrides.isEmpty)
        #expect(restored.fontSettings.quota.value == 23)
    }

    @Test @MainActor
    func handlesCorruptStorageAndInvalidSizes() throws {
        let database = try SQLiteStore()
        let preferences = SQLitePreferences(database: database)
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        preferences.set(Data("invalid json".utf8), forKey: "meterFontSettings")
        let settings = makeSettings(database)
        #expect(settings.fontSettings == MeterFontSettings())
        settings.fontSettings.setSize(1_000, role: .value, section: .quota)
        settings.fontSettings.setSize(-20, role: .title, section: nil)
        settings.fontSettings.setSize(.nan, role: .detail, section: .activityOverview)
        settings.fontSettings.setSize(11.7, role: .detail, section: .monthlyUsage)
        let restored = makeSettings(database)
        #expect(restored.fontSettings.quota.value == 24)
        #expect(restored.fontSettings.content.title == 9)
        #expect(restored.fontSettings.sizes(for: .activityOverview).detail == 10)
        #expect(restored.fontSettings.sizes(for: .monthlyUsage).detail == 11.5)
    }

    @Test @MainActor
    func fontRolesRenderFromTheSelectedScope() throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let settings = makeSettings(try SQLiteStore())
        func renderedHeight(_ section: DashboardSection) throws -> CGFloat {
            let sample = VStack(alignment: .leading, spacing: 8) {
                Text("Usage").meterText(.title)
                Text("123,456").meterText(.value)
                Text("Updated now").meterText(.detail)
            }
            .meterTypography(for: section)
            .environmentObject(settings)
            return try #require(ImageRenderer(content: sample).nsImage).size.height
        }
        let contentBefore = try renderedHeight(.activityOverview)
        let quotaBefore = try renderedHeight(.quota)
        settings.fontSettings.setSize(24, role: .value, section: .activityOverview)
        #expect(try renderedHeight(.activityOverview) > contentBefore)
        #expect(try renderedHeight(.quota) == quotaBefore)
        settings.fontSettings.setSize(18, role: .title, section: .quota)
        #expect(try renderedHeight(.quota) > quotaBefore)
    }

    @Test @MainActor
    func eachFontPreviewMatchesTheActualCardAndAllIncludesHiddenCards() async throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let database = try SQLiteStore()
        let settings = makeSettings(database)
        settings.language = .simplifiedChinese
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backgrounds = QuotaBackgroundStore(defaults: SQLitePreferences(database: database), storageDirectory: directory)
        let usage = LocalTokenUsage(totalTokens: 3_280_000, inputTokens: 3_096_000,
                                    cachedInputTokens: 2_600_000, cacheWriteInputTokens: 0,
                                    outputTokens: 184_000, reasoningOutputTokens: 96_000,
                                    apiEquivalentCostUSD: 8.25)
        let month = Calendar.current.dateInterval(of: .month, for: Date())!.start
        let store = UsageStore(localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: usage, lifetime: usage,
            monthlyUsage: [MonthlyTokenUsage(month: month, usage: usage)]
        )), settings: settings)
        await store.refreshLocalUsage()
        await store.refreshLifetimeUsage()
        let snapshot = CodexUsageSnapshot(
            fetchedAt: Date(), account: nil,
            rateLimitBuckets: [RateLimitBucket(id: "codex", name: "Codex", planType: nil,
                hasCredits: nil, unlimitedCredits: false, creditBalance: "1905", windows: [])],
            usageSummary: TokenUsageSummary(lifetimeTokens: 128_640_000, peakDailyTokens: nil,
                longestRunningTurnSeconds: 7_842, currentStreakDays: 18, longestStreakDays: 31),
            dailyUsage: []
        )
        settings.fontSettings.setSize(20, role: .value, section: .activityOverview)
        settings.fontSettings.setSize(14, role: .title, section: .monthlyUsage)

        func render<V: View>(_ view: V) throws -> (size: CGSize, pixels: Data) {
            let content = view.frame(width: 392)
                .environmentObject(settings).environmentObject(store).environmentObject(backgrounds)
            let image = try #require(ImageRenderer(content: content).nsImage)
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let bytes = try #require(bitmap.bitmapData)
            return (image.size, Data(bytes: bytes, count: bitmap.bytesPerRow * bitmap.pixelsHigh))
        }

        var heights: [DashboardSection: CGFloat] = [:]
        for section in DashboardSection.allCases {
            let actual = try render(FontCardPreview(section: section, snapshot: snapshot))
            let expected = try render(DashboardCard(section: section, snapshot: snapshot))
            #expect(actual.size == expected.size, "Preview size for \(section.rawValue)")
            #expect(actual.pixels.count == expected.pixels.count)
            let difference = zip(actual.pixels, expected.pixels).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
            // Separate SwiftUI renders can differ by a few rasterization channel levels.
            let meanChannelDifference = Double(difference) / Double(max(1, expected.pixels.count))
            #expect(meanChannelDifference < 0.01, "Preview pixels for \(section.rawValue)")
            heights[section] = actual.size.height
            if let output = ProcessInfo.processInfo.environment["CODEX_METER_FONT_SNAPSHOTS"] {
                let root = FontCardPreview(section: section, snapshot: snapshot)
                    .padding(14).frame(width: 420).background(Color.meterPanel)
                    .foregroundStyle(Color.meterPrimary)
                    .environmentObject(settings).environmentObject(store).environmentObject(backgrounds)
                let hosting = NSHostingView(rootView: root)
                hosting.setFrameSize(NSSize(width: 420, height: hosting.fittingSize.height))
                let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = hosting
                hosting.layoutSubtreeIfNeeded()
                let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                let url = URL(fileURLWithPath: output, isDirectory: true)
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                try png.write(to: url.appendingPathComponent("preview-\(section.rawValue).png"))
                window.contentView = nil
            }
        }
        settings.showUsageHeatmapCard = false
        settings.showCreditsBalanceCard = false
        settings.dashboardSectionOrder.reverse()
        let all = try render(FontCardPreview(section: nil, snapshot: snapshot))
        let content = MeterFontSettings.contentSections
        let expectedHeight = content.reduce(CGFloat(0)) { $0 + (heights[$1] ?? 0) }
            + CGFloat(content.count - 1) * 12
        #expect(abs(all.size.height - expectedHeight) < 1)
    }

    @Test @MainActor
    func rendersFontControlsAndLargeQuotaInSupportedLanguages() async throws {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        let database = try SQLiteStore()
        let preferences = SQLitePreferences(database: database)
        let settings = makeSettings(database)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backgrounds = QuotaBackgroundStore(defaults: preferences, storageDirectory: directory)
        let previewStore = UsageStore(localUsageLoader: FixedLocalUsageLoader(
            value: LocalTokenUsageSnapshot(today: .zero, lifetime: .zero)
        ), settings: settings)
        await previewStore.refreshLocalUsage()
        await previewStore.refreshLifetimeUsage()
        for role in MeterTextRole.allCases {
            settings.fontSettings.setSize(role.range.upperBound, role: role, section: .quota)
        }
        let output = ProcessInfo.processInfo.environment["CODEX_METER_FONT_SNAPSHOTS"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for language in AppLanguage.allCases {
            settings.language = language
            if language == .simplifiedChinese || language == .traditionalChinese {
                #expect(SettingsSection.allCases.allSatisfy { $0.sidebarTitle(language: language).count == 2 })
            }
            for quota in [false, true] {
                let view = FontSettingsView(showQuotaInitially: quota, contentSectionInitially: .activityOverview)
                    .padding(24)
                    .frame(width: 580)
                    .background(Color.meterPanel)
                    .foregroundStyle(Color.meterPrimary)
                    .environmentObject(settings)
                    .environmentObject(previewStore)
                    .environmentObject(backgrounds)
                let hosting = NSHostingView(rootView: view)
                hosting.setFrameSize(NSSize(width: 580, height: hosting.fittingSize.height))
                let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                window.contentView = hosting
                hosting.layoutSubtreeIfNeeded()
                let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                #expect(hosting.frame.width == 580)
                #expect(hosting.frame.height > 300 && hosting.frame.height < 750)
                if let output {
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: output.appendingPathComponent("fonts-\(language.rawValue)-\(quota ? "quota" : "content").png"))
                }
                window.contentView = nil
            }
        }
        #expect(SettingsSection.allCases.last == .updates)

        if let output {
            settings.language = .simplifiedChinese
            let store = UsageStore(settings: settings)
            let root = SettingsPanelView(showFontsInitially: true)
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(backgrounds)
                .environmentObject(UpdateController.shared)
            let hosting = NSHostingView(rootView: root)
            hosting.setFrameSize(NSSize(width: 760, height: 552))
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("settings-fonts-sidebar.png"))
            window.contentView = nil

            for role in MeterTextRole.allCases {
                settings.fontSettings.setSize(role.range.upperBound, role: role, section: nil)
            }
            let sampleUsage = LocalTokenUsage(
                totalTokens: 3_280_000, inputTokens: 3_096_000, cachedInputTokens: 2_600_000,
                cacheWriteInputTokens: 0, outputTokens: 184_000, reasoningOutputTokens: 96_000,
                apiEquivalentCostUSD: 8.25
            )
            let month = Calendar.current.dateInterval(of: .month, for: Date())!.start
            let demoStore = UsageStore(localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
                today: sampleUsage, lifetime: sampleUsage,
                monthlyUsage: [MonthlyTokenUsage(month: month, usage: sampleUsage)]
            )), settings: settings)
            await demoStore.refreshLocalUsage()
            await demoStore.refreshLifetimeUsage()
            let snapshot = CodexUsageSnapshot(
                fetchedAt: Date(), account: nil,
                rateLimitBuckets: [RateLimitBucket(
                    id: "codex", name: "Codex", planType: nil, hasCredits: nil,
                    unlimitedCredits: false, creditBalance: "1905",
                    windows: [BackgroundQuotaUsageCard.previewWindow(), BackgroundQuotaUsageCard.previewWeeklyWindow()]
                )],
                usageSummary: TokenUsageSummary(lifetimeTokens: 128_640_000, peakDailyTokens: nil,
                                               longestRunningTurnSeconds: 7_842, currentStreakDays: 18, longestStreakDays: 31),
                dailyUsage: []
            )
            let stack = DashboardCardStack(snapshot: snapshot)
                .padding(14)
                .frame(width: 420)
                .background(Color.meterPanel)
                .foregroundStyle(Color.meterPrimary)
                .environmentObject(settings)
                .environmentObject(demoStore)
                .environmentObject(backgrounds)
            let panel = NSHostingView(rootView: stack)
            panel.setFrameSize(NSSize(width: 420, height: panel.fittingSize.height))
            let panelWindow = NSWindow(contentRect: panel.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            panelWindow.contentView = panel
            panel.layoutSubtreeIfNeeded()
            let panelBitmap = try #require(panel.bitmapImageRepForCachingDisplay(in: panel.bounds))
            panel.cacheDisplay(in: panel.bounds, to: panelBitmap)
            let panelPNG = try #require(panelBitmap.representation(using: .png, properties: [:]))
            try panelPNG.write(to: output.appendingPathComponent("panel-large-fonts.png"))
            panelWindow.contentView = nil
        }
    }

    @MainActor private func makeSettings(_ database: SQLiteStore) -> AppSettings {
        AppSettings(defaults: SQLitePreferences(database: database), launchAtLoginManager: FontTestLoginManager())
    }
}

private struct FontTestLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
