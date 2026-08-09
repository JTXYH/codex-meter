import Foundation
import Testing
@testable import CodexMeter

struct CodexAppServerClientTests {
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
