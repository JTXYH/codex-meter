import AppKit
import SwiftUI

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

    static let menuBarTemplateImage: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            context.setFillColor(NSColor.black.cgColor)
            context.addPath(
                CGPath(
                    roundedRect: CGRect(x: 1, y: 1, width: 16, height: 16),
                    cornerWidth: 4.2,
                    cornerHeight: 4.2,
                    transform: nil
                )
            )
            context.fillPath()

            // A fully transparent terminal mark keeps maximum contrast at menu-bar size.
            context.setBlendMode(.clear)
            context.setStrokeColor(NSColor.clear.cgColor)
            context.setLineWidth(2.35)
            context.setLineCap(.round)
            context.setLineJoin(.round)

            context.beginPath()
            context.move(to: CGPoint(x: 5.1, y: 12.2))
            context.addLine(to: CGPoint(x: 8.2, y: 9.0))
            context.addLine(to: CGPoint(x: 5.1, y: 5.8))
            context.strokePath()

            context.beginPath()
            context.move(to: CGPoint(x: 9.6, y: 5.9))
            context.addLine(to: CGPoint(x: 13.0, y: 5.9))
            context.strokePath()
            context.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        return image
    }()
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

struct MenuBarCodexIconView: View {
    var body: some View {
        Image(nsImage: CodexIconResource.menuBarTemplateImage)
            .renderingMode(.template)
            .foregroundStyle(.primary)
            .frame(width: 18, height: 18)
            .fixedSize()
            .accessibilityLabel("Codex Meter")
    }
}

struct PanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
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
                            .stroke(Color.meterBorder, lineWidth: 1)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.meterAccent)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.meterTrack, style: StrokeStyle(lineWidth: 13, lineCap: .round))
            Circle()
                .trim(from: 0, to: min(max(remainingPercent / 100, 0), 1))
                .stroke(
                    AngularGradient(
                        colors: [.meterCyan, .meterAccent, .meterAccentSoft, .meterCyan],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.meterAccent.opacity(0.16), radius: 8)

            VStack(spacing: 1) {
                Text("\(Int(remainingPercent.rounded()))%")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.meterSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 118, height: 118)
        .accessibilityLabel(
            L10n.remaining(Int(remainingPercent.rounded()), language: settings.language)
        )
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
