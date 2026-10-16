import SwiftUI

struct HeroUsageCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.meterFontSizes) private var fontSizes
    let snapshot: CodexUsageSnapshot

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                PanelCardHeading(title: RedesignL10n.text(.currentQuota, language: settings.language),
                                 trailing: snapshot.quotaCardPrimaryWindow.map { RedesignL10n.window($0, language: settings.language) })
                    .padding(.bottom, theme.isInstrument ? 13 : 12)
                if let window = snapshot.quotaCardPrimaryWindow {
                    if theme.isInstrument { linearQuota(window) }
                    else { circularQuota(window) }
                    if let weekly = snapshot.quotaCardSecondaryWindow {
                        weeklyStrip(weekly)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "circle.dotted").font(.system(size: 25)).foregroundStyle(Color.meterTertiary)
                        Text(L10n.text(.noQuotaWindow, language: settings.language)).meterText(.title, size: 12, weight: .medium)
                        Text(L10n.text(.noQuotaExplanation, language: settings.language)).meterText(.detail, size: 11)
                            .foregroundStyle(Color.meterSecondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).frame(minHeight: 160)
                }
            }
            .padding(.bottom, -theme.cardPadding)
        }
        .accessibilityIdentifier("quota-card")
    }

    private func circularQuota(_ window: RateLimitWindow) -> some View {
        HStack(spacing: 24) {
            ZStack {
                Circle().stroke(theme.accentSoft, lineWidth: 5.6)
                Circle().trim(from: 0, to: min(1, max(0, window.remainingPercent / 100)))
                    .stroke(window.remainingPercent < 30 ? Color.meterDanger : theme.accent,
                            style: StrokeStyle(lineWidth: 5.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(Int(window.remainingPercent.rounded())))
                        .meterText(.value, size: 36, weight: .medium).tracking(-1.8)
                    Text("%").meterText(.detail, size: 13)
                }.foregroundStyle(window.remainingPercent < 30 ? Color.meterDanger : theme.accent)
            }.frame(width: 97.1, height: 97.1).frame(width: 112, height: 112)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.remaining(Int(window.remainingPercent.rounded()), language: settings.language))
            VStack(alignment: .leading, spacing: 0) {
                label(L10n.text(.remainingQuota, language: settings.language)).padding(.bottom, 7)
                Text(status(window)).meterText(.title, size: 16, weight: .medium)
                    .lineLimit(1).minimumScaleFactor(0.7).frame(minHeight: 24)
                    .help(status(window))
                HStack(spacing: 5) {
                    Circle().fill(Color.meterSuccess).frame(width: 5, height: 5)
                    Text(RedesignL10n.reset(window.resetsAt, language: settings.language))
                        .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }.frame(minHeight: 15).padding(.top, 10)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.horizontal, 4).padding(.bottom, 18)
    }

    private func linearQuota(_ window: RateLimitWindow) -> some View {
        let reset = QuotaResetReadout(date: window.resetsAt, language: settings.language)
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    label(L10n.text(.remainingQuota, language: settings.language))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(Int(window.remainingPercent.rounded()))).meterText(.value, size: 43).tracking(-2).frame(minHeight: 58.5)
                        Text("%").meterText(.detail, size: 17)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    label(RedesignL10n.text(.resetTime, language: settings.language))
                    Text(reset.primary).meterText(.value, size: 23).frame(minHeight: 34.5)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .accessibilityIdentifier("quota-reset-primary")
                    Text(reset.secondary).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityIdentifier("quota-reset-secondary")
                }.frame(maxWidth: 180, alignment: .trailing)
            }.offset(y: -5.5).padding(.top, 6).padding(.bottom, 14)
            GeometryReader { geometry in
                Rectangle().fill(Color.meterPanel)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(theme.accent).frame(width: geometry.size.width * min(1, max(0, window.remainingPercent / 100)))
                    }
            }.frame(height: 8).clipShape(RoundedRectangle(cornerRadius: 2)).padding(.bottom, 17)
        }
    }

    private func weeklyStrip(_ window: RateLimitWindow) -> some View {
        VStack(spacing: 0) {
            PanelRule()
            HStack(spacing: 12) {
                Text(RedesignL10n.text(.weeklyRemaining, language: settings.language)).meterText(.title, size: 11)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(Int(window.remainingPercent.rounded()))).font(.system(size: 17 * CGFloat(fontSizes.value / 16), weight: .semibold))
                    Text("%").meterText(.detail, size: 10)
                }
                Text(RedesignL10n.reset(window.resetsAt, language: settings.language, includeTime: false))
                    .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7).padding(.leading, 4)
            }.frame(minHeight: 25.5).padding(.vertical, 13)
        }
    }

    private func label(_ value: String) -> some View {
        Text(value).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary).frame(minHeight: 15)
    }
    private func status(_ window: RateLimitWindow) -> String {
        settings.quotaStatusMessages.text(for: QuotaStatus(remainingPercent: window.remainingPercent), language: settings.language)
    }
}

