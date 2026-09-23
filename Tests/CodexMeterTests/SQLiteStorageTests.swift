import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct SQLiteStorageTests {
    @Test @MainActor
    func migratesPreferencesImagesAndIndependentCardSettingsAcrossRestart() throws {
        let fixture = try StorageFixture()
        defer { fixture.remove() }
        let suite = "CodexMeter.SQLiteMigration.\(UUID())"
        let legacy = try #require(UserDefaults(suiteName: suite))
        defer { legacy.removePersistentDomain(forName: suite) }
        legacy.set(false, forKey: "showTokenActivityCard")
        legacy.set(["monthlyUsage", "tokenActivity", "quota"], forKey: "dashboardSectionOrder")
        legacy.set("Keep", forKey: "unrelatedPreference")
        let profile = QuotaBackgroundProfile(name: "Existing", assets: [.sufficient: QuotaBackgroundAsset(
            originalFilename: "original.jpg", croppedFilename: "crop.jpg")])
        legacy.set(try JSONEncoder().encode([profile]), forKey: "quotaBackgroundProfiles")
        legacy.set(profile.id.uuidString, forKey: "selectedQuotaBackgroundProfileID")
        let images = fixture.root.appendingPathComponent("images")
        let directory = images.appendingPathComponent(profile.id.uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let image = NSImage(size: NSSize(width: 40, height: 40))
        image.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 40, height: 40).fill(); image.unlockFocus()
        let data = try #require(image.tiffRepresentation)
        try data.write(to: directory.appendingPathComponent("original.jpg"))
        try data.write(to: directory.appendingPathComponent("crop.jpg"))
        let database = try SQLiteStore(url: fixture.databaseURL)
        let preferences = SQLitePreferences(database: database, legacy: legacy)
        #expect(legacy.object(forKey: "showTokenActivityCard") == nil)
        #expect(legacy.string(forKey: "unrelatedPreference") == "Keep")
        let settings = AppSettings(defaults: preferences, launchAtLoginManager: NoLoginChanges())
        #expect(!settings.showTokenActivityCard)
        #expect(!settings.showActivityOverviewCard)
        #expect(Array(settings.dashboardSectionOrder.prefix(4)) == [.monthlyUsage, .tokenActivity, .activityOverview, .quota])
        settings.showActivityOverviewCard = true
        settings.moveDashboardSections(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        let backgrounds = QuotaBackgroundStore(defaults: preferences, storageDirectory: images)
        #expect(backgrounds.selectedImage(for: 90) != nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("original.jpg").path))
        #expect(try database.storageInfo().imageBytes == Int64(data.count * 2))
        let reopened = try SQLiteStore(url: fixture.databaseURL)
        let restoredPreferences = SQLitePreferences(database: reopened, legacy: legacy)
        let restored = AppSettings(defaults: restoredPreferences, launchAtLoginManager: NoLoginChanges())
        #expect(restored.showActivityOverviewCard)
        #expect(!restored.showTokenActivityCard)
        #expect(restored.dashboardSectionOrder.first == .activityOverview)
        let restoredImages = QuotaBackgroundStore(defaults: restoredPreferences, storageDirectory: images)
        #expect(restoredImages.selectedImage(for: 90) != nil)
        try reopened.cleanUsage(before: fixture.now)
        #expect(restoredPreferences.string(forKey: "selectedQuotaBackgroundProfileID") == profile.id.uuidString)
        #expect(try reopened.storageInfo().imageBytes == Int64(data.count * 2))
        #expect(try reopened.rows("PRAGMA integrity_check").first?.first?.string == "ok")
    }

    @Test
    func importsLegacyJSONAndBackfillsHoursOnceWithoutDuplicatingCosts() async throws {
        let f = try StorageFixture()
        defer { f.remove() }
        let file = try f.write([f.context("gpt-5.5"), f.event("2026-09-21T02:00:00Z", input: 100_000, output: 10_000)])
        let values = try file.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        let usage: [String: Any] = ["totalTokens": 110_000, "inputTokens": 100_000, "outputTokens": 10_000,
            "cachedInputTokens": 0, "cacheWriteInputTokens": 0, "reasoningOutputTokens": 0, "apiEquivalentCostUSD": 0.8]
        let state: [String: Any] = ["offset": try Data(contentsOf: file).count,
            "usageByDay": [f.calendar.startOfDay(for: f.now).timeIntervalSinceReferenceDate, usage],
            "pricing": ["inputUSDPerMillion": 5, "cachedInputUSDPerMillion": 0.5, "outputUSDPerMillion": 30, "supportsLongContextPricing": true],
            "modificationDate": values.contentModificationDate!.timeIntervalSinceReferenceDate,
            "creationDate": values.creationDate!.timeIntervalSinceReferenceDate]
        let cache = f.root.appendingPathComponent("legacy.json")
        let payload: [String: Any] = ["version": 1, "scope": "lifetime", "timeZoneIdentifier": f.calendar.timeZone.identifier,
            "sessionsPath": f.sessions.path, "archivedSessionsPath": f.archive.path, "files": [file.absoluteString, state]]
        try JSONSerialization.data(withJSONObject: payload).write(to: cache)
        let database = try SQLiteStore(url: f.databaseURL)
        let scanner = f.scanner(database, cache: cache)
        let first = await scanner.usage(at: f.now)
        #expect(first.today.totalTokens == 110_000)
        #expect(abs(first.today.apiEquivalentCostUSD - 0.8) < 1e-10)
        #expect(first.hourlyUsage.first?.usage?.totalTokens == 110_000)
        let fileBytes = try UInt64(Data(contentsOf: file).count)
        #expect(await scanner.bytesReadDuringLastScan == fileBytes)
        #expect(!FileManager.default.fileExists(atPath: cache.path))
        let restored = f.scanner(try SQLiteStore(url: f.databaseURL))
        #expect(await restored.usage(at: f.now) == first)
        #expect(await restored.bytesReadDuringLastScan == 0)
    }

    @Test
    func upgradesDailyDatabaseAndBackfillsHourlyBoundariesWithoutRestoringCleanedHistory() async throws {
        let f = try StorageFixture()
        defer { f.remove() }
        let file = try f.write([
            f.context("gpt-5.5"),
            f.event("2026-08-01T02:00:00Z", input: 100_000, output: 10_000),
            f.event("2026-09-20T15:59:59Z", input: 1_000, output: 100),
            f.event("2026-09-20T16:00:00Z", input: 2_000, output: 200),
            f.event("2026-09-20T16:59:59Z", input: 3_000, output: 300),
            f.event("2026-09-20T18:00:00Z", input: 0, output: 0),
        ])
        let database = try SQLiteStore(url: f.databaseURL)
        let first = await f.scanner(database).usage(at: f.now)
        #expect(first.hourlyUsage.map { $0.usage?.totalTokens } == [0, 5_500, 1_100, 110_000])
        #expect(first.hourlyUsage.map { f.calendar.component(.hour, from: $0.start) } == [2, 0, 23, 10])
        #expect(abs((first.hourlyUsage[1].usage?.apiEquivalentCostUSD ?? 0) - 0.04) < 1e-10)
        let cutoff = f.calendar.date(byAdding: .day, value: -30, to: f.now)!
        try database.cleanUsage(before: cutoff)
        try database.setData(Data("keep".utf8), namespace: "test", key: "preference")
        // Reproduce a v1 database: daily totals/checkpoints exist, hourly data does not.
        for row in try database.rows("SELECT scope,path,state FROM scan_files") {
            let data = try #require(row[2].data)
            var state = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            state.removeValue(forKey: "hasHourlyUsage")
            try database.execute("UPDATE scan_files SET state=? WHERE scope=? AND path=?",
                                 [.blob(try JSONSerialization.data(withJSONObject: state)), row[0], row[1]])
        }
        try database.execute("DROP TABLE hourly_usage")
        try database.execute("PRAGMA user_version=1")
        let upgraded = try SQLiteStore(url: f.databaseURL)
        #expect(try upgraded.rows("PRAGMA user_version").first?.first?.int == 2)
        #expect(try upgraded.data(namespace: "test", key: "preference") == Data("keep".utf8))
        let scanner = f.scanner(upgraded)
        let rebuilt = await scanner.usage(at: f.now)
        let fileBytes = try UInt64(Data(contentsOf: file).count)
        #expect(await scanner.bytesReadDuringLastScan == fileBytes)
        #expect(rebuilt.hourlyUsage.map { $0.usage?.totalTokens } == [0, 5_500, 1_100])
        #expect(rebuilt.dailyUsage.map { $0.usage?.totalTokens } == [5_500, 1_100])
        #expect(rebuilt.lifetime?.totalTokens == 6_600)
        let restored = f.scanner(try SQLiteStore(url: f.databaseURL))
        #expect(await restored.usage(at: f.now) == rebuilt)
        #expect(await restored.bytesReadDuringLastScan == 0)
    }

    @Test
    func cleanupSurvivesRestartRewritesArchivesAndNewUsageOnTheSameDay() async throws {
        let f = try StorageFixture()
        defer { f.remove() }
        let old = f.event("2026-08-01T02:00:00Z", input: 100_000, output: 10_000)
        let recent = f.event("2026-09-21T02:00:00Z", input: 100_000, output: 10_000)
        let lines = [f.context("gpt-6-astra"), old, recent]
        let file = try f.write(lines)
        let database = try SQLiteStore(url: f.databaseURL)
        let history = f.scanner(database)
        let today = f.scanner(database, scope: .today)
        #expect(await history.usage(at: f.now).lifetime?.totalTokens == 220_000)
        #expect(await today.usage(at: f.now).today.totalTokens == 110_000)
        let cutoff = f.calendar.date(byAdding: .day, value: -30, to: f.calendar.startOfDay(for: f.now))!
        try database.cleanUsage(before: cutoff)
        let cleaned = await history.usage(at: f.now)
        #expect(cleaned.lifetime?.totalTokens == 110_000)
        #expect(cleaned.monthlyUsage.count == 1)
        #expect(cleaned.dailyUsage.count == 1)
        #expect(cleaned.dailyUsage[0].usage?.totalTokens == 110_000)
        #expect(cleaned.hourlyUsage.count == 1)
        #expect(cleaned.hourlyUsage[0].usage?.totalTokens == 110_000)
        let restarted = f.scanner(try SQLiteStore(url: f.databaseURL))
        #expect(await restarted.usage(at: f.now) == cleaned)
        // A rewrite followed by an archive must not restore the excluded old date.
        try (lines.joined(separator: "\n") + "\n\n").write(to: file, atomically: true, encoding: .utf8)
        #expect(await restarted.usage(at: f.now).lifetime?.totalTokens == 110_000)
        try FileManager.default.moveItem(at: file, to: f.archive.appendingPathComponent(file.lastPathComponent))
        #expect(await restarted.usage(at: f.now).lifetime?.totalTokens == 110_000)
        try database.cleanUsage(before: f.now)
        #expect(await history.usage(at: f.now).lifetime == .zero)
        #expect(await today.usage(at: f.now).today == .zero)
        let archived = f.archive.appendingPathComponent(file.lastPathComponent)
        let handle = try FileHandle(forWritingTo: archived)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((f.event("2026-09-21T13:00:00Z", input: 1_000, output: 100) + "\n").utf8))
        try handle.close()
        let next = await restarted.usage(at: f.now.addingTimeInterval(3_600))
        #expect(next.today.totalTokens == 1_100)
        #expect(next.lifetime?.totalTokens == 1_100)
        #expect(next.hourlyUsage.map { $0.usage?.totalTokens } == [1_100])
        #expect(abs(next.today.apiEquivalentCostUSD - 0.015) < 1e-10)
        #expect(await f.scanner(try SQLiteStore(url: f.databaseURL)).usage(at: f.now) == next)
        #expect(try database.rows("PRAGMA integrity_check").first?.first?.string == "ok")
    }

    @Test
    func pricingBoundaryAndConcurrentCleanupKeepScopesConsistent() async throws {
        let f = try StorageFixture()
        defer { f.remove() }
        let a = f.event("2026-09-21T02:00:00Z", input: 272_000, cached: 200_000, write: 10_000, output: 10_000)
        let b = f.event("2026-09-21T03:00:00Z", input: 272_001, cached: 200_000, write: 10_000, output: 10_000)
        _ = try f.write([f.context("gpt-6-astra"), a, b])
        let database = try SQLiteStore(url: f.databaseURL)
        let scanner = f.scanner(database)
        let first = await scanner.usage(at: f.now)
        #expect(abs(first.today.apiEquivalentCostUSD - 4.08502) < 1e-10)
        let today = f.scanner(database, scope: .today)
        async let one = scanner.usage(at: f.now)
        async let two = today.usage(at: f.now)
        try await Task.detached { try database.cleanUsage(before: f.now) }.value
        _ = await (one, two)
        #expect(await scanner.usage(at: f.now).lifetime == .zero)
        #expect(await today.usage(at: f.now).today == .zero)
        #expect(try database.storageInfo().dailyRows == 0)
        #expect(try database.rows("SELECT COUNT(*) FROM hourly_usage").first?.first?.int == 0)
    }

    @Test
    func transactionsRollBackAndRejectNewerSchemas() throws {
        let f = try StorageFixture()
        defer { f.remove() }
        let database = try SQLiteStore(url: f.databaseURL)
        #expect(throws: SQLiteStore.Failure.self) {
            try database.transaction {
                try database.setData(Data([1]), namespace: "test", key: "uncommitted")
                try database.execute("INSERT INTO nonexistent VALUES(1)")
            }
        }
        #expect(try database.data(namespace: "test", key: "uncommitted") == nil)
        try database.execute("PRAGMA user_version=99")
        #expect(throws: SQLiteStore.Failure.self) { _ = try SQLiteStore(url: f.databaseURL) }
    }
}

