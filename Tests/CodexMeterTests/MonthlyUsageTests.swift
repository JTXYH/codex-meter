import AppKit
import Foundation
import SwiftUI
import Testing
@testable import CodexMeter

struct MonthlyUsageTests {
    @Test
    func buildsCalendarMonthsAcrossYearBoundaryAndKeepsMissingMonthsUnavailable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let january = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)))
        let december = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 20)))
        let result = MonthlyUsageBuilder.months(from: [
            MonthlyTokenUsage(month: january, usage: .zero),
            MonthlyTokenUsage(month: december, usage: usage(tokens: 100, cost: 2)),
            MonthlyTokenUsage(month: december, usage: usage(tokens: 200, cost: 3)),
        ], count: 3, endingAt: january, calendar: calendar)
        #expect(result.map { calendar.component(.month, from: $0.month) } == [1, 12, 11])
        #expect(result[0].usage == .zero)
        #expect(result[1].usage?.totalTokens == 300)
        #expect(result[1].usage?.apiEquivalentCostUSD == 5)
        #expect(result[2].usage == nil)
        #expect(L10n.monthLabel(result[0].month, now: january, language: .simplifiedChinese, calendar: calendar) == "本月")
        #expect(L10n.monthLabel(result[1].month, now: january, language: .simplifiedChinese, calendar: calendar) == "12 月")
        #expect(L10n.monthDateRange(result[1].month, now: january, language: .simplifiedChinese, calendar: calendar)
            == "2025年12月1日 – 2025年12月31日")
        #expect(L10n.monthDateRange(result[0].month, now: january, language: .simplifiedChinese, calendar: calendar)
            == "2026年1月1日 – 2026年1月31日")
        let september = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        #expect(L10n.monthLabel(result[0].month, now: september, language: .simplifiedChinese, calendar: calendar) == "1 月")
        #expect(MonthlyUsageBuilder.months(from: [], count: 12, endingAt: january, calendar: calendar).count == 12)
    }

    @Test @MainActor
    func rendersStatisticsCardAtEveryPeriodRangeAndLanguage() async throws {
        let suite = "CodexMeterTests.MonthlyPreview.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let originalAppearance = NSApplication.shared.appearance
        defer {
            defaults.removePersistentDomain(forName: suite)
            NSApplication.shared.appearance = originalAppearance
        }
        let settings = AppSettings(defaults: defaults, launchAtLoginManager: MonthlyPreviewLoginManager())
        let calendar = Calendar.current
        let currentMonth = try #require(calendar.dateInterval(of: .month, for: Date())?.start)
        let tokens: [Int64] = [1_020_000_000, 380_000_000, 200_000_000, 100_000_000, 60_000_000, 20_000_000]
        let costs = [1428.36, 1068.20, 876.50, 640.25, 492.65, 379.00]
        let months = (0..<6).map { offset in
            MonthlyTokenUsage(month: calendar.date(byAdding: .month, value: -offset, to: currentMonth)!,
                              usage: usage(tokens: tokens[offset], cost: costs[offset]))
        }
        let days = (0..<30).map { offset in
            PeriodTokenUsage(start: calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date()))!,
                             usage: usage(tokens: 4_800_000 - Int64(offset) * 120_000, cost: 12.36 - Double(offset) * 0.3))
        }
        let currentHour = try #require(calendar.dateInterval(of: .hour, for: Date())?.start)
        let hours = (0..<24).map { offset in
            let factor = (offset * 7) % 10
            return PeriodTokenUsage(start: calendar.date(byAdding: .hour, value: -offset, to: currentHour)!,
                                    usage: usage(tokens: 328_000 + Int64(factor) * 42_000, cost: 0.825 + Double(factor) * 0.12))
        }
        let store = UsageStore(localUsageLoader: FixedLocalUsageLoader(value: LocalTokenUsageSnapshot(
            today: usage(tokens: 424_000_000, cost: 901.08),
            lifetime: usage(tokens: 1_780_000_000, cost: 4884.96),
            monthlyUsage: months, dailyUsage: days, hourlyUsage: hours
        )), settings: settings)
        await store.refreshLocalUsage()
        await store.refreshLifetimeUsage()
        #expect(store.localCurrentMonthUsage == months[0].usage)
        #expect(store.monthlyUsage(count: 12).suffix(6).allSatisfy { $0.usage == nil })
        #expect(store.periodUsage(.day, count: 7).first?.usage?.totalTokens == 4_800_000)
        #expect(store.periodUsage(.hour, count: 24).first?.usage?.totalTokens == 328_000)
        #expect(store.periodUsage(.hour, count: 24).first?.usage?.apiEquivalentCostUSD == 0.825)
        await store.refreshLifetimeUsage(at: currentHour.addingTimeInterval(3_600))
        #expect(store.localStatisticsHour == currentHour.addingTimeInterval(3_600))
        #expect(store.periodUsage(.hour, count: 6, at: currentHour.addingTimeInterval(3_600)).first?.usage == nil)
        await store.refreshLifetimeUsage()
        let currentYearTokens = months.filter { calendar.isDate($0.month, equalTo: currentMonth, toGranularity: .year) }
            .reduce(Int64(0)) { $0 + ($1.usage?.totalTokens ?? 0) }
        #expect(store.periodUsage(.year, count: 3).first?.usage?.totalTokens == currentYearTokens)
        let exportDirectory = ProcessInfo.processInfo.environment["CODEX_METER_MONTHLY_SNAPSHOTS"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let exportDirectory { try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true) }
        for dark in [false, true] {
            settings.appearance = dark ? .dark : .light
            for language in AppLanguage.allCases {
                settings.language = language
                for period in UsagePeriod.allCases {
                    settings.usageStatisticsPeriod = period
                    for count in period.ranges {
                        settings.setUsageStatisticsRange(count, for: period)
                        let content = MonthlyUsageCard()
                            .padding(14)
                            .frame(width: 420)
                            .background(Color.meterPanel)
                            .foregroundStyle(Color.meterPrimary)
                            .environmentObject(settings)
                            .environmentObject(store)
                            .environment(\.colorScheme, dark ? .dark : .light)
                        let renderer = ImageRenderer(content: content)
                        renderer.scale = 2
                        let image = try #require(renderer.nsImage)
                        #expect(image.size.width == 420)
                        #expect(image.size.height > 300 && image.size.height < 470)
                        if let exportDirectory, language == .simplifiedChinese, count == period.defaultRange {
                            // NSHostingView also renders the native horizontal date scroller.
                            let hosting = NSHostingView(rootView: content)
                            hosting.setFrameSize(NSSize(width: 420, height: hosting.fittingSize.height))
                            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                            window.contentView = hosting
                            defer { window.contentView = nil }
                            hosting.layoutSubtreeIfNeeded()
                            let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                            let data = try #require(bitmap.representation(using: .png, properties: [:]))
                            try data.write(to: exportDirectory.appendingPathComponent("statistics-\(period.rawValue)-\(dark ? "dark" : "light").png"))
                        }
                    }
                }
            }
        }
    }

    private func usage(tokens: Int64, cost: Double) -> LocalTokenUsage {
        LocalTokenUsage(totalTokens: tokens, inputTokens: tokens, cachedInputTokens: 0,
                        cacheWriteInputTokens: 0, outputTokens: 0, reasoningOutputTokens: 0,
                        apiEquivalentCostUSD: cost)
    }
}

private struct MonthlyPreviewLoginManager: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
