import AppKit
import CoreText
import SwiftUI

struct PacificClockCard: View {
    var isPresented = true
    /// A fixed instant for design and typography previews; the dashboard uses the system clock.
    var fixedDate: Date?

    var body: some View {
        Group {
            if let fixedDate {
                PacificClockContent(date: fixedDate)
            } else if isPresented {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    // Read wall time on each tick so sleep and clock adjustments cannot accumulate drift.
                    PacificClockContent(date: .now)
                }
            } else {
                PacificClockContent(date: .now)
            }
        }
        .accessibilityIdentifier("pacific-clock-card")
    }
}

private struct PacificClockContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.meterFontSizes) private var sizes
    let date: Date

    private var title: String { SettingsCopy.text("pacificClock", language: settings.language) }
    private var titleScale: CGFloat { CGFloat(sizes.title / MeterTextRole.title.defaultSize) }
    private var valueScale: CGFloat { CGFloat(sizes.value / MeterTextRole.value.defaultSize) }
    private var detailScale: CGFloat { CGFloat(sizes.detail / MeterTextRole.detail.defaultSize) }
    private var clockSize: CGFloat { (theme.isInstrument ? 30 : 32) * valueScale }

    var body: some View {
        let readout = PacificClockReadout(date: date, language: settings.language)
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        heading
                        Spacer(minLength: 8)
                        dateLabel(readout.pacificDate)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        heading
                        dateLabel(readout.pacificDate)
                    }
                }
                .frame(minHeight: 20 * titleScale, alignment: .leading)

                clockText(readout.pacificTime)
                    .meterText(.value, size: theme.isInstrument ? 30 : 32, weight: .medium)
                    .fixedSize()
                    .frame(minHeight: 41 * valueScale, alignment: .leading)
                    .offset(x: leadingOffset(for: readout.pacificTime))
                    .padding(.top, 9)
                    .accessibilityIdentifier("pacific-clock-time")

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        localLabel
                        localTime(readout.localTime)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        localLabel
                        localTime(readout.localTime)
                    }
                }
                .frame(minHeight: 16 * detailScale, alignment: .leading)
                .padding(.top, 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Expose one complete readout on demand, without announcing every second.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(readout.accessibilityValue)
    }

    private var heading: some View {
        Text(title).meterText(.title, size: 13, weight: .semibold).fixedSize()
    }
    private func dateLabel(_ value: String) -> some View {
        Text(value).meterText(.detail, size: 11).monospacedDigit()
            .foregroundStyle(Color.meterSecondary).fixedSize()
    }
    private var localLabel: some View {
        Text(SettingsCopy.text("localTime", language: settings.language))
            .meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary).fixedSize()
    }
    private func localTime(_ value: String) -> some View {
        Text(value).meterText(.detail, size: 11).monospacedDigit()
            .foregroundStyle(Color.meterSecondary).fixedSize()
    }
    private func clockText(_ time: String) -> Text {
        let parts = time.split(separator: ":")
        return Text(String(parts[0])) + Text(":").foregroundColor(.meterTertiary)
            + Text(String(parts[1])) + Text(":").foregroundColor(.meterTertiary)
            + Text(String(parts[2]))
    }

    /// Align the visible glyph edges, accounting for the first digit, font and text-size settings.
    private func leadingOffset(for time: String) -> CGFloat {
        func inkLeft(_ text: String, font: NSFont) -> CGFloat {
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: String(text.prefix(1)), attributes: [.font: font]))
            return CTLineGetBoundsWithOptions(line, .useGlyphPathBounds).minX
        }
        let valueFont = theme.isInstrument
            ? NSFont(name: "Menlo-Bold", size: clockSize) ?? .monospacedSystemFont(ofSize: clockSize, weight: .bold)
            : NSFont.monospacedDigitSystemFont(ofSize: clockSize, weight: .medium)
        return inkLeft(title, font: .systemFont(ofSize: 13 * titleScale, weight: .semibold))
            - inkLeft(time, font: valueFont)
    }
}
