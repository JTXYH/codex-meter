import Foundation
import Testing
@testable import CodexMeter

struct LocalTokenUsageScannerTests {
    @Test
    func countsOnlyTodaysCompletedLocalTokenEvents() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }

        let file = try fixture.makeRolloutFile(
            lines: [
                tokenEntry(timestamp: "2026-08-11T02:00:00.000Z", tokens: 120),
                tokenEntry(timestamp: "2026-08-10T02:00:00.000Z", tokens: 800),
                #"{"timestamp":"2026-08-11T03:00:00.000Z","type":"event_msg","payload":{"type":"agent_message"}}"#,
                tokenEntry(timestamp: "2026-08-11T04:00:00Z", tokens: -25),
                "not-json",
            ]
        )
        try fixture.markModified(file, at: fixture.now)

        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory,
            calendar: fixture.calendar
        )

        #expect(await scanner.todayUsage(at: fixture.now).totalTokens == 120)
    }

    @Test
    func readsOnlyAppendedLinesWithoutDoubleCounting() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }

        let file = try fixture.makeRolloutFile(
            lines: [tokenEntry(timestamp: "2026-08-11T02:00:00.000Z", tokens: 40)]
        )
        try fixture.markModified(file, at: fixture.now)
        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory,
            calendar: fixture.calendar
        )

        #expect(await scanner.todayUsage(at: fixture.now).totalTokens == 40)
        #expect(await scanner.todayUsage(at: fixture.now).totalTokens == 40)

        try append(
            tokenEntry(timestamp: "2026-08-11T03:00:00.000Z", tokens: 25),
            terminatedByNewline: false,
            to: file
        )
        try fixture.markModified(file, at: fixture.now.addingTimeInterval(1))
        #expect(await scanner.todayUsage(at: fixture.now).totalTokens == 40)

        try append("", terminatedByNewline: true, to: file)
        try fixture.markModified(file, at: fixture.now.addingTimeInterval(2))
        #expect(await scanner.todayUsage(at: fixture.now).totalTokens == 65)
    }

    @Test
    func tracksTokenKindsAndUsesTheActiveModelsPublicRates() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }

        let file = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T01:59:00.000Z", model: "gpt-5.6-terra"),
            tokenEntry(
                timestamp: "2026-08-11T02:00:00.000Z",
                tokens: 110_000,
                inputTokens: 100_000,
                cachedInputTokens: 60_000,
                cacheWriteInputTokens: 10_000,
                outputTokens: 10_000,
                reasoningOutputTokens: 4_000
            ),
            turnContextEntry(timestamp: "2026-08-11T02:59:00.000Z", model: "gpt-5.6-luna"),
            tokenEntry(
                timestamp: "2026-08-11T03:00:00.000Z",
                tokens: 25_000,
                inputTokens: 20_000,
                outputTokens: 5_000
            ),
        ])
        try fixture.markModified(file, at: fixture.now)

        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory,
            calendar: fixture.calendar
        )
        let usage = await scanner.todayUsage(at: fixture.now)

        #expect(usage.totalTokens == 135_000)
        #expect(usage.inputTokens == 120_000)
        #expect(usage.cachedInputTokens == 60_000)
        #expect(usage.cacheWriteInputTokens == 10_000)
        #expect(usage.outputTokens == 15_000)
        #expect(usage.reasoningOutputTokens == 4_000)
        #expect(abs(usage.apiEquivalentCostUSD - 0.32125) < 0.000_001)
        #expect(abs(usage.cacheHitPercentage - 0.5) < 0.000_001)
    }
}

private struct LocalUsageFixture {
    let root: URL
    let sessionsDirectory: URL
    let calendar: Calendar
    let now: Date

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMeterLocalUsageTests-\(UUID().uuidString)", isDirectory: true)
        sessionsDirectory = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        self.calendar = calendar
        now = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 11,
            hour: 12
        )))
    }

    func makeRolloutFile(lines: [String]) throws -> URL {
        let oldSessionDirectory = sessionsDirectory
            .appendingPathComponent("2025/01/01", isDirectory: true)
        try FileManager.default.createDirectory(
            at: oldSessionDirectory,
            withIntermediateDirectories: true
        )
        let file = oldSessionDirectory.appendingPathComponent("rollout-test.jsonl")
        let data = try #require((lines.joined(separator: "\n") + "\n").data(using: .utf8))
        try data.write(to: file)
        return file
    }

    func markModified(_ file: URL, at date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private func tokenEntry(
    timestamp: String,
    tokens: Int64,
    inputTokens: Int64? = nil,
    cachedInputTokens: Int64? = nil,
    cacheWriteInputTokens: Int64? = nil,
    outputTokens: Int64? = nil,
    reasoningOutputTokens: Int64? = nil
) -> String {
    var fields = ["\"total_tokens\":\(tokens)"]
    if let inputTokens { fields.append("\"input_tokens\":\(inputTokens)") }
    if let cachedInputTokens { fields.append("\"cached_input_tokens\":\(cachedInputTokens)") }
    if let cacheWriteInputTokens {
        fields.append("\"cache_write_input_tokens\":\(cacheWriteInputTokens)")
    }
    if let outputTokens { fields.append("\"output_tokens\":\(outputTokens)") }
    if let reasoningOutputTokens {
        fields.append("\"reasoning_output_tokens\":\(reasoningOutputTokens)")
    }
    return #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{\#(fields.joined(separator: ","))}}}}"#
}

private func turnContextEntry(timestamp: String, model: String) -> String {
    #"{"timestamp":"\#(timestamp)","type":"turn_context","payload":{"model":"\#(model)"}}"#
}

private func append(_ value: String, terminatedByNewline: Bool, to file: URL) throws {
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    try handle.seekToEnd()
    let suffix = terminatedByNewline ? "\n" : ""
    try handle.write(contentsOf: Data((value + suffix).utf8))
}
