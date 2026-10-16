import SwiftUI

struct QuotaStatusSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(text(.title)).font(.system(size: 13, weight: .semibold))
                    Text(text(.hint)).font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(QuotaStatus.allCases) { status in
                    HStack(spacing: 12) {
                        Text(status.defaultText(language: settings.language)).font(.system(size: 11))
                            .frame(width: 140, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                        TextField(status.defaultText(language: settings.language), text: Binding(
                            get: { settings.quotaStatusMessages[status] },
                            set: { settings.quotaStatusMessages[status] = $0 }
                        ))
                        .textFieldStyle(.plain).font(.system(size: 11))
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Color.meterBorder, lineWidth: 1) }
                        .accessibilityLabel(status.defaultText(language: settings.language))
                        .accessibilityIdentifier("quota-status-\(status.rawValue)")
                    }
                }
                Button(text(.restore)) { settings.quotaStatusMessages = QuotaStatusMessages() }
                    .buttonStyle(SettingsButtonStyle(kind: .link))
                    .foregroundStyle(theme.accent)
                    .accessibilityIdentifier("quota-status-restore")
            }.padding(18)
        }
        .accessibilityIdentifier("quota-status-settings")
    }

    private func text(_ key: QuotaStatusSettingsL10n.Key) -> String {
        QuotaStatusSettingsL10n.text(key, language: settings.language)
    }
}
