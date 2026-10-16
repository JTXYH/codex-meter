import Foundation
import Testing
@testable import CodexMeter

struct UsageCalendarTests {
    @Test(arguments: [
        ("2026-10-16T00:30:00+08:00", "2026-10-15"),
        ("2026-10-16T00:30:00+14:00", "2026-10-15"),
        ("2026-03-08T01:30:00-08:00", "2026-03-08"),
        ("2026-03-08T03:30:00-07:00", "2026-03-08"),
        ("2026-11-01T01:30:00-07:00", "2026-11-01"),
        ("2026-11-01T01:30:00-08:00", "2026-11-01"),
        ("2027-01-01T00:30:00+08:00", "2026-12-31"),
    ])
    func accountAndLocalDaysShareUTCRegardlessOfDeviceMidnightOrDST(timestamp: String, expected: String) throws {
        let now = try #require(ISO8601DateFormatter().date(from: timestamp))
        let interval = UsageCalendar.dayInterval(containing: now)
        let range = try #require(AccountModelDateRange(period: .day, containing: now, now: now))
        #expect(range.dateString(interval.start) == expected)
        #expect(range.start == interval.start)
        #expect(range.end == interval.start)
        #expect(interval.duration == 86_400)
        #expect(UsageCalendar.calendar.timeZone.secondsFromGMT(for: now) == 0)
        let officialDate = try #require(DateOnlyParser.date(from: expected))
        #expect(interval.contains(officialDate))
        #expect(UsageStatisticsL10n.label(officialDate, period: .day, now: now, language: .english) == "Today")
    }

    @Test
    func officialHistoryExcludesTheEntireCurrentUTCDayAtLocalMidnight() throws {
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T00:30:00+08:00"))
        let account = Data(#"{"result":{"account":null}}"#.utf8)
        let limits = Data(#"{"result":{"rateLimits":null,"rateLimitsByLimitId":{}}}"#.utf8)
        let usage = Data(#"{"result":{"dailyUsageBuckets":[{"startDate":"2026-10-14","tokens":1000},{"startDate":"2026-10-15","tokens":2000}]}}"#.utf8)
        let snapshot = try CodexResponseParser.parse(accountData: account, rateLimitsData: limits, usageData: usage, fetchedAt: now)
        let previous = try #require(UsageCalendar.calendar.date(byAdding: .day, value: -1, to: now))
        let history = AccountUsageBuilder.periods(from: snapshot.dailyUsage, period: .day, count: 1, endingAt: previous)
        #expect(history.first?.tokens == 1_000)
        #expect(snapshot.tokenUsage(on: now)?.tokens == 2_000)
        let historyStart = try #require(history.first?.start)
        #expect(UsageCalendar.dayInterval(containing: historyStart).end == UsageCalendar.dayInterval(containing: now).start)
        #expect(UsageStatisticsL10n.label(historyStart, period: .day, now: now, language: .english) == "Yesterday")
    }

    @Test
    func scannerMovesItsCursorAtUTCMidnightAndDoesNotMixAdjacentDays() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexMeterUTCDay-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let file = sessions.appendingPathComponent("rollout-midnight.jsonl")
        let lines = [
            #"{"type":"turn_context","payload":{"model":"test-model"}}"#,
            event("2026-10-15T07:00:00Z", tokens: 100),
            event("2026-10-15T16:30:00Z", tokens: 200),
            event("2026-10-16T00:00:00Z", tokens: 400),
        ]
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
        let clock = ISO8601DateFormatter()
        let before = try #require(clock.date(from: "2026-10-15T23:59:59Z"))
        let after = try #require(clock.date(from: "2026-10-16T00:00:01Z"))
        try FileManager.default.setAttributes([.modificationDate: after], ofItemAtPath: file.path)
        let database = try SQLiteStore(url: root.appendingPathComponent("meter.sqlite"))
        let scanner = LocalTokenUsageScanner(sessionsDirectory: sessions, scope: .today, database: database)
        let first = await scanner.usage(at: before)
        #expect(first.today.totalTokens == 300)
        #expect(first.dailyModelUsage.first?.usage.totalTokens == 300)
        let next = await scanner.usage(at: after)
        #expect(next.today.totalTokens == 400)
        #expect(next.dailyModelUsage.first?.usage.totalTokens == 400)
        #expect(next.dailyModelUsage.first?.day == UsageCalendar.dayInterval(containing: after).start)
        let restored = LocalTokenUsageScanner(sessionsDirectory: sessions, scope: .today, database: database)
        #expect(await restored.usage(at: after) == next)
        #expect(await restored.bytesReadDuringLastScan == 0)
    }

    @Test
    func scannerRebuildsTaipeiCacheInUTCAndReusesTheMigratedCheckpoint() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexMeterUTCMigration-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let file = sessions.appendingPathComponent("rollout-timezone-migration.jsonl")
        let lines = [
            #"{"type":"turn_context","payload":{"model":"test-model"}}"#,
            event("2026-10-15T07:00:00Z", tokens: 200),
            event("2026-10-15T16:15:00Z", tokens: 100),
        ]
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
        let now = try #require(ISO8601DateFormatter().date(from: "2026-10-16T00:30:00+08:00"))
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file.path)
        let database = try SQLiteStore(url: root.appendingPathComponent("meter.sqlite"))
        var taipei = Calendar(identifier: .gregorian)
        taipei.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let previous = LocalTokenUsageScanner(sessionsDirectory: sessions, scope: .today, database: database, calendar: taipei)
        #expect(await previous.usage(at: now).today.totalTokens == 100)
        #expect(try database.rows("SELECT path FROM scan_files WHERE scope='today'").count == 1)

        let migrated = LocalTokenUsageScanner(sessionsDirectory: sessions, scope: .today, database: database)
        let usage = await migrated.usage(at: now)
        #expect(usage.today.totalTokens == 300)
        #expect(usage.dailyModelUsage.count == 1)
        #expect(usage.dailyModelUsage.first?.usage.totalTokens == 300)
        #expect(usage.dailyModelUsage.first?.day == UsageCalendar.dayInterval(containing: now).start)
        #expect(await migrated.bytesReadDuringLastScan > 0)

        let restored = LocalTokenUsageScanner(sessionsDirectory: sessions, scope: .today, database: database)
        #expect(await restored.usage(at: now) == usage)
        #expect(await restored.bytesReadDuringLastScan == 0)
    }

    private func event(_ timestamp: String, tokens: Int) -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":\#(tokens),"output_tokens":0,"total_tokens":\#(tokens)}}}}"#
    }
}
