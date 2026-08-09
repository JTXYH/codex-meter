import AppKit
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var state: State = .idle
    @Published private(set) var isRefreshing = false

    private let loader: CodexUsageLoading
    private let settings: AppSettings
    private var refreshLoop: Task<Void, Never>?

    init(
        loader: CodexUsageLoading = CodexAppServerClient(),
        settings: AppSettings? = nil
    ) {
        self.loader = loader
        self.settings = settings ?? .shared
    }

    func startIfNeeded() {
        guard refreshLoop == nil else { return }
        refreshLoop = automaticRefreshTask(refreshImmediately: snapshot == nil)
    }

    func rescheduleAutomaticRefresh() {
        guard refreshLoop != nil else { return }
        refreshLoop?.cancel()
        refreshLoop = automaticRefreshTask(refreshImmediately: false)
    }

    private func automaticRefreshTask(refreshImmediately: Bool) -> Task<Void, Never> {
        Task { [weak self] in
            if refreshImmediately {
                await self?.refresh()
            }

            while !Task.isCancelled {
                guard let interval = self?.settings.automaticRefreshIntervalNanoseconds else { return }
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if snapshot == nil { state = .loading }
        defer { isRefreshing = false }

        do {
            snapshot = try await loader.fetchSnapshot()
            state = .loaded
        } catch {
            if let codexError = error as? CodexMeterError {
                state = .failed(L10n.errorMessage(for: codexError, language: settings.language))
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    var menuBarText: String {
        guard let window = snapshot?.featuredWindow else { return "--" }
        return "\(Int(window.remainingPercent.rounded()))%"
    }
}

enum AppActions {
    @MainActor
    static func openSettings() {
        SettingsWindowController.shared.show()
    }

    @MainActor
    static func openCodex() {
        let workspace = NSWorkspace.shared
        let bundleIdentifiers = [
            "com.openai.codex",
            "com.openai.chat",
            "com.openai.chatgpt",
        ]

        for bundleIdentifier in bundleIdentifiers {
            if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                workspace.openApplication(at: url, configuration: .init())
                return
            }
        }

        for path in ["/Applications/Codex.app", "/Applications/ChatGPT.app"] {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                workspace.openApplication(at: url, configuration: .init())
                return
            }
        }

        if let url = URL(string: "https://chatgpt.com/codex") {
            workspace.open(url)
        }
    }

    @MainActor
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
