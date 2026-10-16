import SwiftUI
import UniformTypeIdentifiers

final class SettingsNavigationState: ObservableObject {
    @Published var requestedSection: SettingsSection?
}

#if DEBUG
enum SettingsPreviewDialog { case language, cleanup }
#endif

struct SettingsPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var updateController: UpdateController
    @State private var selectedSection: SettingsSection
    @State private var isLanguagePresented = false
    @State private var cleanupRequest: SettingsCleanupRequest?
    @State private var draggedModule: DashboardSection?
    private let initialStorageInfo: StorageInfo?
    private let navigation: SettingsNavigationState
#if DEBUG
    @State private var previewCleanup = false
#endif

    init(initialSection: SettingsSection = .general, initialStorageInfo: StorageInfo? = nil,
         navigation: SettingsNavigationState = SettingsNavigationState()) {
        self.initialStorageInfo = initialStorageInfo
        self.navigation = navigation
        _selectedSection = State(initialValue: initialSection)
    }

#if DEBUG
    init(initialSection: SettingsSection = .general, initialStorageInfo: StorageInfo? = nil,
         previewDialog: SettingsPreviewDialog) {
        self.initialStorageInfo = initialStorageInfo
        self.navigation = SettingsNavigationState()
        _selectedSection = State(initialValue: initialSection)
        _isLanguagePresented = State(initialValue: previewDialog == .language)
        _previewCleanup = State(initialValue: previewDialog == .cleanup)
    }
