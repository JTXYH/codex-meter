import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 2) {
            Image(nsImage: MenuBarProgressRingImage.make(
                remainingPercent: store.menuBarRemainingPercent,
                size: settings.menuBarIconSize,
                colorScheme: colorScheme
            ))
            .renderingMode(.original)

            Text(store.menuBarText)
                .font(Font(NSFont.menuBarFont(ofSize: 0)))
                .monospacedDigit()

            if store.refreshErrorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .padding(.leading, 2)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Codex Meter")
        .accessibilityValue(
            store.menuBarRemainingPercent.map {
                L10n.remaining(Int($0.rounded()), language: settings.language)
            } ?? L10n.text(.notAvailable, language: settings.language)
        )
        .help(
            store.refreshErrorMessage
                ?? L10n.text(.menuBarHelp, language: settings.language)
        )
    }
}
