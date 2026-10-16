#if DEBUG
import AppKit
import SwiftUI

/// Deterministic, isolated fixtures used only by the explicit demo build.
struct DebugDemoUsageLoader: CodexUsageLoading {
    var usesEnvironmentOverrides = true

    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        if usesEnvironmentOverrides, ProcessInfo.processInfo.environment["CODEX_METER_DEMO_REFRESH_DELAY"] == "1" {
            try await Task.sleep(for: .seconds(3))
        }
        if usesEnvironmentOverrides, ProcessInfo.processInfo.environment["CODEX_METER_DEMO_REMOTE_FAILURE"] == "1" {
            throw CodexMeterError.server("Unable to fetch account usage")
        }
        let now = Date(), calendar = UsageCalendar.calendar
        let today = calendar.startOfDay(for: now)
        var dailyUsage = (0..<120).map { index -> DailyTokenUsage in
            let date = calendar.date(byAdding: .day, value: index - 119, to: today)!
            let recent: [Int64] = [0, 765_000_000, 945_000_000, 450_000_000, 750_000_000, 810_000_000, 560_000_000, 380_000_000]
            let age = 119 - index
            let tokens: Int64 = age < recent.count ? recent[age] : age < 15 ? 551_428_571 : Int64((index * 7 + index / 9) % 4 + 1) * 17_300_000
            return DailyTokenUsage(date: date, tokens: tokens)
        }
        var excess = max(0, dailyUsage.reduce(Int64(0)) { $0 + $1.tokens } - 12_680_000_000)
        for index in 0..<100 where excess > 0 {
            let reduction = min(excess, dailyUsage[index].tokens)
            dailyUsage[index] = DailyTokenUsage(date: dailyUsage[index].date, tokens: dailyUsage[index].tokens - reduction)
            excess -= reduction
        }
        let preview = usesEnvironmentOverrides ? ProcessInfo.processInfo.environment["CODEX_METER_QUOTA_PREVIEW"] : nil
        let remaining: Double = preview == "low" ? 16 : preview == "exhausted" ? 0 : 64
        let primary = RateLimitWindow(id: "codex-primary", bucketID: "codex", bucketName: "Codex", kind: .primary,
                                      usedPercent: 100 - remaining, windowDurationMinutes: 300,
                                      resetsAt: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: now))
        let secondary = RateLimitWindow(id: "codex-secondary", bucketID: "codex", bucketName: "Codex", kind: .secondary,
                                        usedPercent: 68, windowDurationMinutes: 10_080,
                                        resetsAt: Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: now)))
        return CodexUsageSnapshot(
            fetchedAt: now,
            account: CodexAccount(type: "chatgpt", email: "demo@example.com", planType: "pro"),
            rateLimitBuckets: [RateLimitBucket(id: "codex", name: "Codex", planType: "pro", hasCredits: true,
                                               unlimitedCredits: false, creditBalance: "0.00",
                                               windows: preview == "weekly" ? [secondary] : [primary, secondary])],
            usageSummary: TokenUsageSummary(lifetimeTokens: 13_760_000_000, peakDailyTokens: 1_020_000_000,
                                             longestRunningTurnSeconds: 8_280, currentStreakDays: 14, longestStreakDays: 28),
            dailyUsage: dailyUsage,
            resetCredits: RateLimitResetCredits(availableCount: 2, credits: [
                RateLimitResetCredit(id: "demo-reset-1", resetType: "codexRateLimits", status: "available",
                    grantedAt: Date(timeIntervalSince1970: 1_790_707_824), expiresAt: Date(timeIntervalSince1970: 1_793_299_824)),
                RateLimitResetCredit(id: "demo-reset-2", resetType: "codexRateLimits", status: "available",
                    grantedAt: Date(timeIntervalSince1970: 1_791_415_344), expiresAt: Date(timeIntervalSince1970: 1_794_007_344)),
            ])
        )
    }
}

