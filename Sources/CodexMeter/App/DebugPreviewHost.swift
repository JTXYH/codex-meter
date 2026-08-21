#if DEBUG
import AppKit
import SwiftUI

private let debugPanelSnapshotSize = CGSize(width: 420, height: 950)

struct DebugDemoUsageLoader: CodexUsageLoading {
    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: now)

        let dailyUsage = (0..<90).compactMap { index -> DailyTokenUsage? in
            guard let date = calendar.date(byAdding: .day, value: index - 89, to: today) else {
                return nil
            }
            let tokens: Int64 = index.isMultiple(of: 11)
                ? 0
                : Int64(420_000 + ((index * 97_531) % 3_800_000))
            return DailyTokenUsage(date: date, tokens: tokens)
        }
        let peak = dailyUsage.map(\.tokens).max() ?? 0

        let bucket = RateLimitBucket(
            id: "codex",
            name: "Codex",
            planType: "plus",
            hasCredits: false,
            unlimitedCredits: false,
            creditBalance: "0",
            windows: [
                RateLimitWindow(
                    id: "codex-primary",
                    bucketID: "codex",
                    bucketName: "Codex",
                    kind: .primary,
                    usedPercent: 28,
                    windowDurationMinutes: 300,
                    resetsAt: now.addingTimeInterval(2 * 60 * 60 + 18 * 60)
                ),
                RateLimitWindow(
                    id: "codex-secondary",
                    bucketID: "codex",
                    bucketName: "Codex",
                    kind: .secondary,
                    usedPercent: 37,
                    windowDurationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60 + 3 * 60 * 60)
                ),
            ]
        )

        return CodexUsageSnapshot(
            fetchedAt: now,
            account: CodexAccount(type: "chatgpt", email: "demo@example.com", planType: "plus"),
            rateLimitBuckets: [bucket],
            usageSummary: TokenUsageSummary(
                lifetimeTokens: 128_640_000,
                peakDailyTokens: peak,
                longestRunningTurnSeconds: 7_842,
                currentStreakDays: 18,
                longestStreakDays: 31
            ),
            dailyUsage: dailyUsage
        )
    }
}

struct DebugDemoLocalTokenUsageLoader: LocalTokenUsageLoading {
    func todayUsage(at now: Date) async -> LocalTokenUsage {
        LocalTokenUsage(
            totalTokens: 3_280_000,
            inputTokens: 3_096_000,
            cachedInputTokens: 2_600_000,
            cacheWriteInputTokens: 0,
            outputTokens: 184_000,
            reasoningOutputTokens: 96_000,
            apiEquivalentCostUSD: 8.25
        )
    }
}

