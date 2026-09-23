import SwiftUI

// The legacy section identifier and settings keys remain stable during migration.
struct MonthlyUsageCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedDates: [UsagePeriod: Date] = [:]
    @State private var isRangePopoverPresented = false
    @State private var rangeTriggerSize = CGSize(width: 80, height: 26)

    private var period: UsagePeriod { settings.usageStatisticsPeriod }
    private var range: Int { settings.usageStatisticsRange(for: period) }
    private var records: [PeriodTokenUsage] { store.periodUsage(period, count: range) }
    private var selected: PeriodTokenUsage? {
        records.first(where: { $0.start == selectedDates[period] }) ?? records.first
    }
    private var isLoaded: Bool { store.hasLoadedLocalLifetimeUsage && store.localLifetimeUsage != nil }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                heading
                periodControl.padding(.top, 16)
                dateTabs.padding(.top, 12)

                if let selected {
                    HStack(spacing: 7) {
                        Circle().fill(Color.meterAccent).frame(width: 5, height: 5)
                        Text(L10n.monthUsageTitle(label(selected), language: settings.language))
                            .meterText(.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 8)
                        Text(UsageStatisticsL10n.dateCaption(selected.start, period: period, language: settings.language))
                            .meterText(.detail)
                            .foregroundStyle(Color.meterTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.top, 20)

                    HStack(alignment: .top, spacing: 18) {
                        selectedMetric(title: "Token", value: formattedTokens(selected.usage))
                        selectedMetric(title: L10n.text(.apiEquivalentCost, language: settings.language),
                                       value: formattedCost(selected.usage))
                    }
                    .padding(.top, 15)

                    usageChart.padding(.top, 22)
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                        Text(isLoaded ? UsageStatisticsL10n.footer(selected, period: period, language: settings.language)
                             : L10n.text(.calculatingUsage, language: settings.language))
                            .lineLimit(2)
                    }
                    .meterText(.detail)
                    .foregroundStyle(Color.meterTertiary)
                    .padding(.top, 18)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isRangePopoverPresented {
                MonthlyRangePopover(selection: range, language: settings.language, period: period) { count in
                    settings.setUsageStatisticsRange(count, for: period)
                    isRangePopoverPresented = false
                }
                .background(MonthlyRangeDismissObserver(triggerSize: rangeTriggerSize) {
                    isRangePopoverPresented = false
                }.allowsHitTesting(false))
                .padding(.top, 49)
                .padding(.trailing, 16)
            }
        }
        .zIndex(isRangePopoverPresented ? 1 : 0)
        .onDisappear { isRangePopoverPresented = false }
        .onChange(of: period) { _, _ in isRangePopoverPresented = false }
        .onChange(of: records.map(\.start)) { _, dates in
            if let date = selectedDates[period], !dates.contains(date) { selectedDates[period] = nil }
        }
    }

    private var heading: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: period == .hour ? "clock" : "calendar")
                    .font(.meter(size: 13))
                    .foregroundStyle(Color.meterAccent)
                Text(L10n.text(.monthlyUsage, language: settings.language))
                    .meterText(.title)
            }
            Spacer(minLength: 8)
            Button { isRangePopoverPresented.toggle() } label: {
                HStack(spacing: 6) {
                    Text(UsageStatisticsL10n.range(range, period: period, language: settings.language))
                    Image(systemName: "chevron.down").font(.meter(size: 7))
                }
                .meterText(.detail)
                .foregroundStyle(isRangePopoverPresented ? Color.meterAccent : Color.meterSecondary)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(isRangePopoverPresented ? Color.meterAccent.opacity(0.10) : Color.meterControl,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { rangeTriggerSize = geometry.size }
                        .onChange(of: geometry.size) { _, size in rangeTriggerSize = size }
                }
            }
            .accessibilityLabel(L10n.text(.monthlyUsageRange, language: settings.language))
            .accessibilityValue(UsageStatisticsL10n.range(range, period: period, language: settings.language))
            .accessibilityIdentifier("monthly-range-button")
        }
    }

    private var periodControl: some View {
        HStack(spacing: 4) {
            ForEach(UsagePeriod.allCases) { option in
                Button { settings.usageStatisticsPeriod = option } label: {
                    Text(UsageStatisticsL10n.period(option, language: settings.language))
                        .meterText(.detail)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(period == option ? Color.meterAccent : Color.meterSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(period == option ? Color.meterCard : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .shadow(color: period == option ? Color.meterShadow : .clear, radius: 2, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(period == option ? .isSelected : [])
                .accessibilityIdentifier("usage-period-\(option.rawValue)")
            }
        }
        .padding(4)
        .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(UsageStatisticsL10n.text(.period, language: settings.language))
    }

    private var dateTabs: some View {
        let values = records
        let selectedDate = selectedDates[period] ?? values.first?.start
        return GeometryReader { geometry in
            let visibleCount = CGFloat(max(1, min(values.count, period == .day ? 7 : 6)))
            let tabWidth = (geometry.size.width - 3 * (visibleCount - 1)) / visibleCount
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(values) { record in
                            let isSelected = selectedDate == record.start
                            Button { select(record) } label: {
                                Text(label(record))
                                    .meterText(.detail)
                                    .foregroundStyle(isSelected ? Color.meterAccent : Color.meterSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                    .frame(width: tabWidth, height: 27)
                                    .background(isSelected ? Color.meterAccent.opacity(0.09) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                            .help(hoverDescription(record))
                            .id(record.start)
                        }
                    }
                }
                .onChange(of: selectedDate) { _, date in
                    if let date { proxy.scrollTo(date, anchor: .center) }
                }
                .onChange(of: period) { _, _ in
                    if let date = selectedDate { proxy.scrollTo(date, anchor: .center) }
                }
            }
        }
        .frame(height: 27)
    }

    private func selectedMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .meterText(.detail)
                .foregroundStyle(Color.meterSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .meterText(.value)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var usageChart: some View {
        let values = records
        let selectedDate = selectedDates[period] ?? values.first?.start
        let peak = values.compactMap { $0.usage?.totalTokens }.max() ?? 0
        return VStack(spacing: 16) {
            Rectangle().fill(Color.meterBorder).frame(height: 1)
            HStack(alignment: .bottom, spacing: values.count > 14 ? 3 : 8) {
                ForEach(values) { record in
                    let tokens = record.usage?.totalTokens ?? 0
                    let fraction = peak > 0 ? min(max(Double(tokens) / Double(peak), 0), 1) : 0
                    Button { select(record) } label: {
                        VStack(spacing: 7) {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                if record.usage == nil {
                                    RoundedRectangle(cornerRadius: 1)
                                        .stroke(Color.meterTertiary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                        .frame(height: 2)
                                } else {
                                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                                        .fill(Color.meterAccent.opacity(selectedDate == record.start ? 0.65 : 0.17))
                                        .frame(height: max(2, 65 * fraction))
                                }
                            }
                            .padding(.horizontal, values.count > 14 ? 1 : 5)
                            .frame(height: 65)
                            Text(values.count <= 7 ? label(record, compact: true) : " ")
                                .meterText(.detail)
                                .foregroundStyle(selectedDate == record.start ? Color.meterAccent : Color.meterTertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(UsageStatisticsL10n.dateCaption(record.start, period: period, language: settings.language))
                    .accessibilityValue("\(formattedTokens(record.usage)) Token · \(formattedCost(record.usage))")
                    .accessibilityAddTraits(selectedDate == record.start ? .isSelected : [])
                    .help(hoverDescription(record))
                }
            }
            .overlay(alignment: .bottom) {
                if values.count > 7 {
                    // Sparse axis labels span several bars so 24 hours remain readable.
                    GeometryReader { geometry in
                        let spacing: CGFloat = values.count > 14 ? 3 : 8
                        let barWidth = (geometry.size.width - spacing * CGFloat(values.count - 1)) / CGFloat(values.count)
                        ForEach(Array(values.enumerated()), id: \.element.id) { index, record in
                            if index == 0 || index == values.count - 1
                                || index.isMultiple(of: Int(ceil(Double(values.count) / 6))) {
                                let first = index == 0
                                let last = index == values.count - 1
                                Text(label(record, compact: true))
                                    .meterText(.detail)
                                    .foregroundStyle(selectedDate == record.start ? Color.meterAccent : Color.meterTertiary)
                                    .lineLimit(1)
                                    .frame(width: 60, alignment: first ? .leading : last ? .trailing : .center)
                                    .position(x: first ? 30 : last ? geometry.size.width - 30
                                              : (CGFloat(index) + 0.5) * barWidth + CGFloat(index) * spacing,
                                              y: geometry.size.height / 2)
                            }
                        }
                    }
                    .frame(height: 16)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func select(_ record: PeriodTokenUsage) {
        selectedDates[period] = record.start
        isRangePopoverPresented = false
    }

    private func label(_ record: PeriodTokenUsage, compact: Bool = false) -> String {
        UsageStatisticsL10n.label(record.start, period: period, language: settings.language, compact: compact)
    }

    private func hoverDescription(_ record: PeriodTokenUsage) -> String {
        let date = UsageStatisticsL10n.dateCaption(record.start, period: period, language: settings.language)
        return "\(date)\n\(formattedTokens(record.usage)) Token · \(formattedCost(record.usage))"
    }

    private func formattedTokens(_ usage: LocalTokenUsage?) -> String {
        guard isLoaded else { return L10n.text(.calculatingUsage, language: settings.language) }
        guard let usage else { return "—" }
        return MeterFormatters.tokens(usage.totalTokens, language: settings.language)
    }

    private func formattedCost(_ usage: LocalTokenUsage?) -> String {
        guard isLoaded else { return L10n.text(.calculatingUsage, language: settings.language) }
        return usage.map { MeterFormatters.usd($0.apiEquivalentCostUSD) }
            ?? "—"
    }
}
