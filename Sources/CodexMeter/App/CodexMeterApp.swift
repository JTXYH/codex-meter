import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
#if DEBUG
    private var previewWindow: NSWindow?
    private var previewStore: UsageStore?
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppSettings.shared.applyAppearance()
        UpdateController.shared.startIfNeeded()

#if DEBUG
        let store = ProcessInfo.processInfo.environment["CODEX_METER_DEMO"] == "1"
            ? UsageStore(
                loader: DebugDemoUsageLoader(),
                localUsageLoader: DebugDemoLocalTokenUsageLoader(),
                settings: AppSettings.shared
            )
            : UsageStore.shared
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
        window.contentView = NSHostingView(rootView: rootView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        previewStore = store
        previewWindow = window
#endif
    }
}

@main
struct CodexMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore.shared
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra {
            MeterPanelView()
                .environmentObject(store)
                .environmentObject(settings)
        } label: {
            MenuBarLabelView()
                .environmentObject(store)
                .environmentObject(settings)
                .onAppear { store.startIfNeeded() }
        }
        .menuBarExtraStyle(.window)

    }
}
