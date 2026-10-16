import AppKit
import Testing
@testable import CodexMeter

struct MenuBarProgressRingTests {
    @Test @MainActor
    func rendersColoredQuotaRingAtTheSelectedSize() throws {
        for size: CGFloat in [12, 18, 22] {
            let image = MenuBarProgressRingImage.make(remainingPercent: 49, size: size)
            #expect(!image.isTemplate)
            #expect(image.size == NSSize(width: size, height: size))
            let bitmap = try bitmap(image)

            // 49% starts at noon and runs clockwise: right is filled, left is track.
            let filled = try edgeColor(bitmap, right: true)
            #expect(filled.alphaComponent > 0.8)
            #expect(filled.blueComponent > filled.greenComponent)
            let track = try edgeColor(bitmap, right: false)
            #expect(track.alphaComponent > 0.8)
            #expect(abs(track.blueComponent - track.greenComponent) < 0.1)
            #expect(try alpha(bitmap, x: 0.5, y: 0.5) == 0)
        }

        let empty = try bitmap(MenuBarProgressRingImage.make(remainingPercent: 0, size: 22))
        let full = try bitmap(MenuBarProgressRingImage.make(remainingPercent: 100, size: 22))
        for right in [false, true] {
            let track = try edgeColor(empty, right: right)
            #expect(track.alphaComponent > 0.8)
            #expect(abs(track.blueComponent - track.greenComponent) < 0.1)
            #expect(try edgeColor(full, right: right).alphaComponent > 0.8)
        }

        let dataTheme = try bitmap(MenuBarProgressRingImage.make(remainingPercent: 49, size: 22, theme: .instrument))
        let dataFill = try edgeColor(dataTheme, right: true)
        #expect(dataFill.greenComponent > dataFill.redComponent)
        let warning = try bitmap(MenuBarProgressRingImage.make(remainingPercent: 20, size: 22))
        let warningColor = try color(warning, x: 0.80, y: 0.18)
        #expect(warningColor.redComponent > warningColor.blueComponent)

        // The approved track is an opaque neutral color; only the ring interior
        // and the outside of the circular stroke are transparent.
        // The outside of a true circle stays transparent near a diagonal corner.
        let largeRing = try bitmap(MenuBarProgressRingImage.make(remainingPercent: 100, size: 64))
        #expect(try alpha(largeRing, x: 0.12, y: 0.12) < 0.05)
    }

    private func bitmap(_ image: NSImage) throws -> NSBitmapImageRep {
        let tiff = try #require(image.tiffRepresentation)
        return try #require(NSBitmapImageRep(data: tiff))
    }

    private func alpha(_ bitmap: NSBitmapImageRep, x: Double, y: Double) throws -> CGFloat {
        try color(bitmap, x: x, y: y).alphaComponent
    }

    private func color(_ bitmap: NSBitmapImageRep, x: Double, y: Double) throws -> NSColor {
        let color = try #require(bitmap.colorAt(
            x: Int(x * Double(bitmap.pixelsWide)),
            y: Int(y * Double(bitmap.pixelsHigh))
        ))
        return try #require(color.usingColorSpace(.deviceRGB))
    }

    private func edgeColor(_ bitmap: NSBitmapImageRep, right: Bool) throws -> NSColor {
        let xRange = right
            ? (Int(Double(bitmap.pixelsWide) * 0.8)..<bitmap.pixelsWide)
            : (0..<Int(Double(bitmap.pixelsWide) * 0.2))
        let yRange = Int(Double(bitmap.pixelsHigh) * 0.45)..<Int(Double(bitmap.pixelsHigh) * 0.55)
        let colors = xRange.flatMap { x in
            yRange.compactMap { y in
                bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            }
        }
        return try #require(colors.max { $0.alphaComponent < $1.alphaComponent })
    }
}
