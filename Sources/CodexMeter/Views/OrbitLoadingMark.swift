import SwiftUI

/// The approved C-shaped mark. Only its outer ring moves; the central scale stays still.
struct OrbitLoadingMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.meterTheme) private var theme
    var isAnimating = true
    @State private var isVisible = false
    @State private var startedAt = Date()
    @State private var pausedElapsed: TimeInterval = 0

    var body: some View {
        Group {
            if isVisible && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimating)) { context in
                    let elapsed = isAnimating ? context.date.timeIntervalSince(startedAt) : pausedElapsed
                    let phase = max(0, elapsed).truncatingRemainder(dividingBy: 2.4) / 2.4
                    let progress = min(1, max(0, (phase - 0.12) / 0.63))
                    mark(rotation: 2 * .pi * (progress * progress * (3 - 2 * progress)),
                         dotOpacity: 0.725 + 0.275 * cos(phase * 2 * .pi))
                }
            } else {
                mark(rotation: 0, dotOpacity: 1)
            }
        }
        .accessibilityHidden(true)
        .onAppear { startedAt = Date(); isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: isAnimating) { _, animating in
            if animating { startedAt = Date().addingTimeInterval(-pausedElapsed) }
            else { pausedElapsed = Date().timeIntervalSince(startedAt) }
        }
    }

    private func mark(rotation: Double, dotOpacity: Double) -> some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 256
            context.translateBy(x: (size.width - 256 * scale) / 2, y: (size.height - 256 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            var ring = context
            ring.translateBy(x: 128, y: 128)
            ring.rotate(by: .radians(rotation))
            ring.translateBy(x: -128, y: -128)
            var arc = Path()
            arc.addArc(center: CGPoint(x: 128, y: 128), radius: 67,
                       startAngle: .degrees(-47.5), endAngle: .degrees(-312.5), clockwise: true)
            ring.stroke(arc, with: .color(theme.accent), style: StrokeStyle(lineWidth: 22, lineCap: .round))
            ring.opacity = dotOpacity
            ring.fill(Path(ellipseIn: CGRect(x: 183, y: 117, width: 22, height: 22)), with: .color(theme.accent))
            var pointer = Path()
            pointer.move(to: CGPoint(x: 116, y: 128)); pointer.addLine(to: CGPoint(x: 146, y: 128))
            context.stroke(pointer, with: .color(theme.accent), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            var ticks = Path()
            for (start, end) in [(CGPoint(x: 128, y: 84), CGPoint(x: 128, y: 90)),
                                 (CGPoint(x: 84, y: 128), CGPoint(x: 90, y: 128)),
                                 (CGPoint(x: 128, y: 166), CGPoint(x: 128, y: 172))] {
                ticks.move(to: start); ticks.addLine(to: end)
            }
            context.stroke(ticks, with: .color(theme.accent.opacity(0.32)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
        }
    }
}

/// Only presentation changes trigger entrance motion, never a data refresh.
struct PanelModuleEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isPresented: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(y: reduceMotion || isPresented ? 0 : 4)
            .animation(reduceMotion ? nil : .easeOut(duration: isPresented ? 0.24 : 0.14)
                .delay(isPresented ? 0.04 + Double(min(index, 2)) * 0.03 : 0), value: isPresented)
    }
}