actor DebugDemoLocalTokenUsageLoader: LocalTokenUsageLoading {
    private let compact: Bool

    init(compact: Bool = ProcessInfo.processInfo.environment["CODEX_METER_DEMO_LAYOUT"] == "compact") {
        self.compact = compact
    }

    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        let day = UsageCalendar.calendar.startOfDay(for: now)
        let samples: [(String, LocalTokenUsage)] = compact ? [
            ("gpt-6-astra", LocalTokenUsage(totalTokens: 377_130_000, inputTokens: 376_000_000, cachedInputTokens: 365_000_000,
                cacheWriteInputTokens: 0, outputTokens: 1_130_000, reasoningOutputTokens: 0)),
            ("codex-auto-review", LocalTokenUsage(totalTokens: 16_744_500, inputTokens: 16_710_000, cachedInputTokens: 16_000_000,
                cacheWriteInputTokens: 0, outputTokens: 34_500, reasoningOutputTokens: 0))
        ] : [
            ("gpt-6-astra", LocalTokenUsage(totalTokens: 28_900_000, inputTokens: 28_800_000, cachedInputTokens: 27_600_000,
                                           cacheWriteInputTokens: 0, outputTokens: 100_000, reasoningOutputTokens: 0)),
            ("gpt-6.1-sol", LocalTokenUsage(totalTokens: 2_862_000, inputTokens: 2_830_000, cachedInputTokens: 2_510_000,
                                             cacheWriteInputTokens: 0, outputTokens: 32_000, reasoningOutputTokens: 0))
        ]
        return LocalTokenUsageSnapshot(today: samples.reduce(.zero) { $0.adding($1.1) }, lifetime: nil,
                                       dailyModelUsage: samples.map { DailyModelTokenUsage(day: day, model: $0.0, usage: $0.1) })
    }
}

struct DebugDemoAccountModelLoader: AccountModelUsageLoading {
    var compact = ProcessInfo.processInfo.environment["CODEX_METER_DEMO_LAYOUT"] == "compact"

    func fetchModels(in range: AccountModelDateRange, account: CodexAccount) async throws -> [AccountModelIdentity] {
        if compact {
            return [AccountModelIdentity(model: "gpt-6-astra", usageShare: 0.99786246),
                    AccountModelIdentity(model: "codex-auto-review", usageShare: 0.00003752),
                    AccountModelIdentity(model: "gpt-6.1-sol", serviceTier: "fast", usageShare: 0.00189891),
                    AccountModelIdentity(model: "gpt-6-luna", usageShare: 0.00013169),
                    AccountModelIdentity(model: "gpt-5.6-luna", usageShare: 0.00006942)]
        }
        return [AccountModelIdentity(model: "gpt-6-astra", usageShare: 0.8),
                AccountModelIdentity(model: "gpt-6.1-sol", serviceTier: "fast", usageShare: 0.15),
                AccountModelIdentity(model: "gpt-6-luna", usageShare: 0.03),
                AccountModelIdentity(model: "gpt-5.6-luna", usageShare: 0.01),
                AccountModelIdentity(model: "codex-auto-review", usageShare: 0.01)]
    }
}

