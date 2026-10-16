import Foundation
import Testing
@testable import CodexMeter

struct LocalTokenUsageScannerTests {
    @Test
    func groupsModelUsageByDayMonthAndYearAndBackfillsExistingCheckpoints() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("model-cache.json")
        _ = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-07-31T15:59:00Z", model: "gpt-6-sol"),
            tokenEntry(timestamp: "2026-07-31T15:59:01Z", tokens: 110, inputTokens: 100, outputTokens: 10),
            turnContextEntry(timestamp: "2026-07-31T16:00:00Z", model: "gpt-6-astra"),
            tokenEntry(timestamp: "2026-07-31T16:00:01Z", tokens: 220, inputTokens: 200, outputTokens: 20),
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-6-sol"),
            tokenEntry(timestamp: "2026-08-11T01:00:01Z", tokens: 330, inputTokens: 300, outputTokens: 30),
        ])
        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, cacheURL: cacheURL, calendar: fixture.calendar
        )
        let first = await scanner.usage(at: fixture.now)
        #expect(first.dailyModelUsage.map { $0.model } == ["gpt-6-sol", "gpt-6-astra", "gpt-6-sol"])
        #expect(first.dailyModelUsage.map { $0.usage.totalTokens } == [330, 220, 110])
        let today = ModelUsageBuilder.models(
            from: first.dailyModelUsage, period: .day, containing: fixture.now, calendar: fixture.calendar
        )
        #expect(today.map { $0.usage.inputTokens } == [300])
        let august = ModelUsageBuilder.models(
            from: first.dailyModelUsage, period: .month, containing: fixture.now, calendar: fixture.calendar
        )
        #expect(august.map(\.model) == ["gpt-6-sol", "gpt-6-astra"])
        #expect(august.map { $0.usage.totalTokens } == [330, 220])
        let year = ModelUsageBuilder.models(
            from: first.dailyModelUsage, period: .year, containing: fixture.now, calendar: fixture.calendar
        )
        #expect(year.map { $0.usage.totalTokens } == [440, 220])
        #expect(year.map { $0.usage.outputTokens } == [40, 20])

        let restored = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, cacheURL: cacheURL, calendar: fixture.calendar
        )
        #expect(await restored.usage(at: fixture.now) == first)
        #expect(await restored.bytesReadDuringLastScan == 0)

        let database = try SQLiteStore(url: cacheURL.appendingPathExtension("sqlite"))
        let saved = try #require(database.rows("SELECT state FROM scan_files WHERE scope='lifetime'").first?.first?.data)
        var checkpoint = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        checkpoint.removeValue(forKey: "hasModelUsage")
        try database.execute("UPDATE scan_files SET state=? WHERE scope='lifetime'", [
            .blob(try JSONSerialization.data(withJSONObject: checkpoint)),
        ])
        try database.execute("DELETE FROM daily_model_usage WHERE scope='lifetime'")
        let upgraded = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, cacheURL: cacheURL, calendar: fixture.calendar
        )
        #expect(await upgraded.usage(at: fixture.now) == first)
        #expect(await upgraded.bytesReadDuringLastScan > 0)
    }

    @Test
    func keepsHourlyModelTotalsSeparateAndBackfillsOldCheckpoints() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("hourly-model-cache.json")
        _ = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T00:10:00Z", model: "gpt-6-sol"),
            tokenEntry(timestamp: "2026-08-11T00:10:01Z", tokens: 110, inputTokens: 100, outputTokens: 10),
            turnContextEntry(timestamp: "2026-08-11T00:20:00Z", model: "gpt-6-astra"),
            tokenEntry(timestamp: "2026-08-11T00:20:01Z", tokens: 220, inputTokens: 200, outputTokens: 20),
            turnContextEntry(timestamp: "2026-08-11T01:10:00Z", model: "gpt-6-sol"),
            tokenEntry(timestamp: "2026-08-11T01:10:01Z", tokens: 330, inputTokens: 300, outputTokens: 30),
        ])
        let scanner = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, cacheURL: cacheURL, calendar: fixture.calendar
        )
        let first = await scanner.usage(at: fixture.now)
        let firstHour = try #require(fixture.calendar.dateInterval(of: .hour,
            for: ISO8601DateFormatter().date(from: "2026-08-11T00:10:01Z")!)?.start)
        let rows = ModelUsageBuilder.models(from: first.hourlyModelUsage,
                                            containing: firstHour, calendar: fixture.calendar)
        #expect(rows.map(\.model) == ["gpt-6-astra", "gpt-6-sol"])
        #expect(rows.map { $0.usage.totalTokens } == [220, 110])
        let nextHour = try #require(fixture.calendar.date(byAdding: .hour, value: 1, to: firstHour))
        #expect(ModelUsageBuilder.models(from: first.hourlyModelUsage,
                                         containing: nextHour, calendar: fixture.calendar)
            .map { $0.usage.totalTokens } == [330])

        let database = try SQLiteStore(url: cacheURL.appendingPathExtension("sqlite"))
        let saved = try #require(database.rows("SELECT state FROM scan_files WHERE scope='lifetime'").first?.first?.data)
        var checkpoint = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        checkpoint.removeValue(forKey: "hasHourlyModelUsage")
        try database.execute("UPDATE scan_files SET state=? WHERE scope='lifetime'", [
            .blob(try JSONSerialization.data(withJSONObject: checkpoint)),
        ])
        try database.execute("DELETE FROM hourly_model_usage WHERE scope='lifetime'")
        let upgraded = LocalTokenUsageScanner(
            sessionsDirectory: fixture.sessionsDirectory, cacheURL: cacheURL, calendar: fixture.calendar
        )
        #expect(await upgraded.usage(at: fixture.now) == first)
        #expect(await upgraded.bytesReadDuringLastScan > 0)
    }

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
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-5.6-sol"),
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
        #expect(result.lifetime == nil)
        #expect(await scanner.bytesReadDuringLastScan == UInt64(try Data(contentsOf: recent).count))
    }

    @Test
    func todayModelsSurviveCacheMigrationAndRestartWithoutLeakingPreviousDays() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("today-model-cache.json")
        let file = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-10T02:00:00Z", model: "yesterday-model"),
            #"{"timestamp":"2026-08-10T02:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":800},"last_token_usage":{"total_tokens":800}}}}"#,
            turnContextEntry(timestamp: "2026-08-11T02:00:00Z", model: "today-model"),
            #"{"timestamp":"2026-08-11T02:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":800},"last_token_usage":{"total_tokens":800}}}}"#,
            tokenEntry(timestamp: "2026-08-11T02:00:01Z", tokens: 120),
        ])
        try fixture.markModified(file, at: fixture.now)
        func scanner() -> LocalTokenUsageScanner {
            LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                   scope: .today, cacheURL: cacheURL, calendar: fixture.calendar)
        }

        let first = await scanner().usage(at: fixture.now)
        #expect(first.today.totalTokens == 120)
        #expect(first.dailyModelUsage.map(\.model) == ["today-model"])
        #expect(first.dailyModelUsage.map { $0.usage.totalTokens } == [120])
        #expect(first.dailyModelUsage.allSatisfy { fixture.calendar.isDate($0.day, inSameDayAs: fixture.now) })
        #expect(first.lifetime == nil)
        #expect(first.dailyUsage.isEmpty && first.hourlyUsage.isEmpty && first.monthlyUsage.isEmpty)
        #expect(first.hourlyModelUsage.isEmpty)

        let restored = scanner()
        #expect(await restored.usage(at: fixture.now) == first)
        #expect(await restored.bytesReadDuringLastScan == 0)

        // Earlier today checkpoints claimed model support but did not persist model rows.
        let database = try SQLiteStore(url: cacheURL.appendingPathExtension("sqlite"))
        let cachedDates = """
            SELECT day FROM daily_usage WHERE scope='today'
            UNION ALL SELECT day FROM daily_model_usage WHERE scope='today'
            UNION ALL SELECT hour FROM hourly_usage WHERE scope='today'
            UNION ALL SELECT hour FROM hourly_model_usage WHERE scope='today'
            """
        #expect(try database.rows(cachedDates).allSatisfy {
            fixture.calendar.isDate(Date(timeIntervalSinceReferenceDate: $0[0].double), inSameDayAs: fixture.now)
        })
        let saved = try #require(database.rows("SELECT state FROM scan_files WHERE scope='today'").first?.first?.data)
        var checkpoint = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        checkpoint.removeValue(forKey: "hasTodayModelUsage")
        try database.execute("UPDATE scan_files SET state=? WHERE scope='today'", [
            .blob(try JSONSerialization.data(withJSONObject: checkpoint)),
        ])
        try database.execute("DELETE FROM daily_model_usage WHERE scope='today'")
        let upgraded = scanner()
        #expect(await upgraded.usage(at: fixture.now) == first)
        #expect(await upgraded.bytesReadDuringLastScan > 0)

        let tomorrow = try #require(fixture.calendar.date(byAdding: .day, value: 1, to: fixture.now))
        try append(turnContextEntry(timestamp: "2026-08-12T02:00:00Z", model: "next-day-model"),
                   terminatedByNewline: true, to: file)
        try append(tokenEntry(timestamp: "2026-08-12T02:00:01Z", tokens: 40),
                   terminatedByNewline: true, to: file)
        try fixture.markModified(file, at: tomorrow)
        let nextDay = await upgraded.usage(at: tomorrow)
        #expect(nextDay.today.totalTokens == 40)
        #expect(nextDay.dailyModelUsage.map(\.model) == ["next-day-model"])
        #expect(nextDay.dailyModelUsage.map { $0.usage.totalTokens } == [40])
        #expect(nextDay.dailyUsage.isEmpty && nextDay.hourlyUsage.isEmpty && nextDay.monthlyUsage.isEmpty)
        #expect(try database.rows(cachedDates).allSatisfy {
            fixture.calendar.isDate(Date(timeIntervalSinceReferenceDate: $0[0].double), inSameDayAs: tomorrow)
        })
        let nextRestart = scanner()
        #expect(await nextRestart.usage(at: tomorrow) == nextDay)
        #expect(await nextRestart.bytesReadDuringLastScan == 0)
        let followingDay = try #require(fixture.calendar.date(byAdding: .day, value: 1, to: tomorrow))
        let emptyNextDay = await nextRestart.usage(at: followingDay)
        #expect(emptyNextDay.today == .zero)
        #expect(emptyNextDay.dailyModelUsage.isEmpty)
    }

    @Test
    func ignoresQuotaMetadataWhilePreservingTokenCountsAndRestart() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("today-cache.json")
        _ = try fixture.makeRolloutFile(lines: [
            quotaTokenEntry("2026-08-10T16:30:00Z", tokens: 100, primary: 10, reset: 1_786_392_000,
                            weekly: 20, weeklyReset: 1_786_752_000),
            quotaTokenEntry("2026-08-10T17:30:00Z", tokens: 200, primary: 12, reset: 1_786_392_000,
                            weekly: 21, weeklyReset: 1_786_752_000),
        ])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             scope: .today, cacheURL: cacheURL, calendar: fixture.calendar)
        let first = await scanner.usage(at: fixture.now)
        #expect(first.today.totalTokens == 300)
        let database = try SQLiteStore(url: cacheURL.appendingPathExtension("sqlite"))
        let stored = try #require(database.rows("SELECT state FROM scan_files WHERE scope='today'").first?.first?.data)
        let checkpoint = try #require(JSONSerialization.jsonObject(with: stored) as? [String: Any])
        #expect(checkpoint["quotaReadings"] == nil)
        let restored = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                              scope: .today, cacheURL: cacheURL, calendar: fixture.calendar)
        #expect(await restored.usage(at: fixture.now) == first)
        #expect(await restored.bytesReadDuringLastScan == 0)
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
    func tracksTokenKindsAcrossModelChanges() async throws {
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
    }

    @Test
    func accumulatesHistoricalAndArchivedTokensAcrossDaysWithoutCountingCopiesTwice() async throws {
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
    }

    @Test
    func repeatedCumulativeEventsAndRewrittenFilesDoNotInflateTokens() async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let entry = #"{"timestamp":"2026-08-11T02:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":110000},"last_token_usage":{"input_tokens":100000,"output_tokens":10000,"total_tokens":110000}}}}"#
        let file = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-5.6-sol"), entry, entry,
        ])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                             calendar: fixture.calendar)
        let usage = await scanner.usage(at: fixture.now)
        #expect(usage.today.totalTokens == 110_000)

        try Data((turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-5.6-sol") + "\n"
            + tokenEntry(timestamp: "2026-08-11T03:00:00Z", tokens: 1_000,
                         inputTokens: 1_000) + "\n").utf8).write(to: file)
        let rewritten = await scanner.usage(at: fixture.now)
        #expect(rewritten.lifetime?.totalTokens == 1_000)

        fixture.remove()
        #expect(await scanner.usage(at: fixture.now).lifetime == nil)
    }

    @Test(arguments: [
        (100 as Int64, 90 as Int64, 20 as Int64, 0 as Int64, 100 as Int64),
        (-1, 0, 0, 1, 1),
        (0, 0, 0, 0, 100),
    ])
    func malformedTokenBreakdownsAreClampedAndSurviveRestart(input: Int64, cached: Int64,
                                                           write: Int64, output: Int64, total: Int64) async throws {
        let fixture = try LocalUsageFixture()
        defer { fixture.remove() }
        let cacheURL = fixture.root.appendingPathComponent("invalid-details.json")
        _ = try fixture.makeRolloutFile(lines: [
            turnContextEntry(timestamp: "2026-08-11T01:00:00Z", model: "gpt-6.1-sol"),
            tokenEntry(timestamp: "2026-08-11T01:00:01Z", tokens: total, inputTokens: input,
                       cachedInputTokens: cached, cacheWriteInputTokens: write, outputTokens: output),
        ])
        let scanner = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                              cacheURL: cacheURL, calendar: fixture.calendar)
        let usage = await scanner.usage(at: fixture.now).today
        #expect(usage.totalTokens == max(total, 0))
        #expect(usage.inputTokens == max(input, 0))
        #expect(usage.cachedInputTokens >= 0)
        #expect(usage.cacheWriteInputTokens >= 0)
        #expect(usage.cachedInputTokens + usage.cacheWriteInputTokens <= usage.inputTokens)
        #expect(usage.outputTokens == max(output, 0))
        let restored = LocalTokenUsageScanner(sessionsDirectory: fixture.sessionsDirectory,
                                               cacheURL: cacheURL, calendar: fixture.calendar)
        #expect(await restored.usage(at: fixture.now).today == usage)
        #expect(await restored.bytesReadDuringLastScan == 0)
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

private func quotaTokenEntry(
    _ timestamp: String,
    tokens: Int64,
    primary: Double,
    reset: Int64,
    weekly: Double,
    weeklyReset: Int64
) -> String {
    #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":\#(tokens)}},"rate_limits":{"limit_id":"codex","primary":{"used_percent":\#(primary),"window_minutes":300,"resets_at":\#(reset)},"secondary":{"used_percent":\#(weekly),"window_minutes":10080,"resets_at":\#(weeklyReset)}}}}"#
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
