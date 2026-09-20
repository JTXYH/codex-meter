import AppKit
import SwiftUI

struct HeroUsageCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var quotaBackgrounds: QuotaBackgroundStore

    let snapshot: CodexUsageSnapshot

    private var primaryWindow: RateLimitWindow? { snapshot.quotaCardPrimaryWindow }
    private var secondaryWindow: RateLimitWindow? { snapshot.quotaCardSecondaryWindow }

    var body: some View {
        if let primaryWindow,
           let backgroundImage = quotaBackgrounds.selectedImage(
               for: primaryWindow.remainingPercent
           ) {
            BackgroundQuotaUsageCard(
                window: primaryWindow,
                weeklyWindow: secondaryWindow,
                backgroundImage: backgroundImage
            )
        } else {
            if let primaryWindow {
                PlainQuotaUsageCard(
                    window: primaryWindow,
                    weeklyWindow: secondaryWindow
                )
            } else {
                PanelCard {
                    HStack(spacing: 12) {
                        Image(systemName: "gauge.with.dots.needle.0percent")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.meterSecondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.text(.noQuotaWindow, language: settings.language))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text(L10n.text(.noQuotaExplanation, language: settings.language))
                                .font(.system(size: 10.5, design: .rounded))
                                .foregroundStyle(Color.meterSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private enum QuotaVisualState {
    case available
    case low
    case exhausted

    init(remainingPercent: Double) {
        if remainingPercent <= 0 {
            self = .exhausted
        } else if remainingPercent < 30 {
            self = .low
        } else {
            self = .available
        }
    }

    var color: Color {
        switch self {
        case .available: .meterAccent
        case .low: .orange
        case .exhausted: .meterTertiary
        }
    }

    var statusDotColor: Color {
        switch self {
        case .available: .meterSuccess
        case .low: .orange
        case .exhausted: .meterTertiary
        }
    }

    var ringColors: [Color] {
        switch self {
        case .available:
            [.meterCyan, .meterAccent, .meterAccentSoft, .meterCyan]
        case .low:
            [.orange.opacity(0.72), .orange, .orange.opacity(0.86)]
        case .exhausted:
            [.meterTertiary]
        }
    }
}

private struct PlainQuotaUsageCard: View {
    @EnvironmentObject private var settings: AppSettings

    let window: RateLimitWindow
    let weeklyWindow: RateLimitWindow?

    private var visualState: QuotaVisualState {
        QuotaVisualState(remainingPercent: window.remainingPercent)
    }

    var body: some View {
        PanelCard {
            HStack(spacing: 18) {
                ProgressRing(
                    remainingPercent: window.remainingPercent,
                    subtitle: MeterFormatters.quotaStatus(
                        remainingPercent: window.remainingPercent,
                        language: settings.language
                    ),
                    colors: visualState.ringColors
                )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.text(.currentPeriod, language: settings.language))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.meterSecondary)
                            Text(MeterFormatters.quotaTitle(
                                for: window,
                                language: settings.language
                            ))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }
                        Spacer(minLength: 4)
                        StatusDot(color: visualState.statusDotColor)
                            .padding(.top, 3)
                    }

                    QuotaWindowMeter(
                        window: window,
                        label: L10n.text(.remainingQuota, language: settings.language),
                        color: visualState.color,
                        emphasized: true
                    )
                    .padding(.top, 9)

                    if let weeklyWindow {
                        WeeklyQuotaInline(window: weeklyWindow)
                            .padding(.top, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
        }
    }
}

private struct QuotaWindowMeter: View {
    @EnvironmentObject private var settings: AppSettings

    let window: RateLimitWindow
    let label: String
    let color: Color
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.system(
                        size: emphasized ? 10 : 10.5,
                        weight: emphasized ? .regular : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 4)
                Text("\(Int(window.remainingPercent.rounded()))%")
                    .font(.system(
                        size: emphasized ? 18 : 13,
                        weight: .bold,
                        design: .rounded
                    ))
                    .monospacedDigit()
            }

            MeterProgressBar(
                progress: window.remainingPercent / 100,
                color: color,
                height: emphasized ? 6 : 4
            )

            if let resetDescription = MeterFormatters.quotaResetDescription(
                for: window,
                language: settings.language
            ) {
                Text(resetDescription)
                    .font(.system(
                        size: emphasized ? 10.2 : 9.6,
                        weight: .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
    }

}

private struct WeeklyQuotaInline: View {
    @EnvironmentObject private var settings: AppSettings

    let window: RateLimitWindow
    var compact = false

    var body: some View {
        Group {
            if let resetDescription = MeterFormatters.quotaResetDescription(
                for: window,
                language: settings.language
            ) {
                labelText
                    + Text(" \(Int(window.remainingPercent.rounded()))%")
                        .font(.system(
                            size: compact ? 8.8 : 10.5,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.meterPrimary)
                    + Text(" · \(resetDescription)")
                        .font(.system(
                            size: compact ? 8.1 : 9.5,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundColor(.meterSecondary)
            } else {
                labelText
                    + Text(" \(Int(window.remainingPercent.rounded()))%")
                        .font(.system(
                            size: compact ? 8.8 : 10.5,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundColor(.meterPrimary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(compact ? 0.62 : 0.68)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private var labelText: Text {
        Text(MeterFormatters.weeklyRemainingLabel(language: settings.language))
            .font(.system(
                size: compact ? 8.4 : 9.8,
                weight: .medium,
                design: .rounded
            ))
            .foregroundColor(.meterSecondary)
    }
}

struct BackgroundQuotaUsageCard: View {
    @EnvironmentObject private var settings: AppSettings

    let window: RateLimitWindow
    let weeklyWindow: RateLimitWindow?
    let backgroundImage: NSImage

    private let designSize = CGSize(width: 392.5, height: 157)

    init(
        window: RateLimitWindow,
        weeklyWindow: RateLimitWindow? = nil,
        backgroundImage: NSImage
    ) {
        self.window = window
        self.weeklyWindow = weeklyWindow
        self.backgroundImage = backgroundImage
    }

    static func previewWindow(
        remainingPercent: Double = 99,
        now: Date = Date()
    ) -> RateLimitWindow {
        let clampedRemainingPercent = min(max(remainingPercent, 0), 100)
        return RateLimitWindow(
            id: "preview",
            bucketID: "preview",
            bucketName: "Codex",
            kind: .primary,
            usedPercent: 100 - clampedRemainingPercent,
            windowDurationMinutes: 300,
            resetsAt: Calendar.current.date(
                byAdding: .hour,
                value: 3,
                to: now
            )
        )
    }

    static func previewWeeklyWindow(
        remainingPercent: Double = 64,
        now: Date = Date()
    ) -> RateLimitWindow {
        let clampedRemainingPercent = min(max(remainingPercent, 0), 100)
        return RateLimitWindow(
            id: "preview-weekly",
            bucketID: "preview",
            bucketName: "Codex",
            kind: .secondary,
            usedPercent: 100 - clampedRemainingPercent,
            windowDurationMinutes: 10_080,
            resetsAt: Calendar.current.date(byAdding: .day, value: 5, to: now)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / designSize.width,
                geometry.size.height / designSize.height
            )

            cardCanvas
                .frame(width: designSize.width, height: designSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
        }
        .aspectRatio(
            QuotaBackgroundImageProcessor.cardAspectRatio,
            contentMode: .fit
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            L10n.remaining(
                Int(window.remainingPercent.rounded()),
                language: settings.language
            )
        )
    }

    private var cardCanvas: some View {
        ZStack(alignment: .leading) {
            Image(nsImage: backgroundImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: designSize.width, height: designSize.height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color.meterCard, location: 0),
                    .init(color: Color.meterCard.opacity(0.98), location: 0.34),
                    .init(color: Color.meterCard.opacity(0.82), location: 0.52),
                    .init(color: Color.meterCard.opacity(0.16), location: 0.74),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.text(.currentPeriod, language: settings.language))
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)

                Text(MeterFormatters.quotaTitle(for: window, language: settings.language))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 1)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(window.remainingPercent.rounded()))")
                        .font(.system(
                            size: weeklyWindow == nil ? 40 : 34,
                            weight: .bold,
                            design: .rounded
                        ))
                    Text("%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundStyle(primaryVisualState.color)
                .monospacedDigit()
                .padding(.top, 1)

                Text(MeterFormatters.quotaStatus(
                    remainingPercent: window.remainingPercent,
                    language: settings.language
                ))
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)

                MeterProgressBar(
                    progress: window.remainingPercent / 100,
                    color: primaryVisualState.color,
                    height: 5
                )
                .frame(width: 145)
                .padding(.top, 4)

                if let resetDescription = MeterFormatters.quotaResetDescription(
                    for: window,
                    language: settings.language
                ) {
                    Text(resetDescription)
                        .font(.system(size: 9.2, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                        .padding(.top, 5)
                }

                if let weeklyWindow {
                    WeeklyQuotaInline(window: weeklyWindow, compact: true)
                        .frame(width: 145, alignment: .leading)
                        .padding(.top, 7)
                }
            }
            .frame(width: 158, alignment: .leading)
            .padding(.horizontal, 17)
            .padding(.vertical, 9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.meterBorder, lineWidth: 1)
        }
        .shadow(color: Color.meterShadow, radius: 12, y: 3)
    }

    private var primaryVisualState: QuotaVisualState {
        QuotaVisualState(remainingPercent: window.remainingPercent)
    }

}

struct TokenActivityCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot

    var body: some View {
        let calendar = Calendar.current
        let today = Date()
        let effectiveSnapshot = snapshot.replacingTokenUsage(
            on: today,
            with: store.localTodayTokens,
            calendar: calendar
        )
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            .map { effectiveSnapshot.tokens(on: $0, calendar: calendar) } ?? 0
        let week = effectiveSnapshot.tokensInLastDays(
            7,
            endingAt: today,
            calendar: calendar
        )

        PanelCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center) {
                    TokenActivitySectionTitle(
                        title: L10n.text(.todayDetails, language: settings.language)
                    )
                    Spacer()
                    Text(L10n.text(.statisticsCurrent, language: settings.language))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                }

                TodayTokenDetails(usage: store.localTodayUsage)

                HStack(alignment: .center) {
                    TokenActivitySectionTitle(
                        title: L10n.text(.activityOverview, language: settings.language)
                    )
                    Spacer()
                }

                HStack(spacing: 9) {
                    ActivityOverviewTile(
                        label: L10n.text(.yesterday, language: settings.language),
                        value: MeterFormatters.tokens(yesterday, language: settings.language)
                    )
                    ActivityOverviewTile(
                        label: L10n.text(.lastSevenDays, language: settings.language),
                        value: MeterFormatters.tokens(week, language: settings.language)
                    )
                }
            }
        }
    }
}

private struct TokenActivitySectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.meterAccent)
                .frame(width: 6, height: 6)
                .padding(4)
                .background(Color.meterAccent.opacity(0.10), in: Circle())
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }
}

private struct TodayTokenDetails: View {
    @EnvironmentObject private var settings: AppSettings

    let usage: LocalTokenUsage

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TodayTokenDetailMetric(
                    icon: "arrow.down",
                    label: L10n.text(.inputTokens, language: settings.language),
                    value: MeterFormatters.tokens(
                        usage.inputTokens,
                        language: settings.language
                    )
                )

                TodayTokenDetailMetric(
                    icon: "arrow.up",
                    label: L10n.text(.outputTokens, language: settings.language),
                    value: MeterFormatters.tokens(
                        usage.outputTokens,
                        language: settings.language
                    )
                )

                TodayTokenDetailMetric(
                    icon: "dollarsign",
                    label: L10n.text(.apiEquivalentCost, language: settings.language),
                    value: MeterFormatters.usd(usage.apiEquivalentCostUSD)
                )
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.meterAccent)
                    .frame(width: 6, height: 6)
                Text(L10n.text(.cachedInput, language: settings.language))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Text(MeterFormatters.tokens(
                    usage.cachedInputTokens,
                    language: settings.language
                ))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text(L10n.hitRate(
                    Int((usage.cacheHitPercentage * 100).rounded()),
                    language: settings.language
                ))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.meterAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.meterCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.meterAccent.opacity(0.18), lineWidth: 1)
                    }
            )
        }
    }
}

