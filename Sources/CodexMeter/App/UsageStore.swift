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
    @Published private(set) var localTodayUsage = LocalTokenUsage.zero

    private let loader: CodexUsageLoading
    private let localUsageLoader: LocalTokenUsageLoading
    private let settings: AppSettings
    private var refreshLoop: Task<Void, Never>?
    private var localUsageRefreshLoop: Task<Void, Never>?

    init(
        loader: CodexUsageLoading = CodexAppServerClient(),
        localUsageLoader: LocalTokenUsageLoading = LocalTokenUsageScanner(),
        settings: AppSettings? = nil
    ) {
        self.loader = loader
        self.localUsageLoader = localUsageLoader
        self.settings = settings ?? .shared
    }

    func startIfNeeded() {
        if refreshLoop == nil {
            refreshLoop = automaticRefreshTask(refreshImmediately: snapshot == nil)
        }
        if localUsageRefreshLoop == nil {
            localUsageRefreshLoop = localUsageTask()
        }
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

    private func localUsageTask() -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshLocalUsage()
                do {
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    func refreshLocalUsage(at now: Date = Date()) async {
        localTodayUsage = await localUsageLoader.todayUsage(at: now)
    }

    var localTodayTokens: Int64 {
        localTodayUsage.totalTokens
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if snapshot == nil { state = .loading }
        defer { isRefreshing = false }

        await refreshLocalUsage()

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

    var refreshErrorMessage: String? {
        guard snapshot != nil, case let .failed(message) = state else { return nil }
        return message
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