struct DebugPreviewHost: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    @State private var didExport = false

    var body: some View {
        MeterPanelView()
            .environmentObject(store).environmentObject(settings)
            .task {
                guard ProcessInfo.processInfo.environment["CODEX_METER_DEMO"] == "1", !didExport else { return }
                didExport = true
                if ProcessInfo.processInfo.environment["CODEX_METER_SNAPSHOT_SCOPE"] == "identity",
                   let path = ProcessInfo.processInfo.environment["CODEX_METER_SNAPSHOT_DIRECTORY"] {
                    await exportIdentitySnapshots(to: URL(fileURLWithPath: path, isDirectory: true))
                    return
                }
                settings.language = .simplifiedChinese
                settings.usageStatisticsPeriod = .day
                settings.followCodexApp = true
                if ProcessInfo.processInfo.environment["CODEX_METER_DEMO_LAYOUT"] == "compact" {
                    settings.showQuotaCard = false
                    settings.showTokenActivityCard = true
                    settings.showActivityOverviewCard = false
                    settings.showMonthlyUsageCard = true
                    settings.showUsageHeatmapCard = false
                    settings.showUsageSummaryCard = false
                    settings.showCreditsBalanceCard = false
                    settings.showResetCreditsCard = false
                    settings.dashboardSectionOrder = [.tokenActivity, .monthlyUsage]
                    settings.usageStatisticsDayCount = 30
                }
                await store.refresh()
                while store.isRefreshing { try? await Task.sleep(nanoseconds: 20_000_000) }
                await store.refreshLocalUsage()
                for period in UsagePeriod.statisticsPeriods {
                    let date = period == .day ? UsageCalendar.calendar.date(byAdding: .day, value: -1, to: Date())! : Date()
                    await store.loadAccountModels(for: period, containing: date)
                }
                if let path = ProcessInfo.processInfo.environment["CODEX_METER_SNAPSHOT_DIRECTORY"] {
                    await exportSnapshots(to: URL(fileURLWithPath: path, isDirectory: true))
                }
            }
    }

    @MainActor private func exportIdentitySnapshots(to directory: URL) async {
        let originalAppearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = originalAppearance }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let previewSettings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()),
                preferredLanguages: ["zh-Hans"], launchAtLoginManager: DebugPreviewStartupManager(),
                codexLifecycleManager: DebugPreviewStartupManager())
            previewSettings.language = .simplifiedChinese
            previewSettings.usageStatisticsPeriod = .day
            previewSettings.usageStatisticsDayCount = 30
            previewSettings.followCodexApp = true
            previewSettings.showQuotaCard = true
            previewSettings.showTokenActivityCard = true
            previewSettings.showMonthlyUsageCard = true
            previewSettings.showActivityOverviewCard = false
            previewSettings.showUsageHeatmapCard = false
            previewSettings.showUsageSummaryCard = false
            previewSettings.showCreditsBalanceCard = false
            previewSettings.showResetCreditsCard = false
            previewSettings.dashboardSectionOrder = [.quota, .tokenActivity, .monthlyUsage]

            for appearance in [AppAppearance.light, .dark] {
                previewSettings.appearance = appearance
                let scheme: ColorScheme = appearance == .dark ? .dark : .light
                for theme in PanelTheme.allCases {
                    previewSettings.panelTheme = theme
                    let suffix = "\(theme.rawValue)-\(appearance.rawValue)"
                    for scenario in ["ready", "loading", "partial"] {
                        await writeIdentityScenario(scenario, settings: previewSettings, scheme: scheme,
                            url: directory.appendingPathComponent("\(scenario == "ready" ? "panel" : scenario)-\(suffix).png"))
                    }
                }
            }
            previewSettings.panelTheme = .quiet
            previewSettings.appearance = .light
            for scenario in ["error", "signedout", "nocodex"] {
                await writeIdentityScenario(scenario, settings: previewSettings, scheme: .light,
                    url: directory.appendingPathComponent("state-\(scenario)-quiet-light.png"))
            }
            let aboutStore = makeIdentityStore("ready", settings: previewSettings)
            await aboutStore.refresh()
            await writeSnapshot(SettingsPanelView(initialSection: .updates)
                .environmentObject(aboutStore).environmentObject(previewSettings)
                .environmentObject(UpdateController(previewState: .idle)).environment(\.colorScheme, .light),
                width: 820, height: 620, url: directory.appendingPathComponent("settings-updates-quiet-light.png"),
                scheme: .light, settleDelay: .milliseconds(450))
            aboutStore.stop()
            try Data("Identity views exported successfully\n".utf8).write(to: directory.appendingPathComponent("complete.txt"))
        } catch {
            try? Data("Identity export failed: \(error.localizedDescription)\n".utf8)
                .write(to: directory.appendingPathComponent("error.txt"))
        }
    }

    @MainActor private func makeIdentityStore(_ scenario: String, settings: AppSettings) -> UsageStore {
        UsageStore(loader: DebugScenarioUsageLoader(scenario: scenario, usesEnvironmentOverrides: false),
            localUsageLoader: DebugIdentityLocalTokenUsageLoader(delayed: scenario == "loading"),
            settings: settings, modelLoader: DebugDemoAccountModelLoader(compact: true))
    }

    @MainActor private func writeIdentityScenario(_ scenario: String, settings: AppSettings,
                                                 scheme: ColorScheme, url: URL) async {
        let previewStore = makeIdentityStore(scenario, settings: settings)
        var pendingRefresh: Task<Void, Never>?
        defer {
            pendingRefresh?.cancel()
            previewStore.stop()
        }
        if scenario == "loading" || scenario == "partial" {
            if scenario == "partial" { await previewStore.refreshLocalUsage() }
            pendingRefresh = Task { await previewStore.refresh() }
            await Task.yield()
        } else {
            await previewStore.refresh()
            if scenario == "ready",
               let yesterday = UsageCalendar.calendar.date(byAdding: .day, value: -1, to: Date()) {
                await previewStore.loadAccountModels(for: .day, containing: yesterday)
            }
        }
        await writeSnapshot(MeterPanelView().environmentObject(previewStore).environmentObject(settings)
            .environment(\.colorScheme, scheme), width: 420, height: 700, url: url, scheme: scheme,
            settleDelay: .milliseconds(450))
        // End the ten-second fixtures immediately after capture, including their local child task.
        pendingRefresh?.cancel()
        previewStore.stop()
        await pendingRefresh?.value
    }

    @MainActor private func exportSnapshots(to directory: URL) async {
        guard let snapshot = store.dashboardSnapshot else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let originalTheme = settings.panelTheme, originalAppearance = settings.appearance
        defer { settings.panelTheme = originalTheme; settings.appearance = originalAppearance }
        if ProcessInfo.processInfo.environment["CODEX_METER_SNAPSHOT_SCOPE"] == "preferences" {
            let futureSnapshot = CodexUsageSnapshot(fetchedAt: snapshot.fetchedAt, account: snapshot.account,
                rateLimitBuckets: snapshot.rateLimitBuckets.map { bucket in
                    RateLimitBucket(id: bucket.id, name: bucket.name, planType: bucket.planType,
                        hasCredits: bucket.hasCredits, unlimitedCredits: bucket.unlimitedCredits,
                        creditBalance: bucket.creditBalance,
                        windows: bucket.windows.filter { $0.windowDurationMinutes == 10_080 })
                }, usageSummary: snapshot.usageSummary, dailyUsage: snapshot.dailyUsage, resetCredits: snapshot.resetCredits)
            for appearance in [AppAppearance.light, .dark] {
                settings.appearance = appearance
                let scheme: ColorScheme = appearance == .dark ? .dark : .light
                for theme in PanelTheme.allCases {
                    settings.panelTheme = theme
                    let suffix = "\(theme.rawValue)-\(appearance.rawValue)"
                    await writeSnapshot(MeterPanelView().environmentObject(store).environmentObject(settings)
                        .environment(\.colorScheme, scheme), width: 420, height: 700,
                        url: directory.appendingPathComponent("panel-\(suffix).png"), scheme: scheme)
                    for (name, value) in [("today", snapshot), ("future", futureSnapshot)] {
                        await writeSnapshot(DashboardCard(section: .quota, snapshot: value)
                            .environmentObject(store).environmentObject(settings).environment(\.meterTheme, theme)
                            .environment(\.colorScheme, scheme), width: 418,
                            url: directory.appendingPathComponent("quota-\(name)-\(suffix).png"), scheme: scheme)
                    }
                    for section in [SettingsSection.general, .fonts, .refresh, .updates] {
                        await writeSnapshot(SettingsPanelView(initialSection: section)
                            .environmentObject(store).environmentObject(settings)
                            .environmentObject(UpdateController(previewState: .idle))
                            .environment(\.colorScheme, scheme), width: 820, height: 620,
                            url: directory.appendingPathComponent("settings-\(section.rawValue)-\(suffix).png"), scheme: scheme)
                    }
                    await writeSnapshot(QuotaStatusSettingsView().padding(30).background(Color.meterCard)
                        .environmentObject(settings).environment(\.meterTheme, theme).environment(\.colorScheme, scheme),
                        width: 655, url: directory.appendingPathComponent("status-copy-\(suffix).png"), scheme: scheme)
                }
            }
            try? Data("Preferences views exported successfully\n".utf8).write(to: directory.appendingPathComponent("complete.txt"))
            return
        }
        if ProcessInfo.processInfo.environment["CODEX_METER_SNAPSHOT_SCOPE"] == "compact" {
            for appearance in [AppAppearance.light, .dark] {
                settings.appearance = appearance
                let scheme: ColorScheme = appearance == .dark ? .dark : .light
                for theme in PanelTheme.allCases {
                    settings.panelTheme = theme
                    let suffix = "\(theme.rawValue)-\(appearance.rawValue)"
                    await writeSnapshot(MeterPanelView().environmentObject(store).environmentObject(settings)
                        .environment(\.colorScheme, scheme), width: 420, height: 700,
                        url: directory.appendingPathComponent("panel-\(suffix).png"), scheme: scheme)
                    for section in [DashboardSection.tokenActivity, .monthlyUsage] {
                        await writeSnapshot(DashboardCard(section: section, snapshot: snapshot)
                            .environmentObject(store).environmentObject(settings).environment(\.meterTheme, theme)
                            .environment(\.colorScheme, scheme), width: 418,
                            url: directory.appendingPathComponent("\(section == .tokenActivity ? "today" : "history")-\(suffix).png"), scheme: scheme)
                    }
                }
            }
            try? Data("Compact views exported successfully\n".utf8).write(to: directory.appendingPathComponent("complete.txt"))
            return
        }
        let cardNames: [DashboardSection: String] = [.quota: "quota", .tokenActivity: "today", .activityOverview: "overview",
                                                    .monthlyUsage: "history", .usageHeatmap: "heatmap", .usageSummary: "summary", .creditsBalance: "credits", .resetCredits: "reset-cards"]
        for appearance in [AppAppearance.light, .dark] {
            settings.appearance = appearance
            let scheme: ColorScheme = appearance == .dark ? .dark : .light
            for theme in PanelTheme.allCases {
                settings.panelTheme = theme
                let suffix = "\(theme.rawValue)-\(appearance.rawValue)"
                await writeSnapshot(MeterPanelView().environmentObject(store).environmentObject(settings)
                    .environment(\.colorScheme, scheme), width: 420, height: 700,
                    url: directory.appendingPathComponent("panel-\(suffix).png"), scheme: scheme)
                for section in DashboardSection.allCases {
                    await writeSnapshot(DashboardCard(section: section, snapshot: snapshot)
                        .padding(.top, theme.isInstrument ? 1 : 0)
                        .overlay(alignment: .top) { if theme.isInstrument { Color.meterBorder.frame(height: 1) } }
                        .environmentObject(store).environmentObject(settings).environment(\.meterTheme, theme)
                        .environment(\.colorScheme, scheme), width: 420,
                        url: directory.appendingPathComponent("card-\(cardNames[section]!)-\(suffix).png"), scheme: scheme)
                }
            }
            settings.panelTheme = .quiet
            for section in SettingsSection.allCases {
                settings.appearance = .system
                let fixture = StorageInfo(bytes: 4_200_000, dailyRows: 120, checkpoints: 18,
                                          oldest: DateOnlyParser.date(from: "2026-09-01", timeZone: .current), newest: Date())
                await writeSnapshot(SettingsPanelView(initialSection: section, initialStorageInfo: fixture)
                    .environmentObject(store).environmentObject(settings).environmentObject(UpdateController(previewState: .idle))
                    .environment(\.colorScheme, scheme), width: 820, height: 620,
                    url: directory.appendingPathComponent("settings-\(section.rawValue)-\(appearance.rawValue).png"), scheme: scheme)
            }
            for dialog in [SettingsPreviewDialog.language, .cleanup] {
                let name = dialog == .language ? "language" : "cleanup"
                let fixture = StorageInfo(bytes: 4_200_000, dailyRows: 120, checkpoints: 18,
                                          oldest: DateOnlyParser.date(from: "2026-09-01", timeZone: .current), newest: Date())
                await writeSnapshot(SettingsPanelView(initialSection: dialog == .language ? .general : .data,
                                                       initialStorageInfo: fixture, previewDialog: dialog)
                    .environmentObject(store).environmentObject(settings).environmentObject(UpdateController(previewState: .idle))
                    .environment(\.colorScheme, scheme), width: 820, height: 620,
                    url: directory.appendingPathComponent("settings-\(name)-\(appearance.rawValue).png"), scheme: scheme)
            }
            for scenario in ["loading", "error", "signedout", "nocodex", "stale"] {
                let scenarioStore = UsageStore(loader: DebugScenarioUsageLoader(scenario: scenario),
                                               localUsageLoader: DebugDemoLocalTokenUsageLoader(), settings: settings,
                                               modelLoader: DebugDemoAccountModelLoader())
                if scenario != "loading" { await scenarioStore.refresh() }
                if scenario == "stale" { await scenarioStore.refresh() }
                await writeSnapshot(MeterPanelView().environmentObject(scenarioStore).environmentObject(settings)
                    .environment(\.colorScheme, scheme), width: 420, height: 700,
                    url: directory.appendingPathComponent("state-\(scenario)-\(appearance.rawValue).png"), scheme: scheme)
            }
        }
        try? Data("Native views exported successfully\n".utf8).write(to: directory.appendingPathComponent("complete.txt"))
    }

    /// Renders the production SwiftUI views through AppKit, including native controls.
    @MainActor private func writeSnapshot<Content: View>(_ content: Content, width: CGFloat, height: CGFloat? = nil,
                                                         url: URL, scheme: ColorScheme,
                                                         settleDelay: Duration = .milliseconds(80)) async {
        let hosting = NSHostingView(rootView: content.frame(width: width).fixedSize(horizontal: false, vertical: height == nil))
        hosting.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        hosting.setFrameSize(NSSize(width: width, height: height ?? 800))
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = hosting.appearance
        window.contentView = hosting
        defer { window.contentView = nil }
        hosting.layoutSubtreeIfNeeded()
        if height == nil { hosting.setFrameSize(NSSize(width: width, height: hosting.fittingSize.height)) }
        try? await Task.sleep(for: settleDelay)
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url, options: .atomic)
    }
}

