import Foundation

protocol CodexUsageLoading {
    func fetchSnapshot() async throws -> CodexUsageSnapshot
}

enum CodexMeterError: LocalizedError, Equatable {
    case codexNotFound
    case launchFailed(String)
    case timeout
    case responseTooLarge
    case connectionClosed(String)
    case server(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "没有找到 Codex CLI。请先在 Codex 中登录，或在设置里指定 codex 可执行文件。"
        case let .launchFailed(message):
            return "无法启动 Codex App Server：\(message)"
        case .timeout:
            return "读取额度超时，请稍后重试。"
        case .responseTooLarge:
            return "Codex App Server 返回的数据超过安全大小限制。"
        case let .connectionClosed(message):
            return message.isEmpty ? "Codex App Server 提前关闭了连接。" : "Codex App Server：\(message)"
        case let .server(message):
            return "Codex 返回错误：\(message)"
        case let .invalidResponse(message):
            return "无法解析额度数据：\(message)"
        }
    }
}

final class CodexAppServerClient: CodexUsageLoading {
    private let executableOverride: String?
    private let timeout: TimeInterval

    init(executableOverride: String? = nil, timeout: TimeInterval = 15) {
        self.executableOverride = executableOverride
        self.timeout = timeout
    }

    func fetchSnapshot() async throws -> CodexUsageSnapshot {
        let executableOverride = executableOverride
        let timeout = timeout
        return try await Task.detached(priority: .utility) {
            let executable = try CodexExecutableLocator.locate(override: executableOverride)
            return try AppServerRunner(executable: executable, timeout: timeout).fetchSnapshot()
        }.value
    }
}

enum CodexExecutableLocator {
    static func locate(override: String? = nil) throws -> URL {
        let fileManager = FileManager.default
        var candidates: [String] = []

        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidates.append((override as NSString).expandingTildeInPath)
        }

        if let saved = UserDefaults.standard.string(forKey: "codexExecutablePath"), !saved.isEmpty {
            candidates.append((saved as NSString).expandingTildeInPath)
        }

        let environmentPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        candidates.append(contentsOf: environmentPath
            .split(separator: ":")
            .map { String($0) + "/codex" })

        let home = fileManager.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/MacOS/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
        ])

        var seen = Set<String>()
        for path in candidates where seen.insert(path).inserted {
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        throw CodexMeterError.codexNotFound
    }
}

private struct AppServerRunner {
    let executable: URL
    let timeout: TimeInterval

    func fetchSnapshot() throws -> CodexUsageSnapshot {
        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let collector = AppServerResponseCollector(requiredIDs: [1, 2, 3])

        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                collector.markConnectionClosed()
            } else {
                collector.appendOutput(data)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { collector.appendError(data) }
        }

        do {
            try process.run()
        } catch {
            cleanup(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
            throw CodexMeterError.launchFailed(error.localizedDescription)
        }

        do {
            try writeRequests(to: inputPipe.fileHandleForWriting)
        } catch {
            cleanup(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
            throw CodexMeterError.connectionClosed(error.localizedDescription)
        }

        let waitResult = collector.wait(timeout: timeout)
        defer {
            cleanup(process: process, inputPipe: inputPipe, outputPipe: outputPipe, errorPipe: errorPipe)
        }

        switch waitResult {
        case .timedOut:
            throw CodexMeterError.timeout
        case .failed:
            throw CodexMeterError.responseTooLarge
        case let .closed(message):
            throw CodexMeterError.connectionClosed(message)
        case let .responses(messages):
            guard let account = messages[1], let limits = messages[2], let usage = messages[3] else {
                throw CodexMeterError.invalidResponse("缺少账户、额度或用量响应")
            }
            return try CodexResponseParser.parse(
                accountData: account,
                rateLimitsData: limits,
                usageData: usage
            )
        }
    }

    private func writeRequests(to handle: FileHandle) throws {
        let requests: [[String: Any]] = [
            [
                "method": "initialize",
                "id": 0,
                "params": [
                    "clientInfo": [
                        "name": "codex_meter",
                        "title": "Codex Meter",
                        "version": "1.0.0",
                    ],
                ],
            ],
            ["method": "initialized", "params": [:]],
            ["method": "account/read", "id": 1, "params": ["refreshToken": false]],
            ["method": "account/rateLimits/read", "id": 2],
            ["method": "account/usage/read", "id": 3],
        ]

        for request in requests {
            var data = try JSONSerialization.data(withJSONObject: request, options: [])
            data.append(0x0A)
            try handle.write(contentsOf: data)
        }
    }

    private func cleanup(process: Process, inputPipe: Pipe, outputPipe: Pipe, errorPipe: Pipe) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        try? inputPipe.fileHandleForWriting.close()
        try? outputPipe.fileHandleForReading.close()
        try? errorPipe.fileHandleForReading.close()
        if process.isRunning {
            process.terminate()
        }
    }
}

final class AppServerResponseCollector {
    enum WaitResult {
        case responses([Int: Data])
        case closed(String)
        case timedOut
        case failed
    }

    private let requiredIDs: Set<Int>
    private let maximumOutputBytes: Int
    private let maximumErrorBytes: Int
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var buffer = Data()
    private var errorBuffer = Data()
    private var responses: [Int: Data] = [:]
    private var receivedOutputBytes = 0
    private var didFinish = false
    private var connectionClosed = false
    private var didFail = false

    init(
        requiredIDs: Set<Int>,
        maximumOutputBytes: Int = 4 * 1024 * 1024,
        maximumErrorBytes: Int = 16 * 1024
    ) {
        self.requiredIDs = requiredIDs
        self.maximumOutputBytes = max(1, maximumOutputBytes)
        self.maximumErrorBytes = max(1, maximumErrorBytes)
    }

    func appendOutput(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        guard data.count <= maximumOutputBytes - receivedOutputBytes else {
            didFail = true
            didFinish = true
            semaphore.signal()
            return
        }

        receivedOutputBytes += data.count
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer[..<newline])
            buffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = (object["id"] as? NSNumber)?.intValue
            else { continue }

            responses[id] = line
            if requiredIDs.isSubset(of: Set(responses.keys)) {
                didFinish = true
                semaphore.signal()
                return
            }
        }
    }

    func appendError(_ data: Data) {
        lock.lock()
        let remainingBytes = maximumErrorBytes - errorBuffer.count
        if remainingBytes > 0 {
            errorBuffer.append(contentsOf: data.prefix(remainingBytes))
        }
        lock.unlock()
    }

    func markConnectionClosed() {
        lock.lock()
        defer { lock.unlock() }
        guard !didFinish else { return }
        connectionClosed = true
        didFinish = true
        semaphore.signal()
    }

    func wait(timeout: TimeInterval) -> WaitResult {
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            return .timedOut
        }

        lock.lock()
        defer { lock.unlock() }
        if didFail {
            return .failed
        }
        if requiredIDs.isSubset(of: Set(responses.keys)) {
            return .responses(responses)
        }
        if connectionClosed {
            let rawMessage = String(data: errorBuffer, encoding: .utf8) ?? ""
            let sanitized = rawMessage
                .components(separatedBy: .controlCharacters)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = String(sanitized.prefix(1_024))
            return .closed(message)
        }
        return .timedOut
    }
}
