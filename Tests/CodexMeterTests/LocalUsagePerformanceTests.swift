import Darwin
import Foundation
import Testing
@testable import CodexMeter

/// Opt in with CODEX_METER_PERF=1 and run this suite alone in a release build.
/// All files are synthetic, live in a new temporary directory and are removed.
struct LocalUsagePerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CODEX_METER_PERF"] == "1"))
    func largeSyntheticTodayScan() async throws {
        let fixture = try SyntheticUsageVolume()
        defer { fixture.remove() }
        let bytes = try fixture.generate()
        print("PERF_DATASET events=\(fixture.events) active_files=\(fixture.fileCount) historical_files=\(fixture.historicalFiles) bytes=\(bytes) payload_bytes_per_event=\(fixture.payloadBytes)")
        var scanner: LocalTokenUsageScanner? = fixture.scanner()
        let cold = try await measure("cold", scanner: try #require(scanner), fixture: fixture)
        try check(cold, events: fixture.events)
        #expect(await scanner?.bytesReadDuringLastScan == bytes)

        for iteration in 1...3 {
            let warm = try await measure("warm_\(iteration)", scanner: try #require(scanner), fixture: fixture)
            #expect(warm == cold)
            #expect(await scanner?.bytesReadDuringLastScan == 0)
        }

        // Release the scanner and its SQLite connection before loading checkpoints.
        scanner = nil
        scanner = fixture.scanner()
        let restored = try await measure("sqlite_restore", scanner: try #require(scanner), fixture: fixture)
        #expect(restored == cold)
        #expect(await scanner?.bytesReadDuringLastScan == 0)

        let appendedEvents = 1_000
        let appendedBytes = try fixture.append(events: appendedEvents)
        let appended = try await measure("append", scanner: try #require(scanner), fixture: fixture)
        try check(appended, events: fixture.events + appendedEvents)
        #expect(await scanner?.bytesReadDuringLastScan == appendedBytes)
    }

    private func check(_ snapshot: LocalTokenUsageSnapshot, events: Int) throws {
        #expect(snapshot.today.totalTokens == Int64(events) * 1_200)
        #expect(snapshot.today.inputTokens == Int64(events) * 1_000)
        #expect(snapshot.today.cachedInputTokens == Int64(events) * 600)
        #expect(snapshot.today.cacheWriteInputTokens == Int64(events) * 100)
        #expect(snapshot.today.outputTokens == Int64(events) * 200)
        #expect(snapshot.dailyModelUsage.count == 1)
        #expect(try #require(snapshot.dailyModelUsage.first).usage == snapshot.today)
        #expect(snapshot.lifetime == nil && snapshot.dailyUsage.isEmpty)
    }

    private func measure(_ phase: String, scanner: LocalTokenUsageScanner,
                         fixture: SyntheticUsageVolume) async throws -> LocalTokenUsageSnapshot {
        let before = ProcessResources.sample()
        let start = ContinuousClock.now
        let snapshot = await scanner.usage(at: fixture.now)
        let duration = start.duration(to: .now).components
        let seconds = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        let after = ProcessResources.sample()
        let bytes = await scanner.bytesReadDuringLastScan
        #expect(await scanner.storageError == nil)
        let record = PerformanceRecord(phase: phase, seconds: seconds, bytesRead: bytes,
                                       cpuSeconds: after.cpuSeconds - before.cpuSeconds,
                                       rssBeforeBytes: before.rssBytes, rssAfterBytes: after.rssBytes,
                                       processPeakRSSBytes: after.peakRSSBytes)
        print("PERF " + String(decoding: try JSONEncoder().encode(record), as: UTF8.self))
        return snapshot
    }
}

private struct PerformanceRecord: Encodable {
    let phase: String
    let seconds: Double
    let bytesRead: UInt64
    let cpuSeconds: Double
    let rssBeforeBytes: UInt64?
    let rssAfterBytes: UInt64?
    // On Darwin ru_maxrss is bytes; this is the process peak, including generation.
    let processPeakRSSBytes: Int64?
}

private struct ProcessResources {
    let cpuSeconds: Double
    let rssBytes: UInt64?
    let peakRSSBytes: Int64?

    static func sample() -> ProcessResources {
        var resources = rusage()
        let sampled = getrusage(RUSAGE_SELF, &resources) == 0
        let cpu = Double(resources.ru_utime.tv_sec + resources.ru_stime.tv_sec)
            + Double(resources.ru_utime.tv_usec + resources.ru_stime.tv_usec) / 1_000_000
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return ProcessResources(cpuSeconds: cpu, rssBytes: result == KERN_SUCCESS ? info.resident_size : nil,
                                peakRSSBytes: sampled ? Int64(resources.ru_maxrss) : nil)
    }
}

private struct SyntheticUsageVolume {
    let root: URL
    let sessions: URL
    let archived: URL
    let calendar: Calendar
    let now = Date(timeIntervalSince1970: 1_760_529_600) // 2025-10-15 12:00:00 UTC
    let events: Int
    let fileCount: Int
    let historicalFiles: Int
    let payloadBytes: Int
    private let fileManager = FileManager.default

    init() throws {
        func option(_ name: String, default fallback: Int, range: ClosedRange<Int>) throws -> Int {
            guard let raw = ProcessInfo.processInfo.environment[name] else { return fallback }
            guard let value = Int(raw), range.contains(value) else {
                throw BenchmarkError.invalidOption(name)
            }
            return value
        }
        events = try option("CODEX_METER_PERF_EVENTS", default: 1_000_000, range: 1_000...2_000_000)
        fileCount = try option("CODEX_METER_PERF_FILES", default: 200, range: 1...1_000)
        historicalFiles = try option("CODEX_METER_PERF_HISTORY_FILES", default: 2_000, range: 0...20_000)
        payloadBytes = try option("CODEX_METER_PERF_PAYLOAD_BYTES", default: 1_024, range: 0...8_192)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        root = FileManager.default.temporaryDirectory.appendingPathComponent("codex-meter-benchmark-\(UUID().uuidString)")
        sessions = root.appendingPathComponent("sessions")
        archived = root.appendingPathComponent("archived_sessions")
        try fileManager.createDirectory(at: sessions, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: archived, withIntermediateDirectories: true)
    }

    func scanner() -> LocalTokenUsageScanner {
        LocalTokenUsageScanner(sessionsDirectory: sessions, archivedSessionsDirectory: archived,
                               scope: .today, cacheURL: root.appendingPathComponent("usage-cache.json"),
                               calendar: calendar)
    }

    func generate() throws -> UInt64 {
        var total: UInt64 = 0
        let payload = Data(("{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"content\":\""
            + String(repeating: "x", count: payloadBytes) + "\"}}\n").utf8)
        for index in 0..<fileCount {
            let url = activeFile(index)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let count = events / fileCount + (index < events % fileCount ? 1 : 0)
            try Data().write(to: url)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            let context = Data("{\"type\":\"turn_context\",\"payload\":{\"model\":\"gpt-6.1-sol\",\"service_tier\":\"standard\"}}\n".utf8)
            try handle.write(contentsOf: context)
            total += UInt64(context.count)
            var buffer = Data()
            buffer.reserveCapacity(1_048_576 + payload.count)
            for event in 0..<count {
                buffer.append(payload)
                buffer.append(tokenLine(event: event, cumulative: (event + 1) * 1_200))
                if buffer.count >= 1_048_576 {
                    try handle.write(contentsOf: buffer)
                    total += UInt64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            try handle.write(contentsOf: buffer)
            total += UInt64(buffer.count)
            try fileManager.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
        }
        // Old files exercise directory traversal without scanning historical content.
        for index in 0..<historicalFiles {
            let directory = index.isMultiple(of: 2) ? sessions : archived
            let url = directory.appendingPathComponent("rollout-history-\(index).jsonl")
            try payload.write(to: url)
            try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(-172_800)], ofItemAtPath: url.path)
        }
        return total
    }

    func append(events count: Int) throws -> UInt64 {
        let file = activeFile(0)
        let originalCount = events / fileCount + (events % fileCount > 0 ? 1 : 0)
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        var data = Data()
        for event in 0..<count {
            data.append(tokenLine(event: event, cumulative: (originalCount + event + 1) * 1_200))
        }
        try handle.write(contentsOf: data)
        try fileManager.setAttributes([.modificationDate: now.addingTimeInterval(1)], ofItemAtPath: file.path)
        return UInt64(data.count)
    }

    func remove() { try? fileManager.removeItem(at: root) }

    private func activeFile(_ index: Int) -> URL {
        sessions.appendingPathComponent("2025/10/15/rollout-synthetic-\(index).jsonl")
    }

    private func tokenLine(event: Int, cumulative: Int) -> Data {
        func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : String(value) }
        let hour = twoDigits(event % 12)
        let minute = twoDigits((event / 12) % 60)
        return Data("{\"timestamp\":\"2025-10-15T\(hour):\(minute):00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"total_tokens\":\(cumulative)},\"last_token_usage\":{\"input_tokens\":1000,\"cached_input_tokens\":600,\"cache_write_input_tokens\":100,\"output_tokens\":200,\"reasoning_output_tokens\":50,\"total_tokens\":1200}}}}\n".utf8)
    }
}

private enum BenchmarkError: Error {
    case invalidOption(String)
}
