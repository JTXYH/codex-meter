import SwiftUI

struct SettingsPanelView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var updateController: UpdateController
    @State private var selectedSection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 172)

            Divider()
                .overlay(Color.meterBorder)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 720, height: 460)
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
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Text(L10n.text(.settings, language: settings.language))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 20)

            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases) { section in
                    sidebarButton(section)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text(L10n.text(.settingsHint, language: settings.language))
                .font(.system(size: 9.5, weight: .medium, design: .rounded))
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
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)

                Text(section.title(language: settings.language))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))

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
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(selectedSection.hint(language: settings.language))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
            }

            switch selectedSection {
            case .general:
                generalSettings
            case .refresh:
                refreshSettings
            case .updates:
                updateSettings
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
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
                .disabled(updateController.state == .checking)
            }
        }
    }

    private var updateStatusText: String {
        switch updateController.state {
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

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case refresh
    case updates

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "switch.2"
        case .refresh: "arrow.clockwise"
        case .updates: "arrow.down.circle"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .general: L10n.text(.general, language: language)
        case .refresh: L10n.text(.refresh, language: language)
        case .updates: L10n.updateText(.updates, language: language)
        }
    }

    func hint(language: AppLanguage) -> String {
        switch self {
        case .general: L10n.text(.generalHint, language: language)
        case .refresh: L10n.text(.refreshHint, language: language)
        case .updates: L10n.updateText(.updatesHint, language: language)
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.meterAccent)
                .frame(width: 32, height: 32)
                .background(
                    Color.meterAccent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                Text(detail)
                    .font(.system(size: 9.8, weight: .medium, design: .rounded))
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
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
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
                    .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 20))
                        .foregroundStyle(Color.meterTertiary)
                    Text(L10n.text(.noLanguagesFound, language: selection))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))

                Spacer()

                Text(language.rawValue)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.meterTertiary)

                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
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