private struct TodayTokenDetailMetric: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Color.meterAccent)
                    .frame(width: 18, height: 18)
                    .background(Color.meterAccent.opacity(0.09), in: RoundedRectangle(
                        cornerRadius: 6,
                        style: .continuous
                    ))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
            }

            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.meterCard)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.meterAccent.opacity(0.18), lineWidth: 1)
                }
        )
    }
}

private struct ActivityOverviewTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.meterCard)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.meterAccent.opacity(0.18), lineWidth: 1)
                }
        )
    }
}

struct UsageHeatmapCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    private static let dayCount = 120

    let snapshot: CodexUsageSnapshot
    @State private var hoveredDay: HeatmapDay? = nil

    var body: some View {
        let effectiveSnapshot = snapshot.replacingTokenUsage(
            on: Date(),
            with: store.localTodayTokens
        )
        let columns = HeatmapBuilder.columns(
            from: effectiveSnapshot.dailyUsage,
            dayCount: Self.dayCount
        )
        let total = effectiveSnapshot.tokensInLastDays(Self.dayCount)

        PanelCard {
            VStack(spacing: 13) {
                SectionTitle(
                    icon: "calendar",
                    title: L10n.text(.lastOneHundredTwentyDays, language: settings.language),
                    trailing: streakText
                )

                HStack(spacing: 5) {
                    Image(systemName: hoveredDay == nil ? "cursorarrow" : "calendar.badge.clock")
                    Text(hoverDetailText)
                        .contentTransition(.numericText())
                    Spacer()
                }
                .font(.system(size: 9.5, weight: .regular, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .frame(height: 14)

                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 5) {
                        ForEach(Array(L10n.weekdaySymbols(language: settings.language).enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: 8.5, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.meterSecondary)
                                .frame(width: 12, height: 14)
                        }
                    }

                    HStack(spacing: 0) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, column in
                            VStack(spacing: 5) {
                                ForEach(Array(column.enumerated()), id: \.offset) { _, day in
                                    HeatmapCell(day: day) { hoveringDay in
                                        withAnimation(.easeOut(duration: 0.12)) {
                                            hoveredDay = hoveringDay
                                        }
                                    }
                                }
                            }

                            if columnIndex < columns.count - 1 {
                                Spacer(minLength: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Text(
                        L10n.totalTokens(
                            MeterFormatters.tokens(total, language: settings.language),
                            language: settings.language
                        )
                    )
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    Spacer()
                    Text(L10n.text(.less, language: settings.language))
                    ForEach(HeatmapLevel.activeLevels, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(level.color)
                            .frame(width: 10, height: 10)
                    }
                    Text(L10n.text(.more, language: settings.language))
                }
                .font(.system(size: 8.5, weight: .regular, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
            }
        }
    }

    private var streakText: String {
        guard let days = snapshot.usageSummary?.currentStreakDays else {
            return L10n.text(.streakUnavailable, language: settings.language)
        }
        return L10n.streak(days, language: settings.language)
    }

    private var hoverDetailText: String {
        guard let hoveredDay else {
            return L10n.text(.hoverHeatmap, language: settings.language)
        }
        let day = MeterFormatters.day(hoveredDay.date, language: settings.language)
        let tokens = MeterFormatters.tokens(hoveredDay.tokens, language: settings.language)
        return "\(day) / \(tokens) Token"
    }
}

private extension HeatmapLevel {
    var color: Color {
        switch self {
        case .none: Color.meterTrack
        case .low: Color.meterAccent.opacity(0.22)
        case .medium: Color.meterAccent.opacity(0.46)
        case .high: Color.meterAccent.opacity(0.72)
        case .peak: Color.meterAccent
        }
    }
}

private struct HeatmapCell: View {
    let day: HeatmapDay?
    let onHoverDay: (HeatmapDay?) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(fillColor)
            .frame(width: 14, height: 14)
            .overlay {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(Color.meterBorder, lineWidth: 0.5)
            }
            .onHover { hovering in
                guard let day else { return }
                onHoverDay(hovering ? day : nil)
            }
    }

    private var fillColor: Color {
        (day?.level ?? .none).color
    }

}

struct UsageSummaryCard: View {
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot

    var body: some View {
        let summary = snapshot.usageSummary
        PanelCard {
            VStack(spacing: 13) {
                SectionTitle(
                    icon: "chart.bar.xaxis",
                    title: L10n.text(.usageOverview, language: settings.language),
                    trailing: fetchedText
                )
                HStack(spacing: 8) {
                    SummaryMetric(
                        title: L10n.text(.lifetimeTokens, language: settings.language),
                        value: MeterFormatters.tokens(
                            summary?.lifetimeTokens,
                            language: settings.language
                        )
                    )
                    SummaryMetric(
                        title: L10n.text(.longestStreak, language: settings.language),
                        value: L10n.longestStreakValue(
                            summary?.longestStreakDays,
                            language: settings.language
                        )
                    )
                    SummaryMetric(
                        title: L10n.text(.longestTask, language: settings.language),
                        value: MeterFormatters.elapsed(
                            seconds: summary?.longestRunningTurnSeconds,
                            language: settings.language
                        )
                    )
                }
            }
        }
    }

    private var fetchedText: String {
        L10n.updatedAt(snapshot.fetchedAt, language: settings.language)
    }
}

struct CreditsBalanceCard: View {
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot

    var body: some View {
        let balance = snapshot.creditsBalance
        let value = MeterFormatters.credits(balance, language: settings.language)

        PanelCard(borderColor: Color.meterAccent.opacity(0.18)) {
            HStack(spacing: 9) {
                Image(systemName: "creditcard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.meterAccent)
                    .frame(width: 20, height: 40)

                Text(L10n.text(.creditsBalance, language: settings.language))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 12)

                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        balance == .unavailable ? Color.meterSecondary : Color.meterAccent
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .help(value)
            }
        }
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.meterCard)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.meterAccent.opacity(0.18), lineWidth: 1)
                }
        )
    }
}
