import SwiftUI

struct UsageDayIndicator: View {
    @EnvironmentObject private var settings: AppSettings
    let date: Date
    var period: UsagePeriod = .day

    var body: some View {
        Text("UTC").meterText(.detail, size: 8)
            .foregroundStyle(Color.meterTertiary)
            .help(UsageDayL10n.help(containing: date, period: period, language: settings.language))
            .accessibilityLabel(UsageDayL10n.title(language: settings.language))
            .accessibilityIdentifier("usage-time-zone")
    }
}
