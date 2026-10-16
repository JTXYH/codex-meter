import SwiftUI

// The persisted legacy identifier is retained so module order and font preferences migrate.
struct MonthlyUsageCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDates: [UsagePeriod: Date] = [:]
    @State private var selectionRevision = 0
    @State private var isRangePopoverPresented = false
    @State private var rangeTriggerSize = CGSize(width: 80, height: 23)
    private var period: UsagePeriod { settings.usageStatisticsPeriod }
    private var range: Int { settings.usageStatisticsRange(for: period) }
    var body: some View {
        let records = store.statisticsUsage(period, count: range)
        let selected = records.first(where: { $0.start == selectedDates[period] }) ?? records.first
        let selectionID = "\(period.rawValue)-\(selected?.start.timeIntervalSince1970 ?? 0)"
        let modelTaskID = "\(period.rawValue)-\(selected?.start.timeIntervalSince1970 ?? 0)-\(store.snapshot?.account?.usageIdentity ?? "")"
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                heading(for: selected?.start ?? Date()).padding(.bottom, theme.isInstrument ? 13 : 17)
                periodControl
                dateTabs(records).padding(.top, 11).padding(.bottom, 20)
                ZStack(alignment: .topLeading) {
                    historyContent(selected)
                        .id(selectionID)
                        .transition(reduceMotion ? .identity : .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 4)), removal: .opacity
                        ))
                }
                // Only user selections animate; refreshed values retain their view identity.
                .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: selectionRevision)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isRangePopoverPresented {
                MonthlyRangePopover(selection: range, language: settings.language, period: period) { count in
                    settings.setUsageStatisticsRange(count, for: period)
                    isRangePopoverPresented = false
                }
                .background(MonthlyRangeDismissObserver(triggerSize: rangeTriggerSize) { isRangePopoverPresented = false }.allowsHitTesting(false))
                .padding(.top, theme.cardPadding + 30).padding(.trailing, theme.cardPadding)
            }
        }
        .zIndex(isRangePopoverPresented ? 1 : 0)
        .accessibilityIdentifier("history-card")
        .onDisappear { isRangePopoverPresented = false }
        .onChange(of: period) { _, _ in isRangePopoverPresented = false }
        .onChange(of: records.map(\.start)) { _, dates in
            if let date = selectedDates[period], !dates.contains(date) { selectedDates[period] = nil }
        }
        .task(id: modelTaskID) {
            guard let selected else { return }
            await store.loadAccountModels(for: period, containing: selected.start)
        }
    }

    @ViewBuilder
    private func historyContent(_ selected: AccountPeriodUsage?) -> some View {
        if let selected {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(historyTitle(selected)).meterText(.title, size: 11).frame(minHeight: 16.5)
                        HStack(alignment: .firstTextBaseline, spacing: theme.isInstrument ? 2 : 5) {
                            PanelTokenNumber(value: store.hasLoadedRemoteSnapshot ? selected.tokens : nil,
                                             size: theme.isInstrument ? 28 : 30, spacing: 0)
                            Text("Token").meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                        }.frame(minHeight: theme.isInstrument ? 35 : 37.5)
                    }
                    Spacer(minLength: 0)
                }.padding(.bottom, 19)
                PanelRule()
                models(selected).padding(.top, theme.isInstrument ? 14 : 16)
            }
        } else {
            Text("—").meterText(.value, size: theme.isInstrument ? 30 : 33, weight: .medium)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        }
    }

    private func heading(for date: Date) -> some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L10n.text(.monthlyUsage, language: settings.language)).meterText(.title, size: 13, weight: .semibold)
                UsageDayIndicator(date: date, period: period)
            }
            Spacer(minLength: 8)
            Button { isRangePopoverPresented.toggle() } label: {
                HStack(spacing: 8) {
                    Text(UsageStatisticsL10n.range(range, period: period, language: settings.language))
                    Image(systemName: "chevron.down").font(.system(size: 7))
                }.meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
            }.buttonStyle(.plain).fixedSize()
                .background {
                    GeometryReader { geometry in
                        Color.clear.onAppear { rangeTriggerSize = geometry.size }
                            .onChange(of: geometry.size) { _, size in rangeTriggerSize = size }
                    }
                }
                .accessibilityLabel(L10n.text(.monthlyUsageRange, language: settings.language))
                .accessibilityValue(UsageStatisticsL10n.range(range, period: period, language: settings.language))
                .accessibilityIdentifier("monthly-range-button")
        }.frame(minHeight: 23)
    }

    private var periodControl: some View {
        HStack(spacing: 0) {
            ForEach(UsagePeriod.statisticsPeriods) { option in
                Button {
                    guard period != option else { return }
                    settings.usageStatisticsPeriod = option
                    selectionRevision += 1
                } label: {
                    Text(UsageStatisticsL10n.period(option, language: settings.language))
                        .meterText(.detail, size: 10).lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(period == option ? theme.accent : Color.meterSecondary)
                        .frame(maxWidth: .infinity).frame(height: 27)
                        .background(period == option ? Color.meterCard : .clear, in: RoundedRectangle(cornerRadius: 5))
                        .shadow(color: period == option ? Color.black.opacity(0.04) : .clear, radius: 2, y: 1)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityAddTraits(period == option ? .isSelected : [])
                    .accessibilityIdentifier("usage-period-\(option.rawValue)")
            }
        }.padding(4).background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1).allowsHitTesting(false) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(UsageStatisticsL10n.text(.period, language: settings.language))
    }

    private func dateTabs(_ values: [AccountPeriodUsage]) -> some View {
        let selectedDate = selectedDates[period] ?? values.first?.start
        return GeometryReader { geometry in
            let visibleCount = CGFloat(max(1, min(values.count, period == .day ? 7 : period == .week ? 4 : 6)))
            let width = max(43, (geometry.size.width - 4 * (visibleCount - 1)) / visibleCount)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(values) { record in
                            Button {
                                isRangePopoverPresented = false
                                if selectedDate != record.start { selectionRevision += 1 }
                                selectedDates[period] = record.start
                            } label: {
                                Text(UsageStatisticsL10n.label(record.start, period: period, language: settings.language, calendar: UsageCalendar.calendar))
                                    .meterText(.detail, size: 10).lineLimit(1).minimumScaleFactor(0.65)
                                    .foregroundStyle(selectedDate == record.start ? theme.accent : Color.meterSecondary)
                                    .frame(width: width, height: 29)
                                    .background(selectedDate == record.start ? theme.accentSoft : .clear,
                                                in: RoundedRectangle(cornerRadius: 5)).contentShape(Rectangle())
                            }.buttonStyle(.plain).id(record.start)
                                .accessibilityAddTraits(selectedDate == record.start ? .isSelected : [])
                                .help(UsageStatisticsL10n.dateCaption(record.start, period: period, language: settings.language, calendar: UsageCalendar.calendar)
                                      + "\n" + UsageDayL10n.help(containing: record.start, period: period, language: settings.language))
                        }
                    }
                }.onChange(of: selectedDate) { _, date in if let date { proxy.scrollTo(date, anchor: .center) } }
            }
        }.frame(height: 29)
    }

    private func models(_ selected: AccountPeriodUsage) -> some View {
        let list = store.accountModels(for: period, containing: selected.start)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(RedesignL10n.text(.modelsUsed, language: settings.language)).meterText(.title, size: 12, weight: .semibold)
                Spacer(minLength: 8)
                if !list.models.isEmpty {
                    Text(RedesignL10n.modelCount(list.models.count, language: settings.language))
                        .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                }
                if list.isStale && list.state == .failed {
                    Text(RedesignL10n.text(.updateFailed, language: settings.language))
                        .meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
                    retryModelsButton(selected)
                }
            }.frame(minHeight: 18).padding(.bottom, theme.isInstrument ? 13 : 8)
            if list.models.isEmpty {
                VStack(spacing: 8) {
                    if list.state == .loading {
                        ProgressView().controlSize(.small)
                    }
                    Text(modelStateText(list.state))
                        .meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary)
                    if list.state == .failed { retryModelsButton(selected) }
                }.frame(maxWidth: .infinity, minHeight: 84)
            } else {
                ForEach(list.models) { model in
                    HStack(spacing: 9) {
                        Circle().fill(theme.accent.opacity(0.6)).frame(width: 4, height: 4)
                        Text(model.model).meterText(.title, size: 12).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer(minLength: 5)
                        if model.isFast {
                            Text("Fast").meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 4))
                        }
                        Text(ModelUsageL10n.share(model.usageShare, language: settings.language))
                            .meterText(.value, size: 11, weight: .medium)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 54, alignment: .trailing)
                            .help(ModelUsageL10n.text(model.usageShare == nil ? .shareUnavailable : .shareHint,
                                                     language: settings.language))
                            .accessibilityLabel(ModelUsageL10n.text(.share, language: settings.language))
                            .accessibilityValue(ModelUsageL10n.share(model.usageShare, language: settings.language))
                    }.frame(minHeight: 27)
                }
            }
        }.accessibilityIdentifier("historical-models")
    }
    private func modelStateText(_ state: AccountModelLoadState) -> String {
        let key: RedesignL10n.Key
        switch state {
        case .idle, .loading: key = .modelsLoading
        case .unsupported: key = .modelsUnavailable
        case .failed: key = .modelsFailed
        case .loaded: key = .noModels
        }
        return RedesignL10n.text(key, language: settings.language)
    }
    private func retryModelsButton(_ record: AccountPeriodUsage) -> some View {
        Button(L10n.text(.retry, language: settings.language)) {
            let requestedPeriod = period
            Task { await store.loadAccountModels(for: requestedPeriod, containing: record.start, force: true) }
        }.meterText(.detail, size: 11).buttonStyle(.plain).foregroundStyle(theme.accent)
    }
    private func historyTitle(_ record: AccountPeriodUsage) -> String {
        if settings.language == .simplifiedChinese || settings.language == .traditionalChinese {
            if period == .day {
                let calendar = UsageCalendar.calendar
                let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())
                let isYesterday = yesterday.map { calendar.isDate(record.start, inSameDayAs: $0) } == true
                return isYesterday ? "昨日用量" : settings.language == .simplifiedChinese ? "当日用量" : "當日用量"
            }
            switch period {
            case .week: return settings.language == .simplifiedChinese ? "每周用量" : "每週用量"
            case .month: return "每月用量"
            case .year: return "每年用量"
            default: break
            }
        }
        let label = UsageStatisticsL10n.label(record.start, period: period, language: settings.language, calendar: UsageCalendar.calendar)
        return L10n.monthUsageTitle(label, language: settings.language)
    }
}