struct TokenActivityCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.meterFontSizes) private var fontSizes
    @State private var modelsExpanded = true
    private var usage: LocalTokenUsage? { store.hasLoadedLocalTodayUsage ? store.localTodayUsage : nil }
    var body: some View {
        let rows = store.modelUsage(.day, containing: Date())
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L10n.text(.todayDetails, language: settings.language)).meterText(.title, size: 13, weight: .semibold)
                        UsageDayIndicator(date: Date())
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.meterSuccess).frame(width: 5, height: 5)
                        Text(RedesignL10n.text(.localLive, language: settings.language)).meterText(.detail, size: 9)
                            .foregroundStyle(Color.meterSecondary)
                    }
                }.frame(minHeight: 19.5).padding(.bottom, theme.isInstrument ? 13 : 17)
                VStack(alignment: .leading, spacing: 8) {
                    detailLabel(RedesignL10n.text(.todayTokens, language: settings.language))
                    PanelTokenNumber(value: usage?.totalTokens, size: theme.isInstrument ? 25 : 28, unitSize: 17, spacing: 3)
                        .frame(minHeight: theme.isInstrument ? 32 : 35)
                }.padding(.bottom, 16)
                PanelRule()
                GeometryReader { geometry in
                    let width = (geometry.size.width - 16) / 3
                    HStack(alignment: .top, spacing: 8) {
                        tokenDetail(.input, value: usage?.inputTokens).frame(width: width)
                        tokenDetail(.output, value: usage?.outputTokens)
                            .padding(.leading, 13).frame(width: width)
                            .overlay(alignment: .leading) { Rectangle().fill(Color.meterBorder).frame(width: 1) }
                        tokenDetail(.cached, value: usage?.cachedInputTokens)
                            .padding(.leading, 13).frame(width: width)
                            .overlay(alignment: .leading) { Rectangle().fill(Color.meterBorder).frame(width: 1) }
                    }
                }.frame(height: 15 * CGFloat(fontSizes.detail / 10) + 5 + 19.5 * CGFloat(fontSizes.value / 16)).padding(.vertical, 12)
                PanelRule()
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { modelsExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(RedesignL10n.text(.modelDetails, language: settings.language))
                        Text(String(rows.count)).foregroundStyle(Color.meterTertiary)
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 9))
                            .rotationEffect(.degrees(modelsExpanded ? 180 : 0))
                    }.meterText(.title, size: 11).frame(minHeight: 16.5).padding(.top, 13).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("today-model-disclosure")
                    .accessibilityValue(modelsExpanded ? "expanded" : "collapsed")
                if modelsExpanded {
                    ModelUsageRows(rows: rows, isLoaded: store.hasLoadedLocalTodayUsage).padding(.top, 6)
                        .transition(reduceMotion ? .identity : .opacity.combined(with: .offset(y: -3)))
                }
            }
        }.accessibilityIdentifier("today-card")
    }
    private func detailLabel(_ value: String) -> some View {
        Text(value).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary).frame(minHeight: 15)
    }
    private func tokenDetail(_ key: RedesignL10n.Key, value: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            detailLabel(RedesignL10n.text(key, language: settings.language))
            Text(PanelTokenAmount(value, language: settings.language).text)
                .meterText(.value, size: 13, weight: .semibold).lineLimit(1).minimumScaleFactor(0.7).frame(minHeight: 19.5)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityOverviewCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.meterFontSizes) private var fontSizes
    let snapshot: CodexUsageSnapshot

    var body: some View {
        let now = Date()
        let yesterday = UsageCalendar.calendar.date(byAdding: .day, value: -1, to: now)
            .flatMap { snapshot.tokenUsage(on: $0)?.tokens }
        let recent = store.periodUsage(.day, count: 7, at: now)
        let week = recent.contains(where: { $0.tokens != nil }) ? snapshot.tokensInLastDays(7, endingAt: now) : nil
        let month = store.currentMonthTokens
        PanelCard {
            VStack(alignment: .leading, spacing: theme.isInstrument ? 13 : 17) {
                PanelCardHeading(title: L10n.text(.activityOverview, language: settings.language))
                GeometryReader { geometry in
                    let width = (geometry.size.width - 30) / 3
                    HStack(alignment: .top, spacing: 15) {
                        overviewItem(RedesignL10n.text(.yesterdayTokens, language: settings.language), value: yesterday)
                            .frame(width: width)
                        overviewItem(L10n.text(.lastSevenDays, language: settings.language), value: week)
                            .padding(.leading, 16).frame(width: width)
                            .overlay(alignment: .leading) { Rectangle().fill(Color.meterBorder).frame(width: 1) }
                        overviewItem(RedesignL10n.text(.month, language: settings.language), value: month)
                            .padding(.leading, 16).frame(width: width)
                            .overlay(alignment: .leading) { Rectangle().fill(Color.meterBorder).frame(width: 1) }
                    }
                }.frame(height: 15 * CGFloat(fontSizes.detail / 10) + 7 + (theme.isInstrument ? 28.5 : 33) * CGFloat(fontSizes.value / 16))
            }
        }.accessibilityIdentifier("activity-overview-card")
    }
    private func overviewItem(_ title: String, value: Int64?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary).frame(minHeight: 15)
                .lineLimit(1).minimumScaleFactor(0.7)
            PanelTokenNumber(value: store.hasLoadedRemoteSnapshot ? value : nil, size: theme.isInstrument ? 19 : 22, unitSize: 12)
                .frame(minHeight: theme.isInstrument ? 28.5 : 33)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UsageHeatmapCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    let snapshot: CodexUsageSnapshot
    @State private var hoveredDay: HeatmapDay?
    private static let dayCount = 120
    private var total: Int64? {
        guard store.hasLoadedRemoteSnapshot, !snapshot.dailyUsage.isEmpty else { return nil }
        return snapshot.tokensInLastDays(Self.dayCount)
    }

    var body: some View {
        let columns = HeatmapBuilder.columns(from: snapshot.dailyUsage, dayCount: Self.dayCount)
        let months = months(for: columns)
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                PanelCardHeading(title: RedesignL10n.text(.heatmapTitle, language: settings.language),
                                 trailing: snapshot.usageSummary?.currentStreakDays.map { RedesignL10n.streak($0, language: settings.language) })
                    .padding(.bottom, theme.isInstrument ? 13 : 17)
                HStack {
                    ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                        Text(month).meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary).frame(minHeight: 13.5)
                        if index != months.count - 1 { Spacer(minLength: 0) }
                    }
                }.padding(.leading, 22).padding(.bottom, 8)
                HStack(spacing: 7) {
                    VStack(spacing: 0) {
                        ForEach(0..<7) { index in
                            Text(index % 2 == 0 ? L10n.weekdaySymbols(language: settings.language)[index] : "")
                                .meterText(.detail, size: 8).foregroundStyle(Color.meterTertiary)
                                .frame(width: 12, height: 12)
                            if index < 6 { Spacer(minLength: 4) }
                        }
                    }.frame(height: 108)
                    HStack(spacing: 4) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: 4) {
                                ForEach(Array(column.enumerated()), id: \.offset) { _, day in
                                    heatCell(day).frame(height: 12)
                                }
                            }.frame(maxWidth: .infinity)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Text(hoverDetail).meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    legend
                }.frame(minHeight: 38)
                PanelRule()
                HStack {
                    Text("120 \(RedesignL10n.text(.days, language: settings.language)) Token")
                        .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    Spacer()
                    Text(PanelTokenAmount(total, language: settings.language).text).meterText(.value, size: 15, weight: .semibold)
                }.frame(minHeight: 22.5).padding(.top, 12)
            }
        }.accessibilityIdentifier("heatmap-card")
    }

    private func months(for columns: [[HeatmapDay?]]) -> [String] {
        let dates = columns.compactMap { $0.compactMap { $0 }.first?.date }
        var seen = Set<Int>()
        return dates.compactMap { date in
            let month = UsageCalendar.calendar.component(.month, from: date)
            guard seen.insert(month).inserted else { return nil }
            if settings.language == .simplifiedChinese || settings.language == .traditionalChinese { return "\(month) 月" }
            return UsageDayL10n.date(date, template: "MMM", language: settings.language)
        }
    }
    private var hoverDetail: String {
        guard let day = hoveredDay else { return RedesignL10n.heatmapHint(settings.language) }
        let amount = snapshot.tokenUsage(on: day.date).map { PanelTokenAmount($0.tokens, language: settings.language).text + " Token" } ?? "—"
        return "\(UsageDayL10n.date(day.date, template: "Md", language: settings.language)) · \(amount)"
    }
    private var legend: some View {
        HStack(spacing: 3) {
            Text(L10n.text(.less, language: settings.language)).padding(.horizontal, 2)
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2).fill(color(index)).frame(width: 8, height: 8)
                    .overlay { if index == 0 { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.meterBorder, lineWidth: 1) } }
            }
            Text(L10n.text(.more, language: settings.language)).padding(.horizontal, 2)
        }.meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
    }
    private func heatCell(_ day: HeatmapDay?) -> some View {
        let missing = day == nil || snapshot.tokenUsage(on: day!.date) == nil
        return Button { hoveredDay = day } label: {
            ZStack {
                if missing {
                    Canvas { context, size in
                        var path = Path()
                        for x in stride(from: -size.height, through: size.width, by: 4) {
                            path.move(to: CGPoint(x: x, y: size.height))
                            path.addLine(to: CGPoint(x: x + size.height, y: 0))
                        }
                        context.stroke(path, with: .color(.meterBorder), lineWidth: 1)
                    }
                } else {
                    color(level(day?.level ?? .none))
                }
            }.clipShape(RoundedRectangle(cornerRadius: 2))
                .overlay { if !missing, day?.level == HeatmapLevel.none { RoundedRectangle(cornerRadius: 2).strokeBorder(Color.meterBorder, lineWidth: 1) } }
                .contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovering in if hovering { hoveredDay = day } }
            .help(day.map {
                "\(MeterFormatters.day($0.date, language: settings.language)) · \(missing ? "—" : PanelTokenAmount($0.tokens, language: settings.language).text) Token\n"
                    + UsageDayL10n.help(containing: $0.date, language: settings.language)
            } ?? "—")
            .accessibilityLabel(day.map { MeterFormatters.day($0.date, language: settings.language) } ?? "—")
            .accessibilityValue(missing ? "—" : String(day?.tokens ?? 0))
    }
    private func level(_ level: HeatmapLevel) -> Int {
        switch level { case .none: 0; case .low: 1; case .medium: 2; case .high: 3; case .peak: 4 }
    }
    private func color(_ level: Int) -> Color {
        if level == 0 { return .meterPanel }
        return theme.accent.opacity([0, 0.17, 0.37, 0.65, 1][level])
    }
}

