#!/usr/bin/env swift

import AppKit
import Foundation
import WebKit

// The approved vector is the only drawing source. WebKit renders its SVG filters
// and gradients onto an alpha-preserving canvas; iconutil packages the PNG sizes.
private let projectURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
private let sourceURL = projectURL.appendingPathComponent("Resources/AppIcon.svg")
private let resourcesURL = projectURL.appendingPathComponent("Resources", isDirectory: true)
private let inlineIconURL = projectURL.appendingPathComponent("Sources/CodexMeter/Resources/CodexIcon.png")
private let iconsetURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("CodexMeter-\(UUID().uuidString).iconset", isDirectory: true)

private func iconError(_ message: String) -> NSError {
    NSError(domain: "CodexMeterIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

@MainActor
private final class SVGRenderer: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView?
    private var result: Result<[Int: Data], Error>?

    func render(_ svg: Data) throws -> [Int: Data] {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "icons")
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024), configuration: configuration)
        self.webView = webView
        webView.navigationDelegate = self
        defer {
            configuration.userContentController.removeScriptMessageHandler(forName: "icons")
            webView.stopLoading()
            self.webView = nil
        }
        webView.loadHTMLString("""
        <!doctype html><meta charset="utf-8"><script>
        (async () => {
          try {
            const source = atob('\(svg.base64EncodedString())');
            const images = {};
            for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
              // Give filters their final pixel viewport instead of scaling a small raster layer.
              const vector = new DOMParser().parseFromString(source, 'image/svg+xml').documentElement;
              vector.setAttribute('width', size);
              vector.setAttribute('height', size);
              const image = new Image();
              await new Promise((resolve, reject) => {
                image.onload = resolve;
                image.onerror = () => reject(new Error('Unable to render the approved SVG'));
                image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(new XMLSerializer().serializeToString(vector));
              });
              const canvas = document.createElement('canvas');
              canvas.width = canvas.height = size;
              canvas.getContext('2d').drawImage(image, 0, 0, size, size);
              images[size] = canvas.toDataURL('image/png').split(',')[1];
            }
            window.webkit.messageHandlers.icons.postMessage({ images });
          } catch (error) {
            window.webkit.messageHandlers.icons.postMessage({ error: String(error) });
          }
        })();
        </script>
        """, baseURL: nil)
        let deadline = Date().addingTimeInterval(30)
        while result == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        guard let result else { throw iconError("SVG rendering timed out") }
        return try result.get()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        if let error = body["error"] as? String { result = .failure(iconError(error)); return }
        guard let encoded = body["images"] as? [String: String] else { return }
        var images: [Int: Data] = [:]
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            guard let value = encoded[String(size)], let data = Data(base64Encoded: value),
                  let bitmap = NSBitmapImageRep(data: data), bitmap.hasAlpha,
                  bitmap.pixelsWide == size, bitmap.pixelsHigh == size,
                  bitmap.colorAt(x: 0, y: 0)?.alphaComponent == 0 else {
                result = .failure(iconError("Invalid size or missing transparency at \(size)px")); return
            }
            images[size] = data
        }
        result = .success(images)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        result = .failure(error)
    }
}

NSApplication.shared.setActivationPolicy(.prohibited)
let images = try MainActor.assumeIsolated { try SVGRenderer().render(Data(contentsOf: sourceURL)) }
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetURL) }
let variants = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]
for (name, size) in variants {
    try images[size]!.write(to: iconsetURL.appendingPathComponent(name), options: .atomic)
}
try images[1024]!.write(to: resourcesURL.appendingPathComponent("AppIcon.png"), options: .atomic)
try images[256]!.write(to: inlineIconURL, options: .atomic)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconsetURL.path, "--output", resourcesURL.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { throw iconError("iconutil failed: \(iconutil.terminationStatus)") }
print("Generated AppIcon.png (1024px), AppIcon.icns (16–1024px), and CodexIcon.png (256px) from \(sourceURL.path)")
