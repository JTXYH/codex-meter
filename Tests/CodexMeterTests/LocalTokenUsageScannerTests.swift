import Foundation
import Testing
@testable import CodexMeter

struct LocalTokenUsageScannerTests {
    @Test
    func aggregatesMonthsFromTheExistingDailyCacheWithoutReadingLogsAgain() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cache = fixture.root.appendingPathComponent("monthly-cache.json")
        _ = try fixture.makeRolloutFile(lines: [
            tokenEntry(timestamp: "2026-07-31T15:59:00Z", tokens: 100, inputTokens: 100),
            tokenEntry(timestamp: "2026-07-31T16:00:00Z", tokens: 200, inputTokens: 200),
            tokenEntry(timestamp: "2026-08-11T02:00:00Z", tokens: 300, inputTokens: 300),
        ])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             cacheURL: cache, calendar: fixture.calendar)
        let first = await scanner.usage(at: fixture.now)
        #expect(first.monthlyUsage.map { $0.usage?.totalTokens } == [500, 100])
        #expect(first.monthlyUsage.map { fixture.calendar.component(.month, from: $0.month) } == [8, 7])
        #expect(first.dailyUsage.map { $0.usage?.totalTokens } == [300, 200, 100])
        #expect(first.dailyUsage.map { fixture.calendar.component(.day, from: $0.start) } == [11, 1, 31])
        #expect(first.hourlyUsage.map { $0.usage?.totalTokens } == [300, 200, 100])
        #expect(first.hourlyUsage.map { fixture.calendar.component(.hour, from: $0.start) } == [10, 0, 23])
        let restored = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                              cacheURL: cache, calendar: fixture.calendar)
        let loaded = await restored.usage(at: fixture.now)
        #expect(loaded.monthlyUsage == first.monthlyUsage)
        #expect(loaded.dailyUsage == first.dailyUsage)
        #expect(loaded.hourlyUsage == first.hourlyUsage)
        #expect(await restored.bytesReadDuringLastScan == 0)
    }

    @Test
    func todayScanSkipsUntouchedHistoricalFiles() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let recent = try fixture.makeRolloutFile(lines: [
            tokenEntry(timestamp: "2026-08-11T02:00:00Z", tokens: 120, inputTokens: 100, outputTokens: 20),
        ])
        try fixture.markModified(recent, at: fixture.now)
        let history = fixture.sessionsDirectory.appendingPathComponent("rollout-history.jsonl")
        try Data((String(repeating: "x", count: 2_000_000) + "\n").utf8).write(to: history)
        try fixture.markModified(history, at: fixture.now.addingTimeInterval(-86_400))
        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, scope: .today, calendar: fixture.calendar
        )
        let result = await scanner.usage(at: fixture.now)
        #expect(result.today.totalTokens == 120)
        #expect(result.today.apiEquivalentCostUSD > 0)
        #expect(result.lifetime == nil)
        #expect(await scanner.bytesReadDuringLastScan == UInt64(try Data(contentsOf: recent).count))
    }

    @Test
    func cachesCountsWithoutContentAndResumesPartialLinesAfterRestart() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("usage-cache.json")
        let secretText = "test-conversation-content-that-must-not-be-cached"
        let largeMessage = #"{"type":"response_item","payload":{"text":"\#(secretText)\#(String(repeating: "x", count: 3_000_000))"}}"#
        let file = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-5.5"),
            tokenEntry(timestamp: "2026-08-11T02:00:00Z", tokens: 110_000, inputTokens: 100_000, outputTokens: 10_000),
            largeMessage,
        ])
        let pending = tokenEntry(timestamp: "2026-08-11T03:00:00Z", tokens: 110_000,
                                 inputTokens: 100_000, outputTokens: 10_000)
        try append(pending, terminatedByNewline: false, to: file)
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             cacheURL: cacheURL, calendar: fixture.calendar)
        let first = await scanner.usage(at: fixture.now)
        #expect(first.today.totalTokens == 110_000)
        let database = try SQLiteStore(url: cacheURL.appendingPathExtension("sqlite"))
        let cacheText = try database.rows("SELECT state FROM scan_files").compactMap { $0[0].data }
            .map { String(decoding: $0, as: UTF8.self) }.joined()
        #expect(!cacheText.contains(secretText))
        #expect(!cacheText.contains("last_token_usage"))
        #expect(cacheText.utf8.count < 10_000)

        let restored = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                              cacheURL: cacheURL, calendar: fixture.calendar)
        #expect(await restored.usage(at: fixture.now) == first)
        #expect(await restored.bytesReadDuringLastScan == UInt64(pending.utf8.count))
        try append("", terminatedByNewline: true, to: file)
        let completed = await restored.usage(at: fixture.now)
        #expect(completed.today.totalTokens == 220_000)
        #expect(abs(try #require(completed.lifetime).apiEquivalentCostUSD - 1.6) < 0.000_001)
        #expect(await restored.bytesReadDuringLastScan == 1)
        #expect(await restored.usage(at: fixture.now) == completed)
        #expect(await restored.bytesReadDuringLastScan == 0)

        // Leftover invalid legacy JSON cannot replace committed SQLite data.
        try Data("broken-cache".utf8).write(to: cacheURL)
        let recovered = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                               cacheURL: cacheURL, calendar: fixture.calendar)
        #expect(await recovered.usage(at: fixture.now) == completed)
    }

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

        #expect(await scanner.usage(at: fixture.now).today.totalTokens == 120)
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

        #expect(await scanner.usage(at: fixture.now).today.totalTokens == 40)
        #expect(await scanner.usage(at: fixture.now).today.totalTokens == 40)

        try append(
            tokenEntry(timestamp: "2026-08-11T03:00:00.000Z", tokens: 25),
            terminatedByNewline: false,
            to: file
        )
        try fixture.markModified(file, at: fixture.now.addingTimeInterval(1))
        #expect(await scanner.usage(at: fixture.now).today.totalTokens == 40)

        try append("", terminatedByNewline: true, to: file)
        try fixture.markModified(file, at: fixture.now.addingTimeInterval(2))
        #expect(await scanner.usage(at: fixture.now).today.totalTokens == 65)
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
        let usage = await scanner.usage(at: fixture.now).today

        #expect(usage.totalTokens == 135_000)
        #expect(usage.inputTokens == 120_000)
        #expect(usage.cachedInputTokens == 60_000)
        #expect(usage.cacheWriteInputTokens == 10_000)
        #expect(usage.outputTokens == 15_000)
        #expect(usage.reasoningOutputTokens == 4_000)
        #expect(abs(usage.apiEquivalentCostUSD - 0.227) < 0.000_001)
        #expect(abs(usage.cacheHitPercentage - 0.5) < 0.000_001)
    }

    @Test
    func accumulatesHistoricalAndArchivedCostsAcrossDaysWithoutCountingCopiesTwice() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let file = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-10T02:00:00Z", model: "gpt-5.5"),
            tokenEntry(timestamp: "2026-08-10T02:01:00Z", tokens: 110_000,
                       inputTokens: 100_000, outputTokens: 10_000),
            tokenEntry(timestamp: "2026-08-11T02:00:00Z", tokens: 220_000,
                       inputTokens: 200_000, outputTokens: 20_000),
        ])
        // Old modification dates must not hide lifetime usage.
        try fixture.markModified(file, at: fixture.now.addingTimeInterval(-86_400))
        let archive = fixture.root.appendingPathComponent("archived_sessions")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: file, to: archive.appendingPathComponent(file.lastPathComponent))
        let archivedEntry = [
            turnContextEntry(timestamp: "2026-08-09T02:00:00Z", model: "gpt-5.5"),
            tokenEntry(timestamp: "2026-08-09T02:01:00Z", tokens: 110_000,
                       inputTokens: 100_000, outputTokens: 10_000),
        ].joined(separator: "\n") + "\n"
        try Data(archivedEntry.utf8).write(to: archive.appendingPathComponent("rollout-archived.jsonl"))

        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             calendar: fixture.calendar)
        let first = await scanner.usage(at: fixture.now)
        #expect(first.today.totalTokens == 220_000)
        #expect(first.lifetime?.totalTokens == 440_000)
        #expect(abs(try #require(first.lifetime).apiEquivalentCostUSD - 3.2) < 0.000_001)
        #expect(await scanner.usage(at: fixture.now) == first)

        // Archiving a session and crossing midnight must preserve the cumulative amount.
        try FileManager.default.removeItem(at: file)
        let tomorrow = fixture.now.addingTimeInterval(86_400)
        let next = await scanner.usage(at: tomorrow)
        #expect(next.today == .zero)
        #expect(next.lifetime == first.lifetime)
        let movedFile = archive.appendingPathComponent(file.lastPathComponent)
        try append(tokenEntry(timestamp: "2026-08-12T02:00:00Z", tokens: 110_000,
                              inputTokens: 100_000, outputTokens: 10_000),
                   terminatedByNewline: true, to: movedFile)
        let updated = await scanner.usage(at: tomorrow)
        #expect(updated.today.totalTokens == 110_000)
        #expect(abs(try #require(updated.lifetime).apiEquivalentCostUSD - 4) < 0.000_001)
    }

    @Test
    func repeatedCumulativeEventsAndRewrittenFilesDoNotInflateCosts() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let entry = #"{"timestamp":"2026-08-11T02:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":110000},"last_token_usage":{"input_tokens":100000,"output_tokens":10000,"total_tokens":110000}}}}"#
        let file = try fixture.makeRolloutFile(lines: [entry, entry])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             calendar: fixture.calendar)
        let usage = await scanner.usage(at: fixture.now)
        #expect(usage.today.totalTokens == 110_000)
        #expect(abs(try #require(usage.lifetime).apiEquivalentCostUSD - 0.6) < 0.000_001)

        try Data((tokenEntry(timestamp: "2026-08-11T03:00:00Z", tokens: 1_000,
                             inputTokens: 1_000) + "\n").utf8).write(to: file)
        let rewritten = await scanner.usage(at: fixture.now)
        #expect(rewritten.lifetime?.totalTokens == 1_000)
        #expect(abs(try #require(rewritten.lifetime).apiEquivalentCostUSD - 0.004) < 0.000_001)

        fixture.remove()
        #expect(await scanner.usage(at: fixture.now).lifetime == nil)
    }

    @Test(arguments: [
        ("gpt-6-astra", 6.75),
        ("gpt-5.6-sol", 2.7),
        ("gpt-5.6-terra", 1.38),
        ("gpt-5.6-luna", 0.138),
        ("gpt-5.5-2026-04-23", 3.45),
        ("gpt-5.3-codex", 0.665),
        ("gpt-5.1-codex-mini", 0.095),
        ("internal-route", 2.7),
    ])
    func appliesModelRatesAndOnlyApplicableLongContextPremiums(model: String, expected: Double) async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        _ = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: model),
            tokenEntry(timestamp: "2026-08-11T02:00:00Z", tokens: 310_000,
                       inputTokens: 300_000, outputTokens: 10_000),
        ])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             calendar: fixture.calendar)
        let usage = await scanner.usage(at: fixture.now)
        #expect(abs(try #require(usage.lifetime).apiEquivalentCostUSD - expected) < 0.000_001)
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
