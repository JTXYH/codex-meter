import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            MenuBarCodexIconView()
            Text(store.menuBarText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if store.refreshErrorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.orange)
            }
        }
        .help(
            store.refreshErrorMessage
                ?? L10n.text(.menuBarHelp, language: settings.language)
        )
    }
}
