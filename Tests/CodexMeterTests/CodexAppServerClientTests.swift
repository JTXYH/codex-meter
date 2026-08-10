import Foundation
import Testing
@testable import CodexMeter

struct CodexAppServerClientTests {
    @Test
    func drainsFinalResponsesFromAProcessThatExitsImmediately() async throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(
            "CodexMeterTests.\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("codex")
        let script = #"""
        #!/bin/sh
        IFS= read -r request1
        IFS= read -r request2
        IFS= read -r request3
        IFS= read -r request4
        IFS= read -r request5
        printf '%s\n' '{"id":1,"result":{"account":null}}'
        printf '%s\n' '{"id":2,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1786604934}}}}'
        printf '%s\n' '{"id":3,"result":{"summary":null}}'
        """#
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path
        )

        for _ in 0..<20 {
            let snapshot = try await CodexAppServerClient(
                executableOverride: executable.path,
                timeout: 2
            ).fetchSnapshot()
            #expect(snapshot.primaryWindow?.remainingPercent == 75)
        }
    }

    @Test
    func rejectsOutputBeyondTheSafetyLimit() {
        let collector = AppServerResponseCollector(
            requiredIDs: [1],
            maximumOutputBytes: 32,
            maximumErrorBytes: 16
        )

        collector.appendOutput(Data(repeating: 0x41, count: 33))

        switch collector.wait(timeout: 0.1) {
        case .failed:
            break
        default:
            Issue.record("Expected oversized output to fail")
        }
    }

    @Test
    func capsAndSanitizesStandardError() {
        let collector = AppServerResponseCollector(
            requiredIDs: [1],
            maximumOutputBytes: 32,
            maximumErrorBytes: 16
        )

        collector.appendError(Data("failure\nwith\u{0000}control-data".utf8))
        collector.markConnectionClosed()

        switch collector.wait(timeout: 0.1) {
        case let .closed(message):
            #expect(message.utf8.count <= 16)
            #expect(!message.contains("\n"))
            #expect(!message.contains("\u{0000}"))
        default:
            Issue.record("Expected a bounded connection error")
        }
    }
}