#endif

    private func text(_ key: String) -> String { SettingsCopy.text(key, language: settings.language) }
    private var hasDialog: Bool { isLanguagePresented || cleanupRequest != nil }
    private var theme: PanelTheme { settings.panelTheme }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                sidebar.frame(width: 164)
                Rectangle().fill(Color.meterBorder).frame(width: 1)
                ScrollView(.vertical) {
                    content.frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .id(selectedSection)
                .scrollIndicators(.automatic)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.trailing, 1)
            .allowsHitTesting(!hasDialog)
            .accessibilityHidden(hasDialog)
            .compositingGroup()
            .blur(radius: hasDialog ? 2.5 : 0)

            if hasDialog {
                Color(red: 18 / 255, green: 22 / 255, blue: 40 / 255).opacity(0.26)
                    .contentShape(Rectangle()).onTapGesture { dismissDialog() }
                if isLanguagePresented {
                    SettingsLanguageDialog(selection: $settings.language, dismiss: dismissDialog)
                } else if let cleanupRequest {
                    SettingsCleanupDialog(request: cleanupRequest, dismiss: dismissDialog)
                }
            }
        }
        .frame(width: 820, height: 620)
        .foregroundStyle(Color.meterPrimary)
        .background(Color.meterCard)
        .environment(\.meterTheme, theme)
        .tint(theme.accent)
        .focusEffectDisabled()
        .onExitCommand(perform: dismissDialog)
        .onAppear {
#if DEBUG
            if previewCleanup {
                previewCleanup = false
                cleanupRequest = SettingsCleanupRequest(
                    detail: SettingsCopy.cleanupAgeDetail(90, language: settings.language), perform: {})
            }
#endif
        }
        .onReceive(navigation.$requestedSection) { section in
            if let section {
                dismissDialog()
                selectedSection = section
                navigation.requestedSection = nil
            }
        }
        .onChange(of: settings.automaticRefreshInterval) { _, _ in store.rescheduleAutomaticRefresh() }
        .onChange(of: settings.customRefreshIntervalMinutes) { _, _ in
            if settings.automaticRefreshInterval == .custom { store.rescheduleAutomaticRefresh() }
        }
    }

    private func dismissDialog() { isLanguagePresented = false; cleanupRequest = nil }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                CodexIconView(size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex Meter").font(.system(size: 12, weight: .semibold)).tracking(-0.2).frame(height: 18)
                    Text(L10n.text(.settings, language: settings.language))
                        .font(.system(size: 10)).foregroundStyle(Color.meterSecondary).frame(height: 15)
                }
            }
            .padding(.horizontal, 7).padding(.bottom, 28)
            VStack(spacing: 5) {
                ForEach(SettingsSection.allCases) { section in
                    Button { selectedSection = section } label: {
                        HStack(spacing: 9) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 15, weight: .regular))
                                .symbolRenderingMode(.monochrome)
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                            Text(section.title(language: settings.language)).font(.system(size: 12))
                                .lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 11).frame(height: 37).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedSection == section ? theme.accent : Color.meterPrimary)
                    .background(selectedSection == section ? theme.accentSoft : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
                    .accessibilityIdentifier("settings-section-\(section.rawValue)")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 11).padding(.trailing, 9).padding(.top, 25).padding(.bottom, 16)
        .frame(maxHeight: .infinity).background(Color.meterPanel)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: selectedSection == .updates ? 26 : 23) {
            VStack(alignment: .leading, spacing: 7) {
                Text(selectedSection.title(language: settings.language))
                    .font(.system(size: 22, weight: .semibold)).tracking(-0.6)
                    .frame(height: 28.6, alignment: .leading)
                if selectedSection != .general && selectedSection != .updates {
                    Text(selectedSection.hint(language: settings.language))
                        .font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true).frame(minHeight: 18.15)
                }
            }
            Group {
                switch selectedSection {
                case .general: generalSettings
                case .menuBar: menuBarSettings
                case .display: displaySettings
                case .fonts: FontSettingsView()
                case .refresh: refreshSettings
                case .data: DataSettingsView(initialInfo: initialStorageInfo, onCleanupRequest: { cleanupRequest = $0 })
                case .updates: updateSettings
                }
            }
        }
        .padding(.horizontal, 30).padding(.top, 29).padding(.bottom, 28)
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text(text("panelTheme")).font(.system(size: 13, weight: .semibold)).frame(height: 19.5)
                    Spacer()
                    Button(text("viewPanel")) { SettingsWindowController.shared.showMainPanel() }
                        .buttonStyle(SettingsButtonStyle(kind: .link))
                }
                HStack(spacing: 14) {
                    themeButton(.quiet)
                    themeButton(.instrument)
                }
            }
            SettingsCard {
                Text(text("startup")).font(.system(size: 13, weight: .semibold))
                    .frame(height: 19.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 15).padding(.horizontal, 16).padding(.bottom, 12)
                HStack(spacing: 8) {
                    startupButton("manual")
                    startupButton("login")
                    startupButton("codex")
                }.padding(.horizontal, 16).padding(.bottom, 14)
            }
            SettingsCard {
                SettingsRow(title: L10n.text(.appearance, language: settings.language), detail: text("appearanceDetail")) {
                    appearanceControl
                }
                SettingsDivider()
                SettingsRow(title: L10n.text(.language, language: settings.language), detail: text("languageDetail")) {
                    Button { isLanguagePresented = true } label: {
                        HStack {
                            Text(settings.language.nativeName)
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 9))
                        }.font(.system(size: 11)).padding(.horizontal, 10).frame(width: 175, height: 34)
                            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("settings-language")
                }
            }
            QuotaStatusSettingsView()
            if let error = settings.launchAtLoginErrorDescription ?? settings.followCodexAppErrorDescription {
                startupMessage(title: text("startupError"), detail: error, isError: true)
            } else if settings.followCodexAppRequiresApproval {
                startupMessage(title: text("approval"),
                               detail: L10n.text(.followCodexAppApprovalHint, language: settings.language), isError: false)
            } else if settings.followCodexApp {
                SettingsNote(text: text("startupNote"))
            }
        }
    }

    private func themeButton(_ theme: PanelTheme) -> some View {
        let selected = settings.panelTheme == theme
        return Button { settings.panelTheme = theme } label: {
            VStack(spacing: 0) {
                SettingsThemeArtwork(theme: theme)
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text(theme == .quiet ? "quiet" : "instrument"))
                            .font(.system(size: 12, weight: .semibold)).frame(height: 18)
                        Text(text(theme == .quiet ? "quietDetail" : "instrumentDetail"))
                            .font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                            .lineLimit(1).minimumScaleFactor(0.8).frame(height: 15)
                    }
                    Spacer(minLength: 0)
                    Circle().fill(selected ? theme.accent : .clear)
                        .overlay(Circle().strokeBorder(selected ? theme.accent : Color.meterBorder, lineWidth: 1))
                        .overlay { if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .semibold)).foregroundStyle(SettingsPalette.primaryButtonText(for: theme)) } }
                        .frame(width: 17, height: 17)
                }.padding(12).frame(height: 61)
            }
            .padding(1)
            .frame(maxWidth: .infinity).background(Color.meterCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? theme.accent : Color.meterBorder,
                                                                   lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text(theme == .quiet ? "quiet" : "instrument"))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("settings-theme-\(theme.rawValue)")
    }

    private var startupMode: String { settings.followCodexApp ? "codex" : settings.launchAtLogin ? "login" : "manual" }
    private func startupButton(_ mode: String) -> some View {
        let selected = startupMode == mode
        return Button {
            switch mode {
            case "codex": settings.followCodexApp = true
            case "login": settings.launchAtLogin = true
            default:
                if settings.followCodexApp { settings.followCodexApp = false }
                if settings.launchAtLogin { settings.launchAtLogin = false }
            }
        } label: {
            HStack(alignment: .top, spacing: 7) {
                Circle().fill(Color.meterCard)
                    .overlay(Circle().strokeBorder(selected ? theme.accent : Color.meterBorder,
                                                   lineWidth: selected ? 4 : 1))
                    .frame(width: 13, height: 13).padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    Text(text(mode)).font(.system(size: 11, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7).frame(height: 16.5)
                    Text(text(mode + "Detail")).font(.system(size: 9)).foregroundStyle(Color.meterSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7).frame(height: 13.5)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10).padding(.horizontal, 9)
            .padding(1)
            .frame(maxWidth: .infinity, minHeight: 53, alignment: .leading)
            .background(selected ? theme.accentSoft : Color.meterCard, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? theme.accent : Color.meterBorder, lineWidth: 1))
        }
        .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var appearanceControl: some View {
        HStack(spacing: 2) {
            ForEach(AppAppearance.allCases) { appearance in
                Button { settings.appearance = appearance } label: {
                    Text(appearance == .system ? text("appearanceAuto") : L10n.appearanceTitle(appearance, language: settings.language))
                        .font(.system(size: 11))
                        .foregroundStyle(settings.appearance == appearance ? Color.meterPrimary : Color.meterSecondary)
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .background(settings.appearance == appearance ? Color.meterPanel : .clear,
                                    in: RoundedRectangle(cornerRadius: 5))
                        .shadow(color: .black.opacity(settings.appearance == appearance ? 0.07 : 0), radius: 1.5, y: 1)
                }.buttonStyle(.plain).accessibilityAddTraits(settings.appearance == appearance ? .isSelected : [])
            }
        }
        .padding(3).background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
    }

    private func startupMessage(title: String, detail: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("!").font(.system(size: 12)).frame(width: 23, height: 23)
                .foregroundStyle(isError ? SettingsPalette.danger : theme.accent)
                .background(isError ? SettingsPalette.danger.opacity(0.1) : theme.accentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(detail).font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14).background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.meterBorder, lineWidth: 1))
    }

    private var menuBarSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    Text("●").font(.system(size: 10))
                    Text("Finder").fontWeight(.semibold)
                    Text(text("menuFile"))
                    Text(text("menuEdit"))
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        SettingsQuotaRing(size: settings.menuBarIconSize, lineWidth: 3)
                        Text("64%").font(.system(size: 12, weight: .medium))
                    }
                    Text("15:42")
                }
                .font(.system(size: 10)).padding(.horizontal, 12).frame(height: 32)
                .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.meterBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 9, y: 4)
                Text(text("menuPreview"))
                    .font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
            }
            .padding(.horizontal, 20).padding(.top, 27).padding(.bottom, 17).frame(height: 139, alignment: .top)
            .background(LinearGradient(colors: [theme.accentSoft, .meterPanel], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.meterBorder, lineWidth: 1))
            SettingsCard {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(text("iconSize")).font(.system(size: 13, weight: .semibold)).frame(minHeight: 19.5)
                            Text(text("iconSizeDetail")).font(.system(size: 11)).foregroundStyle(Color.meterSecondary).frame(minHeight: 18.15)
                        }
                        Spacer()
                        Text("\(Int(settings.menuBarIconSize)) pt").font(.system(size: 18)).monospacedDigit()
                            .foregroundStyle(theme.accent)
                    }
                    SettingsSlider(value: $settings.menuBarIconSize, range: AppSettings.menuBarIconSizeRange,
                                   step: 1, label: text("iconSize"))
                        .padding(.top, 22).padding(.bottom, 6)
                    HStack { Text("12 pt"); Spacer(); Text("22 pt") }
                        .font(.system(size: 10)).foregroundStyle(Color.meterTertiary).frame(height: 15).padding(.top, 4)
                }.padding(18)
            }
            SettingsNote(text: text("menuNote"), symbol: "circle.inset.filled")
        }
    }

    private var displaySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                ForEach(Array(settings.dashboardSectionOrder.enumerated()), id: \.element) { index, section in
                    if index > 0 { SettingsDivider() }
                    moduleRow(section, index: index)
                        .onDrag { draggedModule = section; return NSItemProvider(object: section.rawValue as NSString) }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard !providers.isEmpty, let source = draggedModule,
                                  let sourceIndex = settings.dashboardSectionOrder.firstIndex(of: source), source != section else { return false }
                            settings.moveDashboardSections(fromOffsets: IndexSet(integer: sourceIndex),
                                                           toOffset: index > sourceIndex ? index + 1 : index)
                            draggedModule = nil
                            return true
                        }
                }
            }
            Text(text("reorderHint")).font(.system(size: 10)).foregroundStyle(Color.meterTertiary)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: settings.dashboardSectionOrder)
    }

    private func moduleRow(_ section: DashboardSection, index: Int) -> some View {
        let key = SettingsCopy.sectionKey(section)
        return VStack(spacing: 0) {
            HStack(spacing: 11) {
                Text("⠿").font(.system(size: 19)).foregroundStyle(Color.meterTertiary).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text(key)).font(.system(size: 13, weight: .semibold)).frame(minHeight: 19.5)
                    Text(text(key + "Detail")).font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true).frame(minHeight: 16.5)
                }
                Spacer(minLength: 0)
                HStack(spacing: 1) {
                    Button { moveModule(index, by: -1) } label: { Text("↑").frame(width: 21, height: 27) }
                        .disabled(index == 0).accessibilityLabel(text("moveUp") + " " + text(key))
                    Button { moveModule(index, by: 1) } label: { Text("↓").frame(width: 21, height: 27) }
                        .disabled(index == settings.dashboardSectionOrder.count - 1).accessibilityLabel(text("moveDown") + " " + text(key))
                }.buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(Color.meterSecondary)
                Toggle(text(key), isOn: visibilityBinding(section)).toggleStyle(SettingsSwitchStyle())
                    .accessibilityIdentifier("settings-visible-\(section.rawValue)")
            }.padding(.horizontal, 16).padding(.vertical, 15).frame(minHeight: 71)
            if section == .monthlyUsage {
                HStack(spacing: 14) {
                    HStack(spacing: 8) {
                        Text(text("defaultPeriod"))
                        SettingsSelect(title: text("defaultPeriod"), selection: $settings.usageStatisticsPeriod,
                                       options: UsagePeriod.statisticsPeriods,
                                       width: settings.language == .simplifiedChinese || settings.language == .traditionalChinese ? 45 : 76, size: 10) {
                            SettingsCopy.period($0, language: settings.language)
                        }
                    }
                    HStack(spacing: 8) {
                        Text(text("displayRange"))
                        SettingsSelect(title: text("displayRange"),
                                       selection: Binding(get: { settings.usageStatisticsRange(for: settings.usageStatisticsPeriod) },
                                                          set: { settings.setUsageStatisticsRange($0, for: settings.usageStatisticsPeriod) }),
                                       options: settings.usageStatisticsPeriod.ranges,
                                       width: settings.language == .simplifiedChinese || settings.language == .traditionalChinese ? (settings.usageStatisticsPeriod == .month ? 99 : 84) : 135,
                                       size: 10) {
                            SettingsCopy.range($0, period: settings.usageStatisticsPeriod, language: settings.language)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                .padding(.leading, 46).padding(.trailing, 18).padding(.bottom, 17)
                .disabled(!settings.showMonthlyUsageCard).opacity(settings.showMonthlyUsageCard ? 1 : 0.48)
            }
        }
    }

    private func moveModule(_ index: Int, by delta: Int) {
        let target = index + delta
        guard settings.dashboardSectionOrder.indices.contains(target) else { return }
        settings.moveDashboardSections(fromOffsets: IndexSet(integer: index), toOffset: delta > 0 ? target + 1 : target)
    }

    private func visibilityBinding(_ section: DashboardSection) -> Binding<Bool> {
        switch section {
        case .quota: $settings.showQuotaCard
        case .tokenActivity: $settings.showTokenActivityCard
        case .activityOverview: $settings.showActivityOverviewCard
        case .monthlyUsage: $settings.showMonthlyUsageCard
        case .usageHeatmap: $settings.showUsageHeatmapCard
        case .usageSummary: $settings.showUsageSummaryCard
        case .creditsBalance: $settings.showCreditsBalanceCard
        case .resetCredits: $settings.showResetCreditsCard
        }
    }

    private var refreshSettings: some View {
        VStack(spacing: 16) {
            SettingsCard {
                SettingsRow(title: text("refreshTitle"), detail: text("refreshDetail")) {
                    SettingsSelect(title: text("refreshTitle"), selection: $settings.automaticRefreshInterval,
                                   options: AutomaticRefreshInterval.allCases) {
                        L10n.refreshIntervalTitle($0, language: settings.language)
                    }
                }
                if settings.automaticRefreshInterval == .custom {
                    SettingsDivider()
                    SettingsRow(title: text("refreshCustom"), detail: text("refreshCustomDetail")) {
                        HStack(spacing: 8) {
                            SettingsNumberField(title: text("refreshCustom"), value: $settings.customRefreshIntervalMinutes, range: 1...1440)
                            Text(text("minuteUnit")).font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                Image(systemName: "arrow.clockwise").font(.system(size: 27)).foregroundStyle(theme.accent)
                    .frame(width: 56, height: 56).background(theme.accentSoft, in: Circle())
                    .overlay(Circle().strokeBorder(Color.meterBorder, lineWidth: 1)).padding(.bottom, 19)
                Text(SettingsCopy.refreshEvery(settings.automaticRefreshIntervalMinutes, language: settings.language))
                    .font(.system(size: 14, weight: .semibold)).frame(minHeight: 21)
                Text(text("refreshManual")).font(.system(size: 11)).foregroundStyle(Color.meterSecondary).frame(minHeight: 18.15).padding(.top, 7)
            }.frame(maxWidth: .infinity).padding(.vertical, 34)
        }
    }

    private var updateSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                HStack(spacing: 18) {
                    CodexIconView(size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codex Meter").font(.system(size: 24, weight: .semibold)).tracking(-0.8).frame(height: 31.2)
                        Text(text("appDescription")).font(.system(size: 12)).foregroundStyle(Color.meterSecondary)
                            .fixedSize(horizontal: false, vertical: true).frame(minHeight: 19.8)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 28).padding(.horizontal, 24)
                SettingsDivider().opacity(0.8)
                HStack(spacing: 10) {
                    Text(L10n.updateText(.currentVersion, language: settings.language)).foregroundStyle(Color.meterSecondary)
                    Text(updateController.currentVersion).fontWeight(.medium).monospacedDigit()
                    Spacer()
                }
                .font(.system(size: 12)).padding(.horizontal, 24).frame(height: 44)
                .background(Color.meterCard.opacity(0.65))
            }
            .padding(1)
            .background(LinearGradient(stops: [.init(color: theme.accentSoft, location: 0), .init(color: .meterCard, location: 0.65)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.meterBorder, lineWidth: 1))

            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    updateSymbol
                    VStack(alignment: .leading, spacing: 4) {
                        Text(updateTitle).font(.system(size: 13, weight: .semibold))
                        if !updateDetail.isEmpty {
                            Text(updateDetail).font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Button { updateController.checkManually() } label: { Text(updateButtonTitle).frame(minWidth: 60) }
                    .buttonStyle(SettingsButtonStyle(kind: .primary))
                    .disabled(updateController.state == .checking || !updateController.isUpdateCheckingEnabled)
                    .accessibilityIdentifier("settings-check-update")
            }
            .padding(.horizontal, 20).padding(.vertical, 21).frame(minHeight: 102)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(updateController.state == .failed ? SettingsPalette.danger.opacity(0.4) : Color.meterBorder, lineWidth: 1))
            HStack(spacing: 24) {
                projectLink(text("projectHome"), url: "https://github.com/JTXYH/codex-meter")
                projectLink(text("reportIssue"), url: "https://github.com/JTXYH/codex-meter/issues")
            }.frame(height: 19.5).padding(2)
        }
    }

    private func projectLink(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 4) { Text(title); Text("↗").font(.system(size: 12)) }
        }.font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
    }

    private var updateSymbol: some View {
        Group {
            if updateController.state == .checking { ProgressView().controlSize(.small) }
            else {
                Image(systemName: updateController.state == .failed ? "exclamationmark" : updateController.state == .upToDate ? "checkmark" : updateIsAvailable ? "arrow.down" : "arrow.clockwise")
                    .font(.system(size: 19))
            }
        }
        .foregroundStyle(updateController.state == .failed ? SettingsPalette.danger : updateController.state == .upToDate ? SettingsPalette.success : Color.meterSecondary)
        .frame(width: 35, height: 35)
        .background(updateController.state == .failed ? SettingsPalette.danger.opacity(0.09) : updateController.state == .upToDate ? SettingsPalette.success.opacity(0.1) : Color.meterPanel,
                    in: RoundedRectangle(cornerRadius: 10))
    }
    private var updateIsAvailable: Bool { if case .available = updateController.state { true } else { false } }
    private var updateTitle: String {
        guard updateController.isUpdateCheckingEnabled else { return text("developmentVersion") }
        return switch updateController.state {
        case .idle: text("appUpdates")
        case .checking: L10n.updateText(.checkingForUpdates, language: settings.language)
        case .upToDate: L10n.updateText(.upToDate, language: settings.language)
        case .available: text("updateAvailable")
        case .failed: L10n.updateText(.updateCheckFailed, language: settings.language)
        }
    }
    private var updateDetail: String {
        guard updateController.isUpdateCheckingEnabled else { return L10n.updateText(.debugBuildUpdateHint, language: settings.language) }
        return switch updateController.state {
        case .idle: ""
        case .checking: text("updateConnecting")
        case .upToDate: text("updateLatestDetail")
        case .available: text("updateAvailableDetail")
        case .failed: text("updateRetryDetail")
        }
    }
    private var updateButtonTitle: String {
        switch updateController.state {
        case .checking: L10n.updateText(.checkingForUpdates, language: settings.language)
        case .available: text("updateDownload")
        case .failed: text("updateRetry")
        default: L10n.updateText(.checkForUpdates, language: settings.language)
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, menuBar, display, fonts, refresh, data, updates
    var id: String { rawValue }
    private var key: String {
        switch self {
        case .general: "general"
        case .menuBar: "menu"
        case .display: "layout"
        case .fonts: "fonts"
        case .refresh: "refresh"
        case .data: "data"
        case .updates: "updates"
        }
    }
    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .display: "square.grid.2x2"
        case .fonts: "textformat.size"
        case .refresh: "arrow.clockwise"
        case .data: "internaldrive"
        case .updates: "info.circle"
        }
    }
    func title(language: AppLanguage) -> String {
        SettingsCopy.text(key, language: language)
    }
    func sidebarTitle(language: AppLanguage) -> String { title(language: language) }
    func hint(language: AppLanguage) -> String {
        SettingsCopy.text(key + "Hint", language: language)
    }
}

