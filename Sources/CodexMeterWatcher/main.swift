import AppKit
import Foundation

private final class CodexMeterWatcher: NSObject {
    private let codexBundleID = "com.openai.codex"
    private let meterBundleID = "local.codex-meter"
    private let workspace = NSWorkspace.shared
    private let meterAppURL: URL
    private var isOpeningMeter = false

    override init() {
        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0])
        meterAppURL = executableURL
            .deletingLastPathComponent() // Helpers
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // CodexMeter.app
        super.init()
    }

    func start() {
        guard meterAppURL.pathExtension == "app" else { return }
        let center = workspace.notificationCenter
        center.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // Covers a watcher starting after Codex is already open, including login.
        if isCodexRunning { openMeter() }
        RunLoop.main.run()
    }

    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard isCodexEvent(notification) else { return }
        openMeter()
    }

    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard isCodexEvent(notification), !isCodexRunning else { return }
        NSRunningApplication.runningApplications(withBundleIdentifier: meterBundleID)
            .forEach { $0.terminate() }
    }

    private var isCodexRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: codexBundleID).isEmpty
    }

    private func isCodexEvent(_ notification: Notification) -> Bool {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        return application?.bundleIdentifier == codexBundleID
    }

    private func openMeter() {
        guard !isOpeningMeter,
              NSRunningApplication.runningApplications(withBundleIdentifier: meterBundleID).isEmpty else {
            return
        }
        isOpeningMeter = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        workspace.openApplication(at: meterAppURL, configuration: configuration) { [weak self] app, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isOpeningMeter = false
                if let error {
                    NSLog("Codex Meter watcher could not open the app: %@", error.localizedDescription)
                } else if !self.isCodexRunning {
                    // Codex might quit while the asynchronous launch is in flight.
                    app?.terminate()
                }
            }
        }
    }
}

CodexMeterWatcher().start()
