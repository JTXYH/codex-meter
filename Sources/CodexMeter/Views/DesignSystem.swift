import AppKit
import SwiftUI

private struct MeterFontSizesKey: EnvironmentKey {
    static let defaultValue = MeterFontSizes()
}

extension EnvironmentValues {
    var meterFontSizes: MeterFontSizes {
        get { self[MeterFontSizesKey.self] }
        set { self[MeterFontSizesKey.self] = newValue }
    }
}

private struct MeterTextModifier: ViewModifier {
    @Environment(\.meterFontSizes) private var sizes
    let role: MeterTextRole

    func body(content: Content) -> some View {
        content.font(.meter(size: CGFloat(sizes[role])))
    }
}

private struct MeterTypographyScope: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    let section: DashboardSection?

    func body(content: Content) -> some View {
        content.environment(\.meterFontSizes, settings.fontSettings.sizes(for: section))
    }
}

extension View {
    func meterText(_ role: MeterTextRole) -> some View {
        modifier(MeterTextModifier(role: role))
    }

    func meterTypography(for section: DashboardSection? = nil) -> some View {
        modifier(MeterTypographyScope(section: section))
    }
}

extension Font {
    /// SF system text with the platform CJK fallback, matching the HTML design's
    /// -apple-system / SF Pro Text / PingFang stack throughout the application.
    static func meter(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

}

private func adaptiveMeterColor(light: NSColor, dark: NSColor) -> Color {
    let color = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }
    return Color(nsColor: color)
}

extension Color {
    static let meterAccent = adaptiveMeterColor(
        light: NSColor(red: 0.34, green: 0.39, blue: 0.96, alpha: 1),
        dark: NSColor(red: 0.47, green: 0.55, blue: 1.0, alpha: 1)
    )
    static let meterAccentSoft = adaptiveMeterColor(
        light: NSColor(red: 0.68, green: 0.63, blue: 1.0, alpha: 1),
        dark: NSColor(red: 0.66, green: 0.62, blue: 1.0, alpha: 1)
    )
    static let meterCyan = adaptiveMeterColor(
        light: NSColor(red: 0.25, green: 0.58, blue: 0.98, alpha: 1),
        dark: NSColor(red: 0.34, green: 0.67, blue: 1.0, alpha: 1)
    )
    static let meterSuccess = adaptiveMeterColor(
        light: NSColor(red: 0.10, green: 0.67, blue: 0.46, alpha: 1),
        dark: NSColor(red: 0.21, green: 0.79, blue: 0.57, alpha: 1)
    )
    static let meterPanelTop = adaptiveMeterColor(
        light: NSColor(red: 0.985, green: 0.985, blue: 0.978, alpha: 1),
        dark: NSColor(red: 0.12, green: 0.125, blue: 0.14, alpha: 1)
    )
    static let meterPanel = adaptiveMeterColor(
        light: NSColor(red: 0.965, green: 0.964, blue: 0.952, alpha: 1),
        dark: NSColor(red: 0.085, green: 0.09, blue: 0.105, alpha: 1)
    )
    static let meterPanelBottom = adaptiveMeterColor(
        light: NSColor(red: 0.975, green: 0.974, blue: 0.965, alpha: 1),
        dark: NSColor(red: 0.07, green: 0.075, blue: 0.09, alpha: 1)
    )
    static let meterCard = adaptiveMeterColor(
        light: .white,
        dark: NSColor(red: 0.14, green: 0.145, blue: 0.165, alpha: 1)
    )
    static let meterPrimary = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.88),
        dark: NSColor.white.withAlphaComponent(0.92)
    )
    static let meterSecondary = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.53),
        dark: NSColor.white.withAlphaComponent(0.62)
    )
    static let meterTertiary = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.34),
        dark: NSColor.white.withAlphaComponent(0.40)
    )
    static let meterBorder = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.075),
        dark: NSColor.white.withAlphaComponent(0.10)
    )
    static let meterTrack = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.07),
        dark: NSColor.white.withAlphaComponent(0.105)
    )
    static let meterControl = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.045),
        dark: NSColor.white.withAlphaComponent(0.085)
    )
    static let meterFooter = adaptiveMeterColor(
        light: NSColor.white.withAlphaComponent(0.97),
        dark: NSColor(red: 0.115, green: 0.12, blue: 0.14, alpha: 0.98)
    )
    static let meterShadow = adaptiveMeterColor(
        light: NSColor.black.withAlphaComponent(0.035),
        dark: NSColor.black.withAlphaComponent(0.30)
    )
}

private enum CodexIconResource {
    private static let url: URL? = {
        let packagedBundle = Bundle.main.resourceURL
            .map { $0.appendingPathComponent("CodexMeter_CodexMeter.bundle") }
            .flatMap(Bundle.init(url:))
        let resources = packagedBundle ?? Bundle.module
        return resources.url(forResource: "CodexIcon", withExtension: "png")
    }()

    static let image: NSImage? = url.flatMap(NSImage.init(contentsOf:))
}

struct CodexIconView: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = CodexIconResource.image {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                Image(systemName: "terminal.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.meterAccent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Codex")
    }
}

struct PanelCard<Content: View>: View {
    let borderColor: Color
    @ViewBuilder let content: Content

    init(
        borderColor: Color = .meterBorder,
        @ViewBuilder content: () -> Content
    ) {
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.meterCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
            )
            .shadow(color: Color.meterShadow, radius: 12, y: 3)
    }
}

struct SectionTitle: View {
    let icon: String
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.meter(size: 14))
                .foregroundStyle(Color.meterAccent)
                .frame(width: 20)
            Text(title)
                .meterText(.title)
            Spacer()
            if let trailing {
                Text(trailing)
                    .meterText(.detail)
                    .foregroundStyle(Color.meterSecondary)
            }
        }
    }
}

struct MeterProgressBar: View {
    let progress: Double
    var color: Color = .meterAccent
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.meterTrack)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.72), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.55), value: progress)
    }
}

struct ProgressRing: View {
    @EnvironmentObject private var settings: AppSettings

    let remainingPercent: Double
    let subtitle: String
    var colors: [Color] = [
        .meterCyan,
        .meterAccent,
        .meterAccentSoft,
        .meterCyan,
    ]

    var body: some View {
        ZStack {
            QuotaRingStroke(
                remainingPercent: remainingPercent,
                lineWidth: 13,
                colors: colors,
                shadowRadius: 8
            )

            VStack(spacing: 1) {
                Text("\(Int(remainingPercent.rounded()))%")
                    .meterText(.value)
                    .monospacedDigit()
                Text(subtitle)
                    .meterText(.detail)
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 128, height: 128)
        .accessibilityLabel(
            L10n.remaining(Int(remainingPercent.rounded()), language: settings.language)
        )
    }
}

struct QuotaRingStroke: View {
    let remainingPercent: Double?
    let lineWidth: CGFloat
    let colors: [Color]
    var shadowRadius: CGFloat = 0

    private var progress: Double? {
        remainingPercent.flatMap { $0.isFinite ? min(max($0 / 100, 0), 1) : nil }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.meterTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if let progress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: colors,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(
                        color: (colors.last ?? .meterAccent).opacity(shadowRadius > 0 ? 0.16 : 0),
                        radius: shadowRadius
                    )
            } else {
                Circle()
                    .stroke(
                        Color.meterTertiary,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            dash: [lineWidth, lineWidth]
                        )
                    )
            }
        }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: 4)
    }
}
