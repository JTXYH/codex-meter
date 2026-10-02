import Foundation
import ServiceManagement

protocol CodexLifecycleManaging {
    func setEnabled(_ isEnabled: Bool) throws
    var requiresApproval: Bool { get }
}

extension CodexLifecycleManaging {
    var requiresApproval: Bool { false }
}

struct SystemCodexLifecycleManager: CodexLifecycleManaging {
    static let agentPlistName = "local.codex-meter.codex-watcher.plist"

    var requiresApproval: Bool {
#if DEBUG
        return false
#else
        if Self.usesLocalAgent { return false }
        return SMAppService.agent(plistName: Self.agentPlistName).status == .requiresApproval
#endif
    }

    func setEnabled(_ isEnabled: Bool) throws {
#if DEBUG
        // SwiftPM debug paths change between runs. Only the packaged app owns an agent.
        return
#else
        if Self.usesLocalAgent {
            try UserCodexLaunchAgentManager().setEnabled(isEnabled)
            return
        }
        let service = SMAppService.agent(plistName: Self.agentPlistName)
        if isEnabled {
            guard service.status != .enabled, service.status != .requiresApproval else { return }
            try service.register()
        } else {
            guard service.status == .enabled || service.status == .requiresApproval else { return }
            try service.unregister()
        }
#endif
    }

    private static var usesLocalAgent: Bool {
        Bundle.main.object(forInfoDictionaryKey: "CodexMeterUsesLocalWatcher") as? Bool == true
    }
}

/// The locally signed ZIP uses the user's LaunchAgents directory. An Apple-issued
/// signature is needed for reliable SMAppService registration across restarts.
struct UserCodexLaunchAgentManager: CodexLifecycleManaging {
    static let label = "local.codex-meter.codex-watcher"

    private let fileManager = FileManager.default

    private var agentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    private var serviceTarget: String {
        "gui/\(getuid())/\(Self.label)"
    }

    private var userDomain: String {
        "gui/\(getuid())"
    }

    func setEnabled(_ isEnabled: Bool) throws {
        let isLoaded = (try? launchctl(["print", serviceTarget])) != nil
        if !isEnabled {
            if isLoaded { try launchctl(["bootout", serviceTarget]) }
            if fileManager.fileExists(atPath: agentURL.path) {
                try fileManager.removeItem(at: agentURL)
            }
            return
        }

        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/CodexMeterWatcher")
        guard fileManager.isExecutableFile(atPath: helperURL.path) else {
            throw LaunchAgentError.helperMissing
        }
        let data = try Self.propertyListData(helperURL: helperURL)
        if isLoaded, (try? Data(contentsOf: agentURL)) == data { return }

        try fileManager.createDirectory(
            at: agentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if isLoaded { try launchctl(["bootout", serviceTarget]) }
        try data.write(to: agentURL, options: .atomic)
        do {
            try launchctl(["bootstrap", userDomain, agentURL.path])
        } catch {
            try? fileManager.removeItem(at: agentURL)
            throw error
        }
    }

    static func propertyListData(helperURL: URL) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: [
                "Label": label,
                "ProgramArguments": [helperURL.path],
                "RunAtLoad": true,
                "KeepAlive": true,
            ],
            format: .xml,
            options: 0
        )
    }

    private func launchctl(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw LaunchAgentError.commandFailed(message)
        }
    }

    private enum LaunchAgentError: LocalizedError {
        case helperMissing
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .helperMissing:
                "Codex Meter watcher is missing from the installed app."
            case let .commandFailed(message):
                "Could not start the Codex watcher: \(message)"
            }
        }
    }
}
