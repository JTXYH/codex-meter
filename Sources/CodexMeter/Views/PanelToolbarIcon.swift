import SwiftUI

/// Toolbar symbols retain their natural proportions at the requested size.
struct PanelToolbarIcon: View {
    enum Kind { case refresh, settings, power }
    let kind: Kind
    var size: CGFloat = 16

    var body: some View {
        Group {
            switch kind {
            case .settings:
                Image(systemName: "gearshape")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
            case .refresh:
                outline(refreshPath)
            case .power:
                outline(powerPath)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func outline(_ path: Path) -> some View {
        path.stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            .frame(width: 24, height: 24)
            .scaleEffect(size / 24)
            .frame(width: size, height: size)
    }

    private var refreshPath: Path {
        var path = Path()
        path.addArc(center: CGPoint(x: 12.643, y: 12.857), radius: 8,
                    startAngle: .degrees(-37.384), endAngle: .degrees(23.132), clockwise: true)
        path.move(to: CGPoint(x: 19, y: 3))
        path.addLine(to: CGPoint(x: 19, y: 8))
        path.addLine(to: CGPoint(x: 14, y: 8))
        return path
    }

    private var powerPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 12, y: 3))
        path.addLine(to: CGPoint(x: 12, y: 12))
        path.move(to: CGPoint(x: 6, y: 6))
        path.addArc(center: CGPoint(x: 12, y: 11.291502622), radius: 8,
                    startAngle: .degrees(-138.59037789), endAngle: .degrees(-41.40962211), clockwise: true)
        return path
    }
}
