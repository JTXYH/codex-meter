import AppKit
import Foundation

@MainActor
final class UpdateController: ObservableObject {
    static let shared = UpdateController()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case failed
    }

    @Published private(set) var state: State = .idle

    let currentVersion: String

    private let client: AppUpdateClient?
    private var automaticCheckLoop: Task<Void, Never>?
    private var promptedVersions = Set<String>()

    init(
        client: AppUpdateClient? = AppUpdateClient(),
        currentVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
    ) {
        self.client = client
        self.currentVersion = currentVersion
    }

    func startIfNeeded() {
        guard automaticCheckLoop == nil else { return }
        automaticCheckLoop = Task { [weak self] in
            await self?.checkForUpdates(isManual: false)

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 6 * 60 * 60 * 1_000_000_000)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.checkForUpdates(isManual: false)
            }
        }
    }

    func checkManually() {
        Task { [weak self] in
            await self?.checkForUpdates(isManual: true)
        }
    }

    private func checkForUpdates(isManual: Bool) async {
        guard state != .checking else { return }
        guard let client else {
            state = .failed
            if isManual { presentCheckFailedAlert() }
            return
        }

        state = .checking
        do {
            if let release = try await client.availableUpdate(currentVersion: currentVersion) {
                state = .available(release.version)
                if isManual || !promptedVersions.contains(release.version) {
                    promptedVersions.insert(release.version)
                    presentAvailableUpdateAlert(release)
                }
            } else {
                state = .upToDate
                if isManual { presentUpToDateAlert() }
            }
        } catch {
            state = .failed
            if isManual { presentCheckFailedAlert() }
        }
    }

    private func presentAvailableUpdateAlert(_ release: AppUpdateRelease) {
        let language = AppSettings.shared.language
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.updateAvailableTitle(
            version: release.version,
            language: language
        )
        let notes = release.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = notes.isEmpty
            ? L10n.updateText(.updatePrompt, language: language)
            : String(notes.prefix(2_000))
        alert.addButton(withTitle: L10n.updateText(.downloadUpdate, language: language))
        alert.addButton(withTitle: L10n.updateText(.viewRelease, language: language))
        alert.addButton(withTitle: L10n.updateText(.later, language: language))

        NSApplication.shared.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(release.downloadURL)
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(release.releasePageURL)
        default:
            break
        }
    }

    private func presentUpToDateAlert() {
        let language = AppSettings.shared.language
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.updateText(.noUpdateTitle, language: language)
        alert.informativeText = L10n.noUpdateMessage(
            version: currentVersion,
            language: language
        )
        alert.addButton(withTitle: L10n.updateText(.ok, language: language))
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentCheckFailedAlert() {
        let language = AppSettings.shared.language
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.updateText(.checkFailedTitle, language: language)
        alert.informativeText = L10n.updateText(.checkFailedMessage, language: language)
        alert.addButton(withTitle: L10n.updateText(.ok, language: language))
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
