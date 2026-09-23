#if DEBUG
import AppKit
import SwiftUI

private let debugPanelSnapshotWidth: CGFloat = 420

struct DebugDemoUsageLoader: CodexUsageLoading {
    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: now)

        let dailyUsage = (0..<120).compactMap { index -> DailyTokenUsage? in
            guard let date = calendar.date(byAdding: .day, value: index - 119, to: today) else {
                return nil
            }
            let tokens: Int64 = index.isMultiple(of: 11)
                ? 0
                : Int64(420_000 + ((index * 97_531) % 3_800_000))
            return DailyTokenUsage(date: date, tokens: tokens)
        }
        let peak = dailyUsage.map(\.tokens).max() ?? 0

        let quotaPreview = ProcessInfo.processInfo.environment["CODEX_METER_QUOTA_PREVIEW"]
        let primaryRemainingPercent: Double = switch quotaPreview {
        case "low": 16
        case "exhausted": 0
        default: 72
        }
        let weeklyRemainingPercent: Double = switch quotaPreview {
        case "low": 38
        case "exhausted": 8
        case "weekly": 38
        default: 63
        }
        let windows: [RateLimitWindow]
        if quotaPreview == "weekly" {
            windows = [
                RateLimitWindow(
                    id: "codex-primary",
                    bucketID: "codex",
                    bucketName: "Codex",
                    kind: .primary,
                    usedPercent: 100 - weeklyRemainingPercent,
                    windowDurationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60 + 3 * 60 * 60)
                ),
            ]
        } else {
            windows = [
                RateLimitWindow(
                    id: "codex-primary",
                    bucketID: "codex",
                    bucketName: "Codex",
                    kind: .primary,
                    usedPercent: 100 - primaryRemainingPercent,
                    windowDurationMinutes: 300,
                    resetsAt: now.addingTimeInterval(2 * 60 * 60 + 18 * 60)
                ),
                RateLimitWindow(
                    id: "codex-secondary",
                    bucketID: "codex",
                    bucketName: "Codex",
                    kind: .secondary,
                    usedPercent: 100 - weeklyRemainingPercent,
                    windowDurationMinutes: 10_080,
                    resetsAt: now.addingTimeInterval(4 * 24 * 60 * 60 + 3 * 60 * 60)
                ),
            ]
        }

        let bucket = RateLimitBucket(
            id: "codex",
            name: "Codex",
            planType: "plus",
            hasCredits: true,
            unlimitedCredits: false,
            creditBalance: "1905",
            windows: windows
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
    func usage(at now: Date) async -> LocalTokenUsageSnapshot {
        let today = LocalTokenUsage(
            totalTokens: 3_280_000,
            inputTokens: 3_096_000,
            cachedInputTokens: 2_600_000,
            cacheWriteInputTokens: 0,
            outputTokens: 184_000,
            reasoningOutputTokens: 96_000,
            apiEquivalentCostUSD: 8.25
        )
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: now)!.start
        let monthly = (0..<6).map { offset in
            let factor = Int64(6 - offset)
            return MonthlyTokenUsage(
                month: calendar.date(byAdding: .month, value: -offset, to: currentMonth)!,
                usage: LocalTokenUsage(
                    totalTokens: 6_000_000 * factor, inputTokens: 5_600_000 * factor,
                    cachedInputTokens: 4_200_000 * factor, cacheWriteInputTokens: 0,
                    outputTokens: 400_000 * factor, reasoningOutputTokens: 200_000 * factor,
                    apiEquivalentCostUSD: 14.628571 * Double(factor)
                )
            )
        }
        return LocalTokenUsageSnapshot(
            today: today,
            lifetime: LocalTokenUsage(
                totalTokens: 128_640_000,
                inputTokens: 120_000_000,
                cachedInputTokens: 96_000_000,
                cacheWriteInputTokens: 0,
                outputTokens: 8_640_000,
                reasoningOutputTokens: 4_320_000,
                apiEquivalentCostUSD: 307.20
            ),
            monthlyUsage: monthly,
            dailyUsage: (0..<30).map { offset in
                let factor = Double((offset * 7) % 10 + 4) / 10
                return PeriodTokenUsage(
                    start: calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!,
                    usage: offset == 0 ? today : LocalTokenUsage(
                        totalTokens: Int64(3_280_000 * factor), inputTokens: Int64(3_096_000 * factor),
                        cachedInputTokens: Int64(2_600_000 * factor), cacheWriteInputTokens: 0,
                        outputTokens: Int64(184_000 * factor), reasoningOutputTokens: Int64(96_000 * factor),
                        apiEquivalentCostUSD: 8.25 * factor
                    )
                )
            },
            hourlyUsage: (0..<24).map { offset in
                let factor = Double((offset * 7) % 10 + 4) / 10
                return PeriodTokenUsage(
                    start: calendar.date(byAdding: .hour, value: -offset, to: calendar.dateInterval(of: .hour, for: now)!.start)!,
                    usage: LocalTokenUsage(
                        totalTokens: Int64(328_000 * factor), inputTokens: Int64(309_600 * factor),
                        cachedInputTokens: Int64(260_000 * factor), cacheWriteInputTokens: 0,
                        outputTokens: Int64(18_400 * factor), reasoningOutputTokens: Int64(9_600 * factor),
                        apiEquivalentCostUSD: 0.825 * factor
                    )
                )
            }
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
                    DashboardCardStack(snapshot: snapshot)
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
        .frame(width: debugPanelSnapshotWidth)
        .foregroundStyle(Color.meterPrimary)
        .meterTypography()
    }

    private var header: some View {
        HStack(spacing: 11) {
            CodexIconView(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Codex Meter")
                        .meterText(.title)
                    if let plan = store.snapshot?.account?.displayPlan {
                        Text(plan.uppercased())
                            .meterText(.detail)
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
                            .font(.meter(size: 8.5))
                    }
                    .meterText(.detail)
                    .foregroundStyle(Color.meterSecondary)
                }
            }
            Spacer()
            Image(systemName: "arrow.clockwise")
                .font(.meter(size: 13))
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
            appearance: .light,
            language: .simplifiedChinese,
            filename: "/tmp/CodexMeter-preview-zh-Hans-light-plain.png",
            includeBackgroundImages: false
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
        filename: String,
        includeBackgroundImages: Bool = true
    ) {
        settings.appearance = appearance
        settings.language = language
        let colorScheme: ColorScheme = appearance == .dark ? .dark : .light
        let previewBackgrounds = makeDebugBackgroundStore(
            includeImages: includeBackgroundImages
        )
        // Let the full card stack choose its height so snapshot constraints do
        // not shrink text. Hosting also captures the horizontal month scroller.
        let hosting = NSHostingView(
            rootView: DebugMeterPanelSnapshotView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(previewBackgrounds)
                .environment(\.colorScheme, colorScheme)
        )
        hosting.setFrameSize(NSSize(
            width: debugPanelSnapshotWidth,
            height: hosting.fittingSize.height
        ))
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        defer { window.contentView = nil }
        hosting.layoutSubtreeIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }

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
            Image(nsImage: MenuBarProgressRingImage.make(
                remainingPercent: 81,
                size: 18,
                colorScheme: colorScheme
            ))
            .renderingMode(.original)
            Text("81%")
                .font(.meter(size: 16))
        }
        .padding(.horizontal, 10)
        .frame(width: 96, height: 32, alignment: .leading)
        .background(background)
        .environment(\.colorScheme, colorScheme)
    }
}
#endif