private actor DebugScenarioUsageLoader: CodexUsageLoading {
    let scenario: String
    let usesEnvironmentOverrides: Bool
    private var requests = 0
    init(scenario: String, usesEnvironmentOverrides: Bool = true) {
        self.scenario = scenario
        self.usesEnvironmentOverrides = usesEnvironmentOverrides
    }
    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        requests += 1
        if scenario == "loading" || scenario == "partial" { try await Task.sleep(for: .seconds(10)) }
        if scenario == "error" || (scenario == "stale" && requests > 1) { throw CodexMeterError.timeout }
        if scenario == "nocodex" { throw CodexMeterError.codexNotFound }
        if scenario == "signedout" {
            return CodexUsageSnapshot(fetchedAt: Date(), account: nil, rateLimitBuckets: [], usageSummary: nil, dailyUsage: [])
        }
        return try await DebugDemoUsageLoader(usesEnvironmentOverrides: usesEnvironmentOverrides).fetchSnapshot()
    }
}

private struct DebugIdentityLocalTokenUsageLoader: LocalTokenUsageLoading {
    let delayed: Bool

    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        if delayed {
            do { try await Task.sleep(for: .seconds(10)) }
            catch { return LocalTokenUsageSnapshot(today: .zero, lifetime: nil) }
        }
        return await DebugDemoLocalTokenUsageLoader(compact: true).usage(at: now)
    }
}

private struct DebugPreviewStartupManager: LaunchAtLoginManaging, CodexLifecycleManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}
#endif