private struct SettingsQuotaRing: View {
    @Environment(\.meterTheme) private var theme
    var size: CGFloat
    var lineWidth: CGFloat
    var fraction: CGFloat = 0.64
    var startAngle: Double = -90
    var strokeColor: Color? = nil
    var trackColor: Color = .meterBorder
    var body: some View {
        Circle().stroke(trackColor, lineWidth: lineWidth)
            .overlay(Circle().trim(from: 0, to: fraction).stroke(strokeColor ?? theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)).rotationEffect(.degrees(startAngle)))
            .padding(lineWidth / 2).frame(width: size, height: size)
    }
}

private struct SettingsThemeArtwork: View {
    @EnvironmentObject private var settings: AppSettings
    let theme: PanelTheme
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 15)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    CodexIconView(size: 12)
                    Text("Codex Meter").font(.system(size: 7, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.clockwise").font(.system(size: 7))
                }.padding(.horizontal, 8).frame(height: 24)
                Rectangle().fill(SettingsPalette.adaptive(0xE3E2EB, 0x494854)).frame(height: 1)
                Group {
                    if theme == .quiet { quietArtwork } else { instrumentArtwork }
                }.padding(.horizontal, 8).padding(.top, 8)
            }
            .frame(width: 180, height: 118, alignment: .topLeading)
            .background(Color.meterCard)
            .clipped()
            .overlay(Rectangle().strokeBorder(SettingsPalette.adaptive(0xE3E2EB, 0x494854), lineWidth: 1))
        }
        .frame(maxWidth: .infinity).frame(height: 132).clipped()
        .background(theme == .quiet ? SettingsPalette.adaptive(0xF1F0FA, 0x343343) : SettingsPalette.adaptive(0xEDF3F1, 0x283A35))
        .foregroundStyle(SettingsPalette.adaptive(0x44444E, 0xE0E0E7))
        .accessibilityHidden(true)
    }
    private var quietArtwork: some View {
        VStack(spacing: 9) {
            HStack(spacing: 16) {
                SettingsQuotaRing(size: 49, lineWidth: 3, fraction: 0.75, startAngle: -135,
                                  strokeColor: PanelTheme.quiet.accent,
                                  trackColor: PanelTheme.quiet.accentSoft)
                    .overlay(HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("64").font(.system(size: 17)); Text("%").font(.system(size: 8))
                    })
                VStack(alignment: .leading, spacing: 7) {
                    Text(SettingsCopy.text("currentQuota", language: settings.language)).font(.system(size: 7, weight: .medium))
                    Capsule().fill(SettingsPalette.adaptive(0xE5E4ED, 0x52505D)).frame(height: 3)
                    Capsule().fill(SettingsPalette.adaptive(0xE5E4ED, 0x52505D)).frame(width: 48, height: 3)
                }
            }
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    VStack(alignment: .leading, spacing: 5) {
                        Rectangle().fill(SettingsPalette.adaptive(0xECEBF3, 0x45444E)).frame(height: 1)
                        Rectangle().fill(SettingsPalette.adaptive(0xE5E4ED, 0x52505D)).frame(width: 32, height: 3)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    private var instrumentArtwork: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("64").font(.system(size: 21, weight: .medium, design: .monospaced))
                    Text("%").font(.system(size: 11, design: .monospaced))
                }
                Spacer()
                Text(SettingsCopy.text("currentQuota", language: settings.language)).font(.system(size: 7))
                    .foregroundStyle(SettingsPalette.adaptive(0x737A78, 0x737A78))
            }
            GeometryReader { proxy in
                Rectangle().fill(PanelTheme.instrument.accentSoft).overlay(alignment: .leading) { Rectangle().fill(PanelTheme.instrument.accent).frame(width: proxy.size.width * 0.64) }
            }.frame(height: 4)
            VStack(spacing: 6) {
                ForEach(0..<3) { _ in
                    VStack(spacing: 4) {
                        Rectangle().fill(SettingsPalette.adaptive(0xE6EBE8, 0xE6EBE8)).frame(height: 1)
                        HStack {
                            Rectangle().fill(SettingsPalette.adaptive(0xE2E8E4, 0xE2E8E4)).frame(width: 39, height: 2)
                            Spacer()
                            Rectangle().fill(SettingsPalette.adaptive(0xE2E8E4, 0xE2E8E4)).frame(width: 37, height: 2)
                        }
                    }
                }
            }
        }
    }
}

