import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var languageSubscription: AnyCancellable?
#if DEBUG
    private var previewWindow: NSWindow?
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppSettings.shared.applyAppearance()
        languageSubscription = AppSettings.shared.$language.removeDuplicates().sink { [weak self] language in
            self?.installApplicationMenu(language: language)
        }
        UpdateController.shared.startIfNeeded()
        MenuBarPanelController.shared.start()

#if DEBUG
        let store = UsageStore.shared
        let rootView = DebugPreviewHost(
            store: store,
            settings: AppSettings.shared
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Meter Preview"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        previewWindow = window
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func openSettings() { SettingsWindowController.shared.show() }

    @objc private func closeKeyWindow(_ sender: Any?) { NSApplication.shared.keyWindow?.performClose(sender) }

    private func installApplicationMenu(language: AppLanguage) {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        let settingsItem = NSMenuItem(title: L10n.text(.settings, language: language) + "…",
                                      action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L10n.text(.quit, language: language) + " Codex Meter",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenu = NSMenu(title: "File")
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)
        let closeItem = fileMenu.addItem(withTitle: "Close Window", action: #selector(closeKeyWindow(_:)), keyEquivalent: "w")
        closeItem.target = self

        let editMenu = NSMenu(title: "Edit")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApplication.shared.mainMenu = mainMenu
    }
}

@main
@MainActor
enum CodexMeterApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