private struct NoLoginChanges: LaunchAtLoginManaging {
    func setEnabled(_ isEnabled: Bool) throws {}
}

private struct StorageFixture {
    let root: URL
    let sessions: URL
    let archive: URL
    let calendar: Calendar
    let now: Date
    var databaseURL: URL { root.appendingPathComponent("meter.sqlite") }
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("MeterSQLite-\(UUID())")
        sessions = root.appendingPathComponent("sessions")
        archive = root.appendingPathComponent("archived_sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        calendar = c
        now = ISO8601DateFormatter().date(from: "2026-09-21T12:00:00Z")!
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func scanner(_ database: SQLiteStore, scope: LocalTokenUsageScanner.Scope = .lifetime, cache: URL? = nil) -> LocalTokenUsageScanner {
        LocalTokenUsageScanner(sessionsDirectory: sessions, archivedSessionsDirectory: archive,
                               scope: scope, cacheURL: cache, database: database, calendar: calendar)
    }
    func write(_ lines: [String]) throws -> URL {
        let file = sessions.appendingPathComponent("rollout-fixture.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }
    func context(_ model: String) -> String {
        "{\"type\":\"turn_context\",\"payload\":{\"model\":\"\(model)\"}}"
    }
    func event(_ timestamp: String, input: Int, cached: Int = 0, write: Int = 0, output: Int) -> String {
        "{\"timestamp\":\"\(timestamp)\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"last_token_usage\":{\"input_tokens\":\(input),\"cached_input_tokens\":\(cached),\"cache_write_input_tokens\":\(write),\"output_tokens\":\(output),\"reasoning_output_tokens\":3,\"total_tokens\":\(input + output)}}}}"
    }
}
