import SwiftUI

struct SettingsPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var updateController: UpdateController
    @State private var selectedSection: SettingsSection

    init(
        showBackgroundsInitially: Bool = false,
        showDisplayInitially: Bool = false,
        showFontsInitially: Bool = false
    ) {
        let initialSection: SettingsSection = if showFontsInitially {
            .fonts
        } else if showDisplayInitially {
            .display
        } else if showBackgroundsInitially {
            .backgrounds
        } else {
            .general
        }
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 180)

            Divider()
                .overlay(Color.meterBorder)

            ScrollView(.vertical) {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 760, height: 552)
        .foregroundStyle(Color.meterPrimary)
        .background(Color.meterPanel)
        .onChange(of: settings.automaticRefreshInterval) { _, _ in
            store.rescheduleAutomaticRefresh()
        }
        .onChange(of: settings.customRefreshIntervalMinutes) { _, _ in
            guard settings.automaticRefreshInterval == .custom else { return }
            store.rescheduleAutomaticRefresh()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CodexIconView(size: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Codex Meter")
                        .font(.meter(size: 13.5))
                    Text(L10n.text(.settings, language: settings.language))
                        .font(.meter(size: 10.5))
                        .foregroundStyle(Color.meterSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases.filter { $0 != .updates }) { section in
                    sidebarButton(section)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            sidebarButton(.updates)
                .padding(.horizontal, 10)

            Text(L10n.text(.settingsHint, language: settings.language))
                .font(.meter(size: 9.5))
                .foregroundStyle(Color.meterTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        }
        .frame(maxHeight: .infinity)
        .background(Color.meterCard.opacity(0.7))
    }

    private func sidebarButton(_ section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        return Button {
            selectedSection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.meter(size: 13))
                    .frame(width: 18)

                Text(section.sidebarTitle(language: settings.language))
                    .font(.meter(size: 12.5))

                Spacer()
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.meterAccent : Color.meterPrimary)
        .background(
            isSelected ? Color.meterAccent.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text(selectedSection.title(language: settings.language))
                    .font(.meter(size: 22))

                Text(selectedSection.hint(language: settings.language))
                    .font(.meter(size: 11.5))
                    .foregroundStyle(Color.meterSecondary)
            }

            switch selectedSection {
            case .general:
                generalSettings
            case .menuBar:
                menuBarSettings
            case .display:
                displaySettings
            case .fonts:
                FontSettingsView()
            case .backgrounds:
                QuotaBackgroundSettingsView()
            case .refresh:
                refreshSettings
            case .updates:
                updateSettings
            case .data:
                DataSettingsView()
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    private var generalSettings: some View {
        SettingsCard {
            SettingsRow(
                icon: "power",
                title: L10n.text(.launchAtLogin, language: settings.language),
                detail: launchAtLoginDetail
            ) {
                Toggle(
                    L10n.text(.launchAtLogin, language: settings.language),
                    isOn: $settings.launchAtLogin
                )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }

            SettingsDivider()

            SettingsRow(
                icon: "circle.lefthalf.filled",
                title: L10n.text(.appearance, language: settings.language),
                detail: L10n.text(.appearanceHint, language: settings.language)
            ) {
                Picker("", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(L10n.appearanceTitle(appearance, language: settings.language))
                            .tag(appearance)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 244)
            }

            SettingsDivider()

            SettingsRow(
                icon: "character.book.closed.fill",
                title: L10n.text(.language, language: settings.language),
                detail: L10n.text(.languageHint, language: settings.language)
            ) {
                SearchableLanguagePicker(selection: $settings.language)
                    .frame(width: 244)
            }
        }
    }

    private var menuBarSettings: some View {
        VStack(spacing: 18) {
            SettingsCard {
                SettingsRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: L10n.text(.menuBarIconSize, language: settings.language),
                    detail: L10n.text(.menuBarIconSizeHint, language: settings.language)
                ) {
                    HStack(spacing: 10) {
                        Slider(
                            value: $settings.menuBarIconSize,
                            in: AppSettings.menuBarIconSizeRange,
                            step: 1
                        ) {
                            Text(L10n.text(.menuBarIconSize, language: settings.language))
                        }
                        .labelsHidden()
                        .tint(.meterAccent)

                        Text("\(Int(settings.menuBarIconSize)) pt")
                            .font(.meter(size: 11))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    .frame(width: 180)
                }
            }

            SettingsCard {
                VStack(spacing: 16) {
                    Text(L10n.text(.menuBarPreview, language: settings.language))
                        .font(.meter(size: 11))
                        .foregroundStyle(Color.meterSecondary)

                    MenuBarLabelView()
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color.meterControl, in: Capsule())

                    Text(L10n.text(.menuBarQuotaHint, language: settings.language))
                        .font(.meter(size: 10.5))
                        .foregroundStyle(Color.meterSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var displaySettings: some View {
        SettingsCard {
            List {
                ForEach(settings.dashboardSectionOrder) { section in
                    visibilityRow(section)
                        .overlay(alignment: .bottom) {
                            if section != settings.dashboardSectionOrder.last {
                                SettingsDivider()
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .onMove(perform: settings.moveDashboardSections)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(settings.dashboardSectionOrder.count) * 72 + 125)
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: settings.dashboardSectionOrder)
    }

    @ViewBuilder
    private func visibilityRow(_ section: DashboardSection) -> some View {
        switch section {
        case .quota:
            visibilityRowContent(section, isOn: $settings.showQuotaCard)
        case .tokenActivity:
            visibilityRowContent(section, isOn: $settings.showTokenActivityCard)
        case .activityOverview:
            visibilityRowContent(section, isOn: $settings.showActivityOverviewCard)
        case .monthlyUsage:
            VStack(alignment: .leading, spacing: 0) {
                visibilityRowContent(section, isOn: $settings.showMonthlyUsageCard)
                VStack(alignment: .leading, spacing: 7) {
                    Picker(UsageStatisticsL10n.text(.period, language: settings.language), selection: $settings.usageStatisticsPeriod) {
                        ForEach(UsagePeriod.allCases) { period in
                            Text(UsageStatisticsL10n.period(period, language: settings.language)).tag(period)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .font(.meter(size: 10))
                    Text(L10n.text(.monthlyUsageRange, language: settings.language))
                        .font(.meter(size: 9))
                        .foregroundStyle(Color.meterSecondary)
                    Picker(L10n.text(.monthlyUsageRange, language: settings.language), selection: Binding(get: { settings.usageStatisticsRange(for: settings.usageStatisticsPeriod) },
                                      set: { settings.setUsageStatisticsRange($0, for: settings.usageStatisticsPeriod) })) {
                        ForEach(settings.usageStatisticsPeriod.ranges, id: \.self) { count in
                            Text(UsageStatisticsL10n.range(count, period: settings.usageStatisticsPeriod, language: settings.language)).tag(count)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .font(.meter(size: 10))
                    Text(UsageStatisticsL10n.text(.rangeHint, language: settings.language))
                        .font(.meter(size: 8.5))
                        .foregroundStyle(Color.meterTertiary)
                }
                .padding(.leading, 49)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(height: 125)
                .disabled(!settings.showMonthlyUsageCard)
                .opacity(settings.showMonthlyUsageCard ? 1 : 0.45)
            }
        case .usageHeatmap:
            visibilityRowContent(section, isOn: $settings.showUsageHeatmapCard)
        case .usageSummary:
            visibilityRowContent(section, isOn: $settings.showUsageSummaryCard)
        case .creditsBalance:
            visibilityRowContent(section, isOn: $settings.showCreditsBalanceCard)
        }
    }

    private func visibilityRowContent(
        _ section: DashboardSection,
        isOn: Binding<Bool>
    ) -> some View {
        let title = L10n.text(section.titleKey, language: settings.language)
        return SettingsRow(
            icon: section.icon,
            title: title,
            detail: L10n.text(section.detailKey, language: settings.language)
        ) {
            HStack(spacing: 12) {
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Image(systemName: "line.3.horizontal")
                    .font(.meter(size: 12))
                    .foregroundStyle(Color.meterTertiary)
                    .frame(width: 18, height: 30)
                    .contentShape(Rectangle())
                    .help(L10n.text(.displayHint, language: settings.language))
                    .accessibilityLabel(L10n.text(.displayHint, language: settings.language))
            }
        }
    }

    private var launchAtLoginDetail: String {
        let hint = L10n.text(.launchAtLoginHint, language: settings.language)
        guard let error = settings.launchAtLoginErrorDescription else { return hint }
        return "\(hint) · \(error)"
    }

    private var refreshSettings: some View {
        SettingsCard {
            SettingsRow(
                icon: "clock.arrow.circlepath",
                title: L10n.text(.automaticRefresh, language: settings.language),
                detail: L10n.text(.automaticRefreshHint, language: settings.language)
            ) {
                Picker("", selection: $settings.automaticRefreshInterval) {
                    ForEach(AutomaticRefreshInterval.allCases) { interval in
                        Text(L10n.refreshIntervalTitle(interval, language: settings.language))
                            .tag(interval)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 196)
            }

            if settings.automaticRefreshInterval == .custom {
                SettingsDivider()

                SettingsRow(
                    icon: "slider.horizontal.3",
                    title: L10n.text(.customMinutes, language: settings.language),
                    detail: L10n.text(.minuteRangeHint, language: settings.language)
                ) {
                    HStack(spacing: 8) {
                        TextField(
                            "",
                            value: $settings.customRefreshIntervalMinutes,
                            format: .number
                        )
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 76)

                        Stepper(
                            "",
                            value: $settings.customRefreshIntervalMinutes,
                            in: 1...1_440
                        )
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
        }
    }

    private var updateSettings: some View {
        SettingsCard {
            SettingsRow(
                icon: "number.circle.fill",
                title: L10n.updateText(.currentVersion, language: settings.language),
                detail: L10n.updateText(.currentVersionHint, language: settings.language)
            ) {
                Text(updateController.currentVersion)
                    .font(.meter(size: 12))
                    .foregroundStyle(Color.meterSecondary)
            }

            SettingsDivider()

            SettingsRow(
                icon: "arrow.down.circle.fill",
                title: L10n.updateText(.appUpdates, language: settings.language),
                detail: updateStatusText
            ) {
                Button {
                    updateController.checkManually()
                } label: {
                    if updateController.state == .checking {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 134)
                    } else {
                        Text(L10n.updateText(.checkForUpdates, language: settings.language))
                            .frame(width: 134)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.meterAccent)
                .disabled(
                    updateController.state == .checking
                        || !updateController.isUpdateCheckingEnabled
                )
            }
        }
    }

    private var updateStatusText: String {
        guard updateController.isUpdateCheckingEnabled else {
            return L10n.updateText(.debugBuildUpdateHint, language: settings.language)
        }

        return switch updateController.state {
        case .idle:
            L10n.updateText(.automaticUpdateHint, language: settings.language)
        case .checking:
            L10n.updateText(.checkingForUpdates, language: settings.language)
        case .upToDate:
            L10n.updateText(.upToDate, language: settings.language)
        case let .available(version):
            L10n.updateAvailableStatus(version: version, language: settings.language)
        case .failed:
            L10n.updateText(.updateCheckFailed, language: settings.language)
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case menuBar
    case display
    case fonts
    case backgrounds
    case refresh
    case data
    case updates

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "switch.2"
        case .menuBar: "menubar.rectangle"
        case .display: "eye"
        case .fonts: "textformat.size"
        case .backgrounds: "photo"
        case .refresh: "arrow.clockwise"
        case .updates: "arrow.down.circle"
        case .data: "externaldrive"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general: L10n.text(.general, language: language)
        case .menuBar: L10n.text(.menuBar, language: language)
        case .display: L10n.text(.display, language: language)
        case .fonts: FontL10n.text(.title, language: language)
        case .backgrounds: QuotaBackgroundL10n.text(.backgrounds, language: language)
        case .refresh: L10n.text(.refresh, language: language)
        case .updates: L10n.updateText(.updates, language: language)
        case .data: StorageL10n.text(.title, language: language)
        }
    }

    func sidebarTitle(language: AppLanguage) -> String {
        switch (self, language) {
        case (.menuBar, .simplifiedChinese): "菜单"
        case (.menuBar, .traditionalChinese): "選單"
        case (.data, .simplifiedChinese): "数据"
        case (.data, .traditionalChinese): "資料"
        case (.refresh, .traditionalChinese): "刷新"
        default: title(language: language)
        }
    }

    func hint(language: AppLanguage) -> String {
        switch self {
        case .general: L10n.text(.generalHint, language: language)
        case .menuBar: L10n.text(.menuBarHint, language: language)
        case .display: L10n.text(.displayHint, language: language)
        case .fonts: FontL10n.text(.hint, language: language)
        case .backgrounds: QuotaBackgroundL10n.text(.backgroundsHint, language: language)
        case .refresh: L10n.text(.refreshHint, language: language)
        case .updates: L10n.updateText(.updatesHint, language: language)
        case .data: StorageL10n.text(.hint, language: language)
        }
    }
}

private extension DashboardSection {
    var icon: String {
        switch self {
        case .quota: "gauge.with.dots.needle.67percent"
        case .tokenActivity: "list.bullet.rectangle"
        case .activityOverview: "waveform.path.ecg"
        case .monthlyUsage: "calendar"
        case .usageHeatmap: "calendar"
        case .usageSummary: "chart.bar.xaxis"
        case .creditsBalance: "creditcard"
        }
    }

    var titleKey: L10n.Key {
        switch self {
        case .quota: .showQuotaCard
        case .tokenActivity: .todayDetails
        case .activityOverview: .activityOverview
        case .monthlyUsage: .showMonthlyUsageCard
        case .usageHeatmap: .showUsageHeatmapCard
        case .usageSummary: .showUsageSummaryCard
        case .creditsBalance: .showCreditsBalanceCard
        }
    }

    var detailKey: L10n.Key {
        switch self {
        case .quota: .showQuotaCardHint
        case .tokenActivity: .showTokenActivityCardHint
        case .activityOverview: .activityOverviewHint
        case .monthlyUsage: .showMonthlyUsageCardHint
        case .usageHeatmap: .showUsageHeatmapCardHint
        case .usageSummary: .showUsageSummaryCardHint
        case .creditsBalance: .showCreditsBalanceCardHint
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            Color.meterCard,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.meterBorder, lineWidth: 1)
        }
        .shadow(color: Color.meterShadow, radius: 10, y: 2)
    }
}

private struct SettingsRow<Control: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    init(
        icon: String,
        title: String,
        detail: String,
        @ViewBuilder control: () -> Control
    ) {
        self.icon = icon
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.meter(size: 13))
                .foregroundStyle(Color.meterAccent)
                .frame(width: 32, height: 32)
                .background(
                    Color.meterAccent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.meter(size: 12.5))
                Text(detail)
                    .font(.meter(size: 9.8))
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 14)

            control
        }
        .padding(.horizontal, 15)
        .frame(minHeight: 72)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.meterBorder)
            .padding(.leading, 60)
    }
}

private struct SearchableLanguagePicker: View {
    @Binding var selection: AppLanguage
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 8) {
                Text(selection.nativeName)
                    .font(.meter(size: 11.5))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.meter(size: 9))
                    .foregroundStyle(Color.meterSecondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color.meterControl,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.meterBorder, lineWidth: 1)
        }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            LanguageSearchPopover(
                selection: $selection,
                isPresented: $isPresented
            )
        }
    }
}

private struct LanguageSearchPopover: View {
    @Binding var selection: AppLanguage
    @Binding var isPresented: Bool
    @State private var query = ""
    @FocusState private var searchIsFocused: Bool

    private var filteredLanguages: [AppLanguage] {
        let normalizedQuery = normalized(query)
        guard !normalizedQuery.isEmpty else { return AppLanguage.allCases }
        return AppLanguage.allCases.filter { language in
            language.searchTerms.contains { normalized($0).contains(normalizedQuery) }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.meter(size: 11))
                    .foregroundStyle(Color.meterSecondary)

                TextField(
                    "",
                    text: $query,
                    prompt: Text(L10n.text(.searchLanguage, language: selection))
                )
                .textFieldStyle(.plain)
                .focused($searchIsFocused)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                Color.meterControl,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.meterBorder, lineWidth: 1)
            }

            Divider().overlay(Color.meterBorder)

            if filteredLanguages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.meter(size: 20))
                        .foregroundStyle(Color.meterTertiary)
                    Text(L10n.text(.noLanguagesFound, language: selection))
                        .font(.meter(size: 11))
                        .foregroundStyle(Color.meterSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredLanguages) { language in
                            languageButton(language)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 300, height: 300)
        .foregroundStyle(Color.meterPrimary)
        .background(Color.meterPanel)
        .onAppear {
            query = ""
            searchIsFocused = true
        }
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        Button {
            selection = language
            isPresented = false
        } label: {
            HStack(spacing: 8) {
                Text(language.nativeName)
                    .font(.meter(size: 11.5))

                Spacer()

                Text(language.rawValue)
                    .font(.meter(size: 9.5))
                    .foregroundStyle(Color.meterTertiary)

                Image(systemName: "checkmark")
                    .font(.meter(size: 10))
                    .foregroundStyle(Color.meterAccent)
                    .opacity(selection == language ? 1 : 0)
                    .frame(width: 14)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            selection == language ? Color.meterAccent.opacity(0.10) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}