private struct SettingsLanguageDialog: View {
    @Environment(\.meterTheme) private var theme
    @Binding var selection: AppLanguage
    let dismiss: () -> Void
    @State private var query = ""
    @FocusState private var isFocused: Bool
    private var filtered: [AppLanguage] {
        let normalized = query.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        return AppLanguage.allCases.filter { language in
            normalized.isEmpty || language.searchTerms.contains { $0.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current).contains(normalized) }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.text(.language, language: selection)).font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 12)).frame(width: 24, height: 24) }
                    .buttonStyle(.plain).foregroundStyle(Color.meterTertiary)
                    .accessibilityLabel(SettingsCopy.text("close", language: selection))
            }.frame(height: 25.5).padding(.bottom, 20)
            TextField("", text: $query,
                      prompt: Text(L10n.text(.searchLanguage, language: selection)).foregroundStyle(Color.meterSecondary))
                .textFieldStyle(.plain).font(.system(size: 13)).padding(.horizontal, 9).frame(height: 33.5)
                .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
                .focused($isFocused)
            ScrollView {
                VStack(spacing: 3) {
                    ForEach(filtered) { language in
                        Button { selection = language; dismiss() } label: {
                            HStack(spacing: 8) {
                                Text(language.nativeName).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(language.rawValue).font(.system(size: 9)).foregroundStyle(Color.meterTertiary)
                                if selection == language { Image(systemName: "checkmark").font(.system(size: 12)).foregroundStyle(theme.accent) }
                            }.padding(.horizontal, 10).frame(height: 42).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if filtered.isEmpty {
                        Text(L10n.text(.noLanguagesFound, language: selection)).font(.system(size: 11))
                            .foregroundStyle(Color.meterSecondary).frame(maxWidth: .infinity).padding(.vertical, 25)
                    }
                }
            }.frame(height: filtered.isEmpty ? 68.15 : min(280, CGFloat(filtered.count * 42 + max(0, filtered.count - 1) * 3))).padding(.top, 13)
        }
        .padding(20).padding(1).frame(width: 340)
        .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.meterBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 30, y: 15)
        .onAppear { isFocused = true }
    }
}