struct UsageSummaryCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    let snapshot: CodexUsageSnapshot
    var body: some View {
        let summary = store.hasLoadedRemoteSnapshot ? snapshot.usageSummary : nil
        PanelCard {
            VStack(alignment: .leading, spacing: theme.isInstrument ? 13 : 17) {
                PanelCardHeading(title: RedesignL10n.text(.accountSummary, language: settings.language))
                Grid(alignment: .leading, horizontalSpacing: 21, verticalSpacing: 21) {
                    GridRow {
                        metric(L10n.text(.lifetimeTokens, language: settings.language)) {
                            PanelTokenNumber(value: summary?.lifetimeTokens, size: 23, unitSize: 11, spacing: 3)
                        }
                        metric(RedesignL10n.peakTitle(settings.language)) {
                            PanelTokenNumber(value: summary?.peakDailyTokens, size: 23, unitSize: 11, spacing: 3)
                        }
                    }
                    GridRow {
                        metric(L10n.text(.longestStreak, language: settings.language)) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(summary?.longestStreakDays.map { String($0) } ?? "—").meterText(.value, size: 23, weight: .medium)
                                if summary?.longestStreakDays != nil {
                                    Text(RedesignL10n.text(.days, language: settings.language)).meterText(.detail, size: 11)
                                }
                            }
                        }
                        metric(L10n.text(.longestTask, language: settings.language)) { duration(summary?.longestRunningTurnSeconds) }
                    }
                }
            }
        }.accessibilityIdentifier("summary-card")
    }
    private func metric<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary).frame(minHeight: 15)
                .lineLimit(1).minimumScaleFactor(0.7)
            content().frame(minHeight: 34.5).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private func duration(_ seconds: Int?) -> some View {
        if let seconds {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                if seconds >= 3600 {
                    Text(String(seconds / 3600)).meterText(.value, size: 23, weight: .medium)
                    Text(RedesignL10n.text(.hours, language: settings.language)).meterText(.detail, size: 11)
                }
                Text(String(seconds >= 3600 ? seconds / 60 % 60 : seconds > 0 ? max(1, seconds / 60) : 0)).meterText(.value, size: 23, weight: .medium)
                    .padding(.leading, seconds >= 3600 ? 4 : 0)
                Text(RedesignL10n.text(.minutes, language: settings.language)).meterText(.detail, size: 11)
            }
        } else { Text("—").meterText(.value, size: 23, weight: .medium) }
    }
}

struct CreditsBalanceCard: View {
    @EnvironmentObject private var settings: AppSettings
    let snapshot: CodexUsageSnapshot
    var body: some View {
        PanelCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(.creditsBalance, language: settings.language)).meterText(.title, size: 13, weight: .semibold).frame(minHeight: 19.5)
                    Text(RedesignL10n.text(.extraCredits, language: settings.language)).meterText(.detail, size: 10)
                        .foregroundStyle(Color.meterSecondary).frame(minHeight: 15)
                }
                Spacer(minLength: 0)
                Text(snapshot.creditsBalance == .unavailable ? "—" : MeterFormatters.credits(snapshot.creditsBalance, language: settings.language))
                    .meterText(.value, size: 23, weight: .medium).lineLimit(1).minimumScaleFactor(0.65)
            }.frame(minHeight: 38.5)
        }.accessibilityIdentifier("credits-card")
    }
}
