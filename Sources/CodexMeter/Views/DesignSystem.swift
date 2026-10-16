import AppKit
import SwiftUI

private struct MeterThemeKey: EnvironmentKey {
    static let defaultValue: PanelTheme = .quiet
}

private struct MeterFontSizesKey: EnvironmentKey {
    static let defaultValue = MeterFontSizes()
}

private struct MeterCardHasBottomBorderKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var meterTheme: PanelTheme {
        get { self[MeterThemeKey.self] }
        set { self[MeterThemeKey.self] = newValue }
    }

    var meterFontSizes: MeterFontSizes {
        get { self[MeterFontSizesKey.self] }
        set { self[MeterFontSizesKey.self] = newValue }
    }

    var meterCardHasBottomBorder: Bool {
        get { self[MeterCardHasBottomBorderKey.self] }
        set { self[MeterCardHasBottomBorderKey.self] = newValue }
    }
}

private struct MeterTextModifier: ViewModifier {
    @Environment(\.meterFontSizes) private var sizes
    @Environment(\.meterTheme) private var theme
    let role: MeterTextRole
    var size: CGFloat?
    var weight: Font.Weight = .regular

    func body(content: Content) -> some View {
        let resolvedSize = size.map { $0 * CGFloat(sizes[role] / role.defaultSize) } ?? CGFloat(sizes[role])
        // The approved web reference falls back to Menlo for its monospaced numbers.
        if role == .value && theme.isInstrument {
            content.font(.custom(weight == .regular || weight == .light ? "Menlo-Regular" : "Menlo-Bold", size: resolvedSize))
        } else if role == .value {
            content.font(.system(size: resolvedSize, weight: weight)).monospacedDigit()
        } else {
            content.font(.system(size: resolvedSize, weight: weight))
        }
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
    func meterText(_ role: MeterTextRole, size: CGFloat? = nil, weight: Font.Weight = .regular) -> some View {
        modifier(MeterTextModifier(role: role, size: size, weight: weight))
    }

    func meterTypography(for section: DashboardSection? = nil) -> some View {
        modifier(MeterTypographyScope(section: section))
    }
}

private func adaptiveMeterColor(light: UInt32, dark: UInt32) -> Color {
    func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    return Color(nsColor: NSColor(name: nil) { appearance in
        color(appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light)
    })
}

extension Color {
    static let meterAccent = adaptiveMeterColor(light: 0x6262df, dark: 0xa5a2ff)
    static let meterAccentSoft = adaptiveMeterColor(light: 0xefeffc, dark: 0x36334e)
    static let meterInstrumentAccent = adaptiveMeterColor(light: 0x167d75, dark: 0x76c5b4)
    static let meterInstrumentAccentSoft = adaptiveMeterColor(light: 0xe7f3ef, dark: 0x283d38)
    static let meterSuccess = adaptiveMeterColor(light: 0x368b73, dark: 0x72baa4)
    static let meterDanger = adaptiveMeterColor(light: 0xc45447, dark: 0xed9286)
    static let meterPanel = adaptiveMeterColor(light: 0xf4f4f7, dark: 0x1d1d23)
    static let meterCard = adaptiveMeterColor(light: 0xffffff, dark: 0x24242b)
    static let meterPrimary = adaptiveMeterColor(light: 0x25252d, dark: 0xededf4)
    static let meterSecondary = adaptiveMeterColor(light: 0x72727d, dark: 0xa2a2af)
    static let meterTertiary = adaptiveMeterColor(light: 0x9999a4, dark: 0x81818f)
    static let meterBorder = adaptiveMeterColor(light: 0xe8e8ed, dark: 0x35353e)
    static let meterTrack = meterBorder
    static let meterControl = meterPanel
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
                    .interpolation(.high)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                OrbitLoadingMark(isAnimating: false)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Codex Meter")
    }
}

struct PanelCard<Content: View>: View {
    @Environment(\.meterTheme) private var theme
    @Environment(\.meterCardHasBottomBorder) private var hasBottomBorder
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.cardPadding)
            .padding(.bottom, hasBottomBorder ? 1 : 0)
            .background(Color.meterCard)
            .overlay(alignment: .bottom) {
                if hasBottomBorder {
                    Color.meterBorder.frame(height: 1).allowsHitTesting(false)
                }
            }
    }
}

struct QuotaRingStroke: View {
    let remainingPercent: Double?
    let lineWidth: CGFloat
    let colors: [Color]

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
