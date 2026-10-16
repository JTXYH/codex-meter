import SwiftUI

struct FontSettingsView: View {
    @Environment(\.meterTheme) private var theme
    @EnvironmentObject private var settings: AppSettings
    @State private var activeSection: DashboardSection?

    init(showQuotaInitially: Bool = false, contentSectionInitially: DashboardSection? = nil) {
        _activeSection = State(initialValue: showQuotaInitially ? .quota : contentSectionInitially)
    }

    private func text(_ key: FontL10n.Key) -> String { FontL10n.text(key, language: settings.language) }
    private func copy(_ key: String) -> String { SettingsCopy.text(key, language: settings.language) }
    private var sizes: MeterFontSizes { settings.fontSettings.sizes(for: activeSection) }

    var body: some View {
        VStack(spacing: 16) {
            SettingsCard {
                SettingsRow(title: text(.scope), detail: copy("scopeDetail")) {
                    SettingsSelect(title: text(.scope), selection: $activeSection,
                                   options: [nil] + DashboardSection.allCases.map(Optional.some)) { section in
                        section.map { copy(SettingsCopy.sectionKey($0)) } ?? text(.allContent)
                    }
                    .accessibilityIdentifier("font-content-scope")
                }
                VStack(spacing: 12) {
                    ForEach(MeterTextRole.allCases) { role in fontControl(role) }
                }.padding(.horizontal, 18).padding(.top, 3).padding(.bottom, 17)
                SettingsDivider()
                HStack {
                    Button(text(.reset)) { settings.fontSettings.reset(section: activeSection) }
                        .buttonStyle(SettingsButtonStyle(kind: .link)).accessibilityIdentifier("font-reset")
                    Spacer()
                    if let activeSection, activeSection != .quota {
                        Button(copy("fontApply")) {
                            settings.fontSettings.applyToContentCards(from: activeSection)
                            self.activeSection = nil
                        }.buttonStyle(SettingsButtonStyle()).accessibilityIdentifier("font-apply-content")
                    }
                }.padding(.horizontal, 18).frame(minHeight: 52)
            }
            Text(text(.preview)).font(.system(size: 10)).tracking(0.5)
                .foregroundStyle(Color.meterTertiary).padding(.top, 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(theme.accent).frame(width: 6, height: 6)
                    Text(copy(activeSection == .quota ? "currentQuota" : "yesterdayUsage"))
                        .font(.system(size: sizes.title, weight: .semibold)).frame(minHeight: sizes.title * 1.5)
                }
                Text(activeSection == .quota ? "64%" : previewTokens)
                    .font(.system(size: sizes.value, weight: .medium)).monospacedDigit().tracking(-0.5)
                    .frame(minHeight: sizes.value * 1.5)
                    .padding(.top, 20)
                Text(previewDetail).font(.system(size: sizes.detail)).foregroundStyle(Color.meterSecondary)
                    .frame(minHeight: sizes.detail * 1.5).padding(.top, 8)
            }
            .padding(.vertical, 22).padding(.horizontal, 24).padding(1).frame(width: 350, alignment: .leading)
            .background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.meterBorder, lineWidth: 1))
            .accessibilityIdentifier("font-preview")
        }
    }

    private var previewTokens: String {
        switch settings.language {
        case .simplifiedChinese: "7 亿 6 千万"
        case .traditionalChinese: "7 億 6 千萬"
        default: "760M"
        }
    }
    private var previewDetail: String {
        if activeSection == .quota {
            return copy("fontQuotaDetail")
        }
        return copy("fontDateDetail")
    }

    private func fontControl(_ role: MeterTextRole) -> some View {
        let title = role == .detail ? copy("fontDetail") : FontL10n.role(role, language: settings.language)
        let size = Binding<Double>(
            get: { settings.fontSettings.sizes(for: activeSection)[role] },
            set: { settings.fontSettings.setSize($0, role: role, section: activeSection) }
        )
        return HStack(spacing: 12) {
            Text(title).font(.system(size: 11)).frame(width: 42, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.8)
            SettingsSlider(value: size, range: role.range, step: 0.5, label: title)
                .accessibilityIdentifier("font-\(role.rawValue)-slider")
            TextField(title, value: size, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.plain).font(.system(size: 11)).monospacedDigit().multilineTextAlignment(.center)
                .frame(width: 54, height: 32)
                .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1))
                .accessibilityIdentifier("font-\(role.rawValue)-input")
            Text("pt").font(.system(size: 10)).foregroundStyle(Color.meterSecondary).frame(width: 15)
        }
    }
}
