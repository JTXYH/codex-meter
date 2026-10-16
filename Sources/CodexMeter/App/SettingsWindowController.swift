import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let navigation = SettingsNavigationState()

    private init() {}

    func show(section: SettingsSection? = nil) {
        MenuBarPanelController.shared.closePanel()
        if let section { navigation.requestedSection = section }
        let settingsWindow = window ?? makeWindow()

        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow.orderFrontRegardless()
        settingsWindow.makeKey()
    }

    func showMainPanel() {
        MenuBarPanelController.shared.showPanel()
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsPanelView(navigation: navigation)
            .environmentObject(AppSettings.shared)
            .environmentObject(UsageStore.shared)
            .environmentObject(UpdateController.shared)

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Codex Meter"
        settingsWindow.contentView = NSHostingView(rootView: rootView)
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.collectionBehavior = [.moveToActiveSpace]
        settingsWindow.setFrameAutosaveName("CodexMeter.SettingsWindow")
        settingsWindow.setContentSize(NSSize(width: 820, height: 620))
        settingsWindow.center()
        window = settingsWindow
        return settingsWindow
    }
}
