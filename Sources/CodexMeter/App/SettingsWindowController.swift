import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        let settingsWindow = window ?? makeWindow()

        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.orderFrontRegardless()
        settingsWindow.makeKey()
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsPanelView()
            .environmentObject(AppSettings.shared)
            .environmentObject(UsageStore.shared)
            .environmentObject(UpdateController.shared)
            .environmentObject(QuotaBackgroundStore.shared)

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 552),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Codex Meter"
        settingsWindow.contentView = NSHostingView(rootView: rootView)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.collectionBehavior = [.moveToActiveSpace]
        settingsWindow.setFrameAutosaveName("CodexMeter.SettingsWindow")
        settingsWindow.setContentSize(NSSize(width: 760, height: 552))
        settingsWindow.center()
        window = settingsWindow
        return settingsWindow
    }
}
