import SwiftUI

struct HeroUsageCard: View {
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot

    private var window: RateLimitWindow? { snapshot.featuredWindow }

    var body: some View {
        PanelCard {
            if let window {
                HStack(spacing: 18) {
                    ProgressRing(
                        remainingPercent: window.remainingPercent,
                        subtitle: L10n.text(.remainingQuota, language: settings.language)
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.text(.currentPeriod, language: settings.language))
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.meterSecondary)
                                Text(MeterFormatters.quotaTitle(for: window, language: settings.language))
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                            Spacer()
                            StatusDot(color: window.remainingPercent <= 10 ? .orange : .meterSuccess)
                        }

                        HStack(alignment: .firstTextBaseline) {
                            Text(L10n.text(.remainingQuota, language: settings.language))
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.meterSecondary)
                            Text("\(Int(window.remainingPercent.rounded()))%")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .monospacedDigit()
                        }

                        MeterProgressBar(
                            progress: window.remainingPercent / 100,
                            color: window.remainingPercent <= 10 ? .orange : .meterAccent
                        )

                        if let resetsAt = window.resetsAt {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    MeterFormatters.resetCountdown(
                                        to: resetsAt,
                                        language: settings.language
                                    )
                                )
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                Text(MeterFormatters.resetDate(resetsAt, language: settings.language))
                                    .font(.system(size: 9.5, design: .rounded))
                                    .foregroundStyle(Color.meterSecondary)
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.0percent")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.meterSecondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text(.noQuotaWindow, language: settings.language))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
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

struct TokenActivityCard: View {
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot

    var body: some View {
        let now = Date()
        let todayUsage = snapshot.tokenUsage(on: now)
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: now)
        let yesterdayUsage = yesterdayDate.flatMap { snapshot.tokenUsage(on: $0) }
        let recentUsage = todayUsage ?? yesterdayUsage
        let recentLabel = L10n.text(
            todayUsage == nil && yesterdayUsage != nil ? .yesterday : .today,
            language: settings.language
        )
        let week = snapshot.tokensInLastDays(7)
        let peak = max(snapshot.usageSummary?.peakDailyTokens ?? 0, 1)

        PanelCard {
            VStack(spacing: 14) {
                SectionTitle(
                    icon: "waveform.path.ecg",
                    title: L10n.text(.tokenActivity, language: settings.language),
                    trailing: L10n.text(.peakBaseline, language: settings.language)
                )
                TokenMetricRow(
                    label: recentLabel,
                    value: MeterFormatters.tokens(
                        recentUsage?.tokens ?? 0,
                        language: settings.language
                    ),
                    progress: Double(recentUsage?.tokens ?? 0) / Double(peak)
                )
                TokenMetricRow(
                    label: L10n.text(.lastSevenDays, language: settings.language),
                    value: MeterFormatters.tokens(week, language: settings.language),
                    progress: Double(week) / (Double(peak) * 7)
                )
            }
        }
    }
}

private struct TokenMetricRow: View {
    let label: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(width: 72, alignment: .leading)
                Text(value)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text("\(Int(min(max(progress, 0), 1) * 100))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
                    .monospacedDigit()
            }
            MeterProgressBar(progress: progress, color: .meterCyan, height: 6)
        }
    }
}

struct UsageHeatmapCard: View {
    @EnvironmentObject private var settings: AppSettings

    let snapshot: CodexUsageSnapshot
    @State private var hoveredDay: HeatmapDay? = nil

    var body: some View {
        let columns = HeatmapBuilder.columns(from: snapshot.dailyUsage)
        let total = snapshot.tokensInLastDays(90)

        PanelCard {
            VStack(spacing: 13) {
                SectionTitle(
                    icon: "calendar",
                    title: L10n.text(.lastNinetyDays, language: settings.language),
                    trailing: streakText
                )

                HStack(spacing: 5) {
                    Image(systemName: hoveredDay == nil ? "cursorarrow" : "calendar.badge.clock")
                    Text(hoverDetailText)
                        .contentTransition(.numericText())
                    Spacer()
                }
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .frame(height: 14)

                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 5) {
                        ForEach(Array(L10n.weekdaySymbols(language: settings.language).enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.meterSecondary)
                                .frame(width: 12, height: 14)
                        }
                    }

                    HStack(spacing: 4) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: 5) {
                                ForEach(Array(column.enumerated()), id: \.offset) { _, day in
                                    HeatmapCell(day: day) { hoveringDay in
                                        withAnimation(.easeOut(duration: 0.12)) {
                                            hoveredDay = hoveringDay
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                HStack {
                    Text(
                        L10n.totalTokens(
                            MeterFormatters.tokens(total, language: settings.language),
                            language: settings.language
                        )
                    )
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    Spacer()
                    Text(L10n.text(.less, language: settings.language))
                    ForEach(0..<4) { level in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.meterAccent.opacity(0.16 + Double(level) * 0.25))
                            .frame(width: 10, height: 10)
                    }
                    Text(L10n.text(.more, language: settings.language))
                }
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
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

private struct HeatmapCell: View {
    let day: HeatmapDay?
    let onHoverDay: (HeatmapDay?) -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(fillColor)
            .frame(width: 14, height: 14)
            .overlay {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .stroke(day == nil ? Color.clear : Color.meterBorder, lineWidth: 0.5)
            }
            .onHover { hovering in
                guard let day else { return }
                onHoverDay(hovering ? day : nil)
            }
    }

    private var fillColor: Color {
        guard let day else { return .clear }
        guard day.tokens > 0 else { return Color.meterTrack }
        return Color.meterAccent.opacity(0.2 + day.intensity * 0.8)
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

private struct SummaryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
