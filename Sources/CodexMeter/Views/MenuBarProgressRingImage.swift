import AppKit
import SwiftUI

@MainActor
enum MenuBarProgressRingImage {
    static func make(
        remainingPercent: Double?,
        size: CGFloat,
        colorScheme: ColorScheme = .light
    ) -> NSImage {
        let colors = remainingPercent.map {
            QuotaVisualState(remainingPercent: $0).ringColors
        } ?? [.meterAccent]
        let lineWidth = size / 7
        let renderer = ImageRenderer(
            content: QuotaRingStroke(
                remainingPercent: remainingPercent,
                lineWidth: lineWidth,
                colors: colors
            )
            // Keep the full stroke inside the bitmap so its edges stay circular.
            .frame(width: size - lineWidth, height: size - lineWidth)
            .frame(width: size, height: size)
            .environment(\.colorScheme, colorScheme)
        )
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        let image = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = false
        return image
    }
}