private struct DebugMeterPanelSnapshotView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.meterPanelTop, .meterPanel, .meterPanelBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().overlay(Color.meterBorder)

                if let snapshot = store.snapshot {
                    VStack(spacing: 12) {
                        HeroUsageCard(snapshot: snapshot)
                        TokenActivityCard(snapshot: snapshot)
                        UsageHeatmapCard(snapshot: snapshot)
                        UsageSummaryCard(snapshot: snapshot)
                    }
                    .padding(14)
                }

                footer
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.meterFooter)
                    .overlay(alignment: .top) {
                        Divider().overlay(Color.meterBorder)
                    }
            }
        }
        .frame(
            width: debugPanelSnapshotSize.width,
            height: debugPanelSnapshotSize.height
        )
        .foregroundStyle(Color.meterPrimary)
    }

    private var header: some View {
        HStack(spacing: 11) {
            CodexIconView(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Codex Meter")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if let plan = store.snapshot?.account?.displayPlan {
                        Text(plan.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.meterAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.meterAccent.opacity(0.11), in: Capsule())
                    }
                }
                if let email = store.snapshot?.account?.email {
                    HStack(spacing: 4) {
                        Text(EmailPrivacy.masked(email))
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8.5, weight: .semibold))
                    }
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.meterControl, in: Circle())
        }
    }

    private var footer: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .frame(width: 38, height: 32)
                .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Spacer()
            Image(systemName: "power")
                .frame(width: 38, height: 32)
                .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct DebugPreviewHost: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var settings: AppSettings
    @State private var didExportSnapshot = false

    private var shouldExportSnapshots: Bool {
        ProcessInfo.processInfo.environment["CODEX_METER_DEMO"] == "1"
    }

    var body: some View {
        MeterPanelView()
            .environmentObject(store)
            .environmentObject(settings)
            .onAppear {
                NSApplication.shared.activate(ignoringOtherApps: true)
                guard shouldExportSnapshots else { return }
                Task { await store.refresh() }
                exportMenuBarIconPreview()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    exportStandaloneSettingsSnapshots()
                }
            }
            .onChange(of: store.snapshot) { _, snapshot in
                guard shouldExportSnapshots, snapshot != nil, !didExportSnapshot else { return }
                didExportSnapshot = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    exportSnapshots()
                }
            }
    }

    private func exportSnapshots() {
        let originalAppearance = settings.appearance
        let originalLanguage = settings.language
        defer {
            settings.appearance = originalAppearance
            settings.language = originalLanguage
        }

        exportPanelSnapshot(
            appearance: .light,
            language: .simplifiedChinese,
            filename: "/tmp/CodexMeter-preview-zh-Hans-light.png"
        )
        exportPanelSnapshot(
            appearance: .dark,
            language: .english,
            filename: "/tmp/CodexMeter-preview-en-dark.png"
        )
        exportPanelSnapshot(
            appearance: .light,
            language: .traditionalChinese,
            filename: "/tmp/CodexMeter-preview-zh-Hant-light.png"
        )
        exportSettingsSnapshot(
            appearance: .dark,
            language: .traditionalChinese,
            filename: "/tmp/CodexMeter-settings-zh-Hant-dark.png"
        )
    }

    private func exportStandaloneSettingsSnapshots() {
        let originalAppearance = settings.appearance
        let originalLanguage = settings.language
        defer {
            settings.appearance = originalAppearance
            settings.language = originalLanguage
        }

        exportSettingsSnapshot(
            appearance: .light,
            language: .simplifiedChinese,
            filename: "/tmp/CodexMeter-settings-zh-Hans-light.png"
        )
        exportSettingsSnapshot(
            appearance: .dark,
            language: .japanese,
            filename: "/tmp/CodexMeter-settings-ja-dark.png"
        )
        exportSettingsSnapshot(
            appearance: .light,
            language: .simplifiedChinese,
            filename: "/tmp/CodexMeter-settings-backgrounds-empty-zh-Hans-light.png",
            showBackgroundsInitially: true
        )
        exportSettingsSnapshot(
            appearance: .light,
            language: .simplifiedChinese,
            filename: "/tmp/CodexMeter-settings-backgrounds-filled-zh-Hans-light.png",
            showBackgroundsInitially: true,
            includeBackgroundImages: true
        )
    }

    private func exportPanelSnapshot(
        appearance: AppAppearance,
        language: AppLanguage,
        filename: String
    ) {
        settings.appearance = appearance
        settings.language = language
        let colorScheme: ColorScheme = appearance == .dark ? .dark : .light
        let previewBackgrounds = makeDebugBackgroundStore(includeImages: true)
        let renderer = ImageRenderer(
            content: DebugMeterPanelSnapshotView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(previewBackgrounds)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.proposedSize = ProposedViewSize(
            width: debugPanelSnapshotSize.width,
            height: debugPanelSnapshotSize.height
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        try? png.write(to: URL(fileURLWithPath: filename), options: .atomic)
    }

    private func exportSettingsSnapshot(
        appearance: AppAppearance,
        language: AppLanguage,
        filename: String,
        showBackgroundsInitially: Bool = false,
        includeBackgroundImages: Bool = false
    ) {
        settings.appearance = appearance
        settings.language = language
        let colorScheme: ColorScheme = appearance == .dark ? .dark : .light
        let previewBackgrounds = makeDebugBackgroundStore(
            includeProfile: showBackgroundsInitially,
            includeImages: includeBackgroundImages
        )
        let renderer = ImageRenderer(
            content: SettingsPanelView(showBackgroundsInitially: showBackgroundsInitially)
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(UpdateController.shared)
                .environmentObject(previewBackgrounds)
                .environment(\.colorScheme, colorScheme)
                .frame(width: 760, height: 516, alignment: .top)
        )
        renderer.proposedSize = ProposedViewSize(width: 760, height: 516)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        try? png.write(to: URL(fileURLWithPath: filename), options: .atomic)
    }

    private func makeDebugBackgroundStore(
        includeProfile: Bool = true,
        includeImages: Bool
    ) -> QuotaBackgroundStore {
        let identifier = "CodexMeter.DebugBackgrounds.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: identifier) ?? .standard
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(identifier, isDirectory: true)
        let backgrounds = QuotaBackgroundStore(
            defaults: defaults,
            storageDirectory: directory
        )
        guard includeProfile else { return backgrounds }

        let profileID = backgrounds.addProfile(named: "演示背景")
        guard includeImages else { return backgrounds }

        let image = makeDebugBackgroundImage()
        for slot in QuotaBackgroundSlot.allCases {
            try? backgrounds.saveImage(
                original: image,
                cropped: image,
                for: slot,
                profileID: profileID
            )
        }
        return backgrounds
    }

    private func makeDebugBackgroundImage() -> NSImage {
        let size = QuotaBackgroundImageProcessor.outputSize
        let image = NSImage(size: size)
        image.lockFocus()
        NSGradient(colors: [
            NSColor.systemPink.withAlphaComponent(0.72),
            NSColor.systemPurple.withAlphaComponent(0.88),
            NSColor.systemBlue.withAlphaComponent(0.82),
        ])?.draw(in: CGRect(origin: .zero, size: size), angle: 0)
        NSColor.white.withAlphaComponent(0.28).setFill()
        NSBezierPath(ovalIn: CGRect(x: 850, y: -130, width: 680, height: 680)).fill()
        NSColor.white.withAlphaComponent(0.46).setFill()
        NSBezierPath(ovalIn: CGRect(x: 1_070, y: 100, width: 300, height: 300)).fill()
        image.unlockFocus()
        return image
    }

    private func exportMenuBarIconPreview() {
        let renderer = ImageRenderer(
            content: HStack(spacing: 0) {
                menuBarIconSample(colorScheme: .light, background: .white)
                menuBarIconSample(
                    colorScheme: .dark,
                    background: Color(red: 0.10, green: 0.105, blue: 0.12)
                )
            }
        )
        renderer.proposedSize = ProposedViewSize(width: 192, height: 32)
        renderer.scale = 4

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        try? png.write(
            to: URL(fileURLWithPath: "/tmp/CodexMeter-menu-icon-preview.png"),
            options: .atomic
        )
    }

    private func menuBarIconSample(colorScheme: ColorScheme, background: Color) -> some View {
        HStack(spacing: 6) {
            MenuBarCodexIconView()
            Text("100%")
                .font(.system(size: 16, weight: .medium))
        }
        .padding(.horizontal, 10)
        .frame(width: 96, height: 32, alignment: .leading)
        .background(background)
        .environment(\.colorScheme, colorScheme)
    }
}
#endif
