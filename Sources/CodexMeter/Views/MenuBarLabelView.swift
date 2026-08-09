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
        }
        .help(L10n.text(.menuBarHelp, language: settings.language))
    }
}
