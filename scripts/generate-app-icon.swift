#!/usr/bin/env swift

import AppKit
import Foundation

private let fileManager = FileManager.default
private let projectURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
private let resourcesURL = projectURL.appendingPathComponent("Resources", isDirectory: true)
private let iconsetURL = fileManager.temporaryDirectory
    .appendingPathComponent("CodexMeter-\(UUID().uuidString).iconset", isDirectory: true)
private let outputURL = resourcesURL.appendingPathComponent("AppIcon.icns")
private let previewURL = resourcesURL.appendingPathComponent("AppIcon.png")

private func meterGlyphPath(in rect: CGRect) -> CGPath {
    let scaleX = rect.width / 16
    let scaleY = rect.height / 16
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * scaleX, y: rect.maxY - y * scaleY)
    }

    let path = CGMutablePath()
    path.move(to: point(2.2, 2.4))
    path.addLine(to: point(8.4, 7.4))
    path.addQuadCurve(to: point(8.4, 8.6), control: point(9.1, 8.0))
    path.addLine(to: point(2.2, 13.6))
    path.addLine(to: point(4.8, 13.6))
    path.addLine(to: point(11.3, 8.6))
    path.addQuadCurve(to: point(11.3, 7.4), control: point(12.0, 8.0))
    path.addLine(to: point(4.8, 2.4))
    path.closeSubpath()

    let underscore = CGRect(
        x: rect.minX + 8.5 * scaleX,
        y: rect.maxY - 13.6 * scaleY,
        width: 5.3 * scaleX,
        height: 1.9 * scaleY
    )
    path.addRoundedRect(
        in: underscore,
        cornerWidth: 0.95 * scaleX,
        cornerHeight: 0.95 * scaleY
    )
    return path
}

private func renderIcon(pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CodexMeterIcon", code: 1)
    }

    let size = CGFloat(pixelSize)
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let tile = bounds.insetBy(dx: size * 0.07, dy: size * 0.07)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.clear(bounds)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.set()

    let tilePath = CGPath(
        roundedRect: tile,
        cornerWidth: tile.width * 0.22,
        cornerHeight: tile.height * 0.22,
        transform: nil
    )
    context.addPath(tilePath)
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    context.addPath(tilePath)
    context.setStrokeColor(NSColor.black.withAlphaComponent(0.15).cgColor)
    context.setLineWidth(max(1, size * 0.008))
    context.strokePath()

    let glyphRect = tile.insetBy(dx: tile.width * 0.15, dy: tile.height * 0.15)
    context.addPath(meterGlyphPath(in: glyphRect))
    context.setFillColor(NSColor.black.cgColor)
    context.fillPath()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CodexMeterIcon", code: 2)
    }
    return data
}

try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetURL) }

let variants: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    let data = try renderIcon(pixelSize: variant.pixels)
    try data.write(to: iconsetURL.appendingPathComponent(variant.filename), options: .atomic)
}

try renderIcon(pixelSize: 1024).write(to: previewURL, options: .atomic)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconsetURL.path, "--output", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw NSError(domain: "CodexMeterIcon", code: Int(iconutil.terminationStatus))
}

print(outputURL.path)
