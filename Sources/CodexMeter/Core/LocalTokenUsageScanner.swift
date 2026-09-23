import Foundation
import Darwin

struct LocalTokenUsage: Codable, Equatable, Sendable {
    static let zero = LocalTokenUsage(
        totalTokens: 0,
        inputTokens: 0,
        cachedInputTokens: 0,
        cacheWriteInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0,
        apiEquivalentCostUSD: 0
    )

    let totalTokens: Int64
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let cacheWriteInputTokens: Int64
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
    let apiEquivalentCostUSD: Double

    var cacheHitPercentage: Double {
        guard inputTokens > 0 else { return 0 }
        return min(max(Double(cachedInputTokens) / Double(inputTokens), 0), 1)
    }

    func adding(_ other: LocalTokenUsage) -> LocalTokenUsage {
        LocalTokenUsage(
            totalTokens: Self.saturatingAdd(totalTokens, other.totalTokens),
            inputTokens: Self.saturatingAdd(inputTokens, other.inputTokens),
            cachedInputTokens: Self.saturatingAdd(cachedInputTokens, other.cachedInputTokens),
            cacheWriteInputTokens: Self.saturatingAdd(
                cacheWriteInputTokens,
                other.cacheWriteInputTokens
            ),
            outputTokens: Self.saturatingAdd(outputTokens, other.outputTokens),
            reasoningOutputTokens: Self.saturatingAdd(
                reasoningOutputTokens,
                other.reasoningOutputTokens
            ),
            apiEquivalentCostUSD: Self.finiteSum(
                apiEquivalentCostUSD,
                other.apiEquivalentCostUSD
            )
        )
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }

    private static func finiteSum(_ lhs: Double, _ rhs: Double) -> Double {
        let sum = lhs + rhs
        return sum.isFinite ? max(sum, 0) : .greatestFiniteMagnitude
    }
}

struct LocalTokenUsageSnapshot: Equatable, Sendable {
    let today: LocalTokenUsage
    let lifetime: LocalTokenUsage?
    var monthlyUsage: [MonthlyTokenUsage] = []
    var dailyUsage: [PeriodTokenUsage] = []
    var hourlyUsage: [PeriodTokenUsage] = []
}

protocol LocalTokenUsageLoading: Sendable {
    func usage(at now: Date) async -> LocalTokenUsageSnapshot
}

actor LocalTokenUsageScanner: LocalTokenUsageLoading {
    enum Scope {
        case today
        case lifetime
    }

    private struct FileState: Codable {
        var offset: UInt64 = 0
        var remainder = Data()
        var usageByDay: [Date: LocalTokenUsage] = [:]
        // Hourly totals, like daily totals, are stored in their own SQLite table.
        var usageByHour: [Date: LocalTokenUsage] = [:]
        // Missing on older checkpoints: reread that log once to recover exact hours.
        var hasHourlyUsage: Bool? = true
        var pricing = LocalTokenUsageScanner.pricing(for: nil)
        var modificationDate: Date?
        var lastReportedTotalTokens: Int64?
        var creationDate: Date?

        // Never serialize a partial log line: it can contain conversation content.
        enum CodingKeys: String, CodingKey {
            case offset, usageByDay, pricing, modificationDate, lastReportedTotalTokens, creationDate
            case hasHourlyUsage
        }
    }

    private struct PersistentCache: Codable {
        let version: Int
        let scope: String
        let timeZoneIdentifier: String
        let sessionsPath: String
        let archivedSessionsPath: String
        let files: [URL: FileState]
    }

    private struct RolloutEntry: Decodable {
        let timestamp: String?
        let type: String?
        let payload: Payload?

        struct Payload: Decodable {
            let type: String?
            let info: TokenInfo?
            let model: String?
        }

        struct TokenInfo: Decodable {
            let lastTokenUsage: TokenUsage?
            let totalTokenUsage: TokenUsage?

            enum CodingKeys: String, CodingKey {
                case lastTokenUsage = "last_token_usage"
                case totalTokenUsage = "total_token_usage"
            }
        }

        struct TokenUsage: Decodable {
            let inputTokens: Int64?
            let cachedInputTokens: Int64?
            let cacheWriteInputTokens: Int64?
            let outputTokens: Int64?
            let reasoningOutputTokens: Int64?
            let totalTokens: Int64?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case cachedInputTokens = "cached_input_tokens"
                case cacheWriteInputTokens = "cache_write_input_tokens"
                case outputTokens = "output_tokens"
                case reasoningOutputTokens = "reasoning_output_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }

    private struct ModelPricing: Codable {
        let inputUSDPerMillion: Double
        let cachedInputUSDPerMillion: Double
        let outputUSDPerMillion: Double
        var supportsLongContextPricing = false

        var cacheWriteInputUSDPerMillion: Double {
            inputUSDPerMillion * 1.25
        }
    }

    private let sessionsDirectory: URL
    private let archivedSessionsDirectory: URL
    private let fileManager: FileManager
    private let scope: Scope
    private let cacheURL: URL?
    private let database: SQLiteStore
    private var dirtyFiles = Set<URL>()
    private var removedFiles = Set<URL>()
    private var retentionCutoff: Date?
    private(set) var storageError: String?
    private var calendar: Calendar
    private let decoder = JSONDecoder()
    private let fractionalDateFormatter: ISO8601DateFormatter
    private let standardDateFormatter: ISO8601DateFormatter
    private var fileStates: [URL: FileState] = [:]
    private var hasLoadedCache = false
    private var cacheNeedsSave = false
    private(set) var bytesReadDuringLastScan: UInt64 = 0
    // Bump when parsing or pricing changes so cached amounts are recalculated.
    private static let cacheVersion = 1

    init(
        sessionsDirectory: URL? = nil,
        archivedSessionsDirectory: URL? = nil,
        scope: Scope = .lifetime,
        cacheURL: URL? = nil,
        database: SQLiteStore? = nil,
        fileManager: FileManager = .default,
        calendar inputCalendar: Calendar = .current
    ) {
        self.database = database ?? (sessionsDirectory == nil ? SQLiteStore.shared
            : try! SQLiteStore(url: cacheURL.map { $0.appendingPathExtension("sqlite") }))
        self.fileManager = fileManager
        self.scope = scope
        self.cacheURL = cacheURL ?? (sessionsDirectory == nil && ProcessInfo.processInfo.environment["CODEX_METER_DATA_DIRECTORY"] == nil
            ? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("CodexMeter", isDirectory: true)
                .appendingPathComponent(scope == .today ? "usage-today.json" : "usage-history.json")
            : nil)
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
        let resolvedSessionsDirectory = sessionsDirectory
            ?? Self.defaultSessionsDirectory(fileManager: fileManager)
        self.sessionsDirectory = resolvedSessionsDirectory
        self.archivedSessionsDirectory = archivedSessionsDirectory
            ?? resolvedSessionsDirectory.deletingLastPathComponent()
                .appendingPathComponent("archived_sessions", isDirectory: true)

        let fractionalDateFormatter = ISO8601DateFormatter()
        fractionalDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.fractionalDateFormatter = fractionalDateFormatter

        let standardDateFormatter = ISO8601DateFormatter()
        standardDateFormatter.formatOptions = [.withInternetDateTime]
        self.standardDateFormatter = standardDateFormatter
    }

    func usage(at now: Date = Date()) async -> LocalTokenUsageSnapshot {
        do {
            let cutoff = try database.retentionCutoff
            if cutoff != retentionCutoff {
                hasLoadedCache = false
                fileStates.removeAll()
                dirtyFiles.removeAll()
                removedFiles.removeAll()
                retentionCutoff = cutoff
            }
        } catch { storageError = error.localizedDescription }
        loadCacheIfNeeded()
        bytesReadDuringLastScan = 0
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return LocalTokenUsageSnapshot(today: .zero, lifetime: nil)
        }

        let isComplete = refreshCandidateFiles(modifiedSince: scope == .today ? dayStart : nil)
        if !saveCacheIfNeeded() {
            // Cleanup may finish while logs are being read. Discard this stale snapshot
            // and reload committed checkpoints before retrying.
            hasLoadedCache = false
            fileStates.removeAll()
            dirtyFiles.removeAll()
            removedFiles.removeAll()
            return await usage(at: now)
        }
        var today = LocalTokenUsage.zero
        var lifetime = LocalTokenUsage.zero
        var usageByMonth: [Date: LocalTokenUsage] = [:]
        var usageByDay: [Date: LocalTokenUsage] = [:]
        var usageByHour: [Date: LocalTokenUsage] = [:]
        // Stable summation order avoids sub-cent floating point changes after restart.
        for url in fileStates.keys.sorted(by: { $0.path < $1.path }) {
            guard let state = fileStates[url] else { continue }
            today = today.adding(state.usageByDay[dayStart] ?? .zero)
            if scope == .lifetime {
                for hour in state.usageByHour.keys.sorted() where hour < dayEnd {
                    guard let usage = state.usageByHour[hour] else { continue }
                    usageByHour[hour] = (usageByHour[hour] ?? .zero).adding(usage)
                }
            }
            for day in state.usageByDay.keys.sorted() where day < dayEnd {
                guard let usage = state.usageByDay[day] else { continue }
                lifetime = lifetime.adding(usage)
                if scope == .lifetime,
                   let month = calendar.dateInterval(of: .month, for: day)?.start {
                    usageByDay[day] = (usageByDay[day] ?? .zero).adding(usage)
                    usageByMonth[month] = (usageByMonth[month] ?? .zero).adding(usage)
                }
            }
        }
        return LocalTokenUsageSnapshot(
            today: today,
            lifetime: scope == .lifetime && isComplete ? lifetime : nil,
            monthlyUsage: scope == .lifetime && isComplete
                ? usageByMonth.map { MonthlyTokenUsage(month: $0.key, usage: $0.value) }
                    .sorted { $0.month > $1.month }
                : [],
            dailyUsage: scope == .lifetime && isComplete
                ? usageByDay.map { PeriodTokenUsage(start: $0.key, usage: $0.value) }
                    .sorted { $0.start > $1.start }
                : [],
            hourlyUsage: scope == .lifetime && isComplete
                ? usageByHour.map { PeriodTokenUsage(start: $0.key, usage: $0.value) }
                    .sorted { $0.start > $1.start }
                : []
        )
    }

    private static func defaultSessionsDirectory(fileManager: FileManager) -> URL {
        let environment = ProcessInfo.processInfo.environment
        let codexHome: URL
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            codexHome = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        } else {
            codexHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }
        return codexHome.appendingPathComponent("sessions", isDirectory: true)
    }

    private var cacheScope: String { scope == .today ? "today" : "lifetime" }

    private var cacheIdentity: String {
        "\(Self.cacheVersion)|\(calendar.timeZone.identifier)|\(sessionsDirectory.standardizedFileURL.path)|\(archivedSessionsDirectory.standardizedFileURL.path)"
    }

    private func loadCacheIfNeeded() {
        guard !hasLoadedCache else { return }
        do {
            try database.transaction {
                let identity = try database.data(namespace: "scanner", key: cacheScope)
                if identity != Data(cacheIdentity.utf8) {
                    try database.execute("DELETE FROM scan_files WHERE scope=?", [.text(cacheScope)])
                    try database.setData(Data(cacheIdentity.utf8), namespace: "scanner", key: cacheScope)
                    // One-time import of the old JSON cache. Files remain untouched until
                    // the relational copy and cursor positions have committed together.
                    if identity == nil, let cacheURL,
                       let data = try? Data(contentsOf: cacheURL),
                       let cache = try? decoder.decode(PersistentCache.self, from: data),
                       cache.version == Self.cacheVersion, cache.scope == cacheScope,
                       cache.timeZoneIdentifier == calendar.timeZone.identifier,
                       cache.sessionsPath == sessionsDirectory.standardizedFileURL.path,
                       cache.archivedSessionsPath == archivedSessionsDirectory.standardizedFileURL.path {
                        for (url, var state) in cache.files {
                            state.usageByDay = state.usageByDay.filter { day, _ in retentionCutoff.map { day >= $0 } ?? true }
                            try persistFile(url, state: state)
                        }
                    }
                }
                fileStates.removeAll()
                for row in try database.rows("SELECT path,state FROM scan_files WHERE scope=?", [.text(cacheScope)]) {
                    guard let path = row[0].string, let data = row[1].data else { continue }
                    fileStates[URL(fileURLWithPath: path)] = try decoder.decode(FileState.self, from: data)
                }
                for row in try database.rows("SELECT path,day,total,input,cached,cache_write,output,reasoning,cost FROM daily_usage WHERE scope=?", [.text(cacheScope)]) {
                    guard let path = row[0].string else { continue }
                    let url = URL(fileURLWithPath: path)
                    fileStates[url]?.usageByDay[Date(timeIntervalSinceReferenceDate: row[1].double)] = LocalTokenUsage(
                        totalTokens: row[2].int, inputTokens: row[3].int, cachedInputTokens: row[4].int,
                        cacheWriteInputTokens: row[5].int, outputTokens: row[6].int,
                        reasoningOutputTokens: row[7].int, apiEquivalentCostUSD: row[8].double)
                }
                for row in try database.rows("SELECT path,hour,total,input,cached,cache_write,output,reasoning,cost FROM hourly_usage WHERE scope=?", [.text(cacheScope)]) {
                    guard let path = row[0].string else { continue }
                    let url = URL(fileURLWithPath: path)
                    fileStates[url]?.usageByHour[Date(timeIntervalSinceReferenceDate: row[1].double)] = LocalTokenUsage(
                        totalTokens: row[2].int, inputTokens: row[3].int, cachedInputTokens: row[4].int,
                        cacheWriteInputTokens: row[5].int, outputTokens: row[6].int,
                        reasoningOutputTokens: row[7].int, apiEquivalentCostUSD: row[8].double)
                }
            }
            hasLoadedCache = true
            if let cacheURL { try? fileManager.removeItem(at: cacheURL) }
        } catch {
            storageError = error.localizedDescription
            database.recordFailure(error)
        }
    }

    private func persistFile(_ url: URL, state: FileState) throws {
        var checkpoint = state
        checkpoint.offset -= UInt64(state.remainder.count)
        checkpoint.remainder = Data()
        checkpoint.usageByDay = [:]
        checkpoint.usageByHour = [:]
        let key: [SQLiteStore.Value] = [.text(cacheScope), .text(url.path)]
        try database.execute("INSERT INTO scan_files VALUES(?,?,?) ON CONFLICT(scope,path) DO UPDATE SET state=excluded.state",
                             key + [.blob(try JSONEncoder().encode(checkpoint))])
        try database.execute("DELETE FROM daily_usage WHERE scope=? AND path=?", key)
        for (day, usage) in state.usageByDay {
            try database.execute("INSERT INTO daily_usage VALUES(?,?,?,?,?,?,?,?,?,?)", key + [
                .real(day.timeIntervalSinceReferenceDate), .integer(usage.totalTokens), .integer(usage.inputTokens),
                .integer(usage.cachedInputTokens), .integer(usage.cacheWriteInputTokens), .integer(usage.outputTokens),
                .integer(usage.reasoningOutputTokens), .real(usage.apiEquivalentCostUSD)
            ])
        }
        try database.execute("DELETE FROM hourly_usage WHERE scope=? AND path=?", key)
        for (hour, usage) in state.usageByHour {
            try database.execute("INSERT INTO hourly_usage VALUES(?,?,?,?,?,?,?,?,?,?)", key + [
                .real(hour.timeIntervalSinceReferenceDate), .integer(usage.totalTokens), .integer(usage.inputTokens),
                .integer(usage.cachedInputTokens), .integer(usage.cacheWriteInputTokens), .integer(usage.outputTokens),
                .integer(usage.reasoningOutputTokens), .real(usage.apiEquivalentCostUSD)
            ])
        }
    }

    @discardableResult
    private func saveCacheIfNeeded() -> Bool {
        do {
            var didSave = false
            let current = try database.transaction {
                guard try database.retentionCutoff == retentionCutoff else { return false }
                guard cacheNeedsSave else { return true }
                for url in removedFiles {
                    try database.execute("DELETE FROM scan_files WHERE scope=? AND path=?", [.text(cacheScope), .text(url.path)])
                }
                for url in dirtyFiles {
                    if let state = fileStates[url] { try persistFile(url, state: state) }
                }
                didSave = true
                return true
            }
            if didSave {
                cacheNeedsSave = false
                dirtyFiles.removeAll()
                removedFiles.removeAll()
                storageError = nil
            }
            return current
        } catch {
            storageError = error.localizedDescription
            database.recordFailure(error)
            return true // Continue displaying live usage and retry persistence next scan.
        }
    }

    private func refreshCandidateFiles(modifiedSince: Date?) -> Bool {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .creationDateKey,
        ]
        var candidates = Set<URL>()
        var sessionNames = Set<String>()
        var foundDirectory = false
        var isComplete = true
        for directory in [sessionsDirectory, archivedSessionsDirectory] {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in
                    isComplete = false
                    return true
                }
            ) else {
                isComplete = false
                continue
            }
            foundDirectory = true
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl",
                      fileURL.lastPathComponent.hasPrefix("rollout-"),
                      sessionNames.insert(fileURL.lastPathComponent).inserted
                else { continue }

                let standardizedURL = fileURL.standardizedFileURL
                guard let values = try? standardizedURL.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true,
                      let modificationDate = values.contentModificationDate
                else {
                    isComplete = false
                    continue
                }
                if let modifiedSince, modificationDate < modifiedSince { continue }

                candidates.insert(standardizedURL)
                if !updateFile(
                    at: standardizedURL,
                    fileSize: max(values.fileSize ?? 0, 0),
                    modificationDate: modificationDate,
                    creationDate: values.creationDate
                ) {
                    isComplete = false
                }
            }
        }

        let previousCount = fileStates.count
        removedFiles.formUnion(fileStates.keys.filter { !candidates.contains($0) })
        fileStates = fileStates.filter { candidates.contains($0.key) }
        if fileStates.count != previousCount { cacheNeedsSave = true }
        return foundDirectory && isComplete
    }

    private func updateFile(
        at url: URL,
        fileSize: Int,
        modificationDate: Date,
        creationDate: Date?
    ) -> Bool {
        var state = fileStates[url] ?? FileState()
        let size = UInt64(fileSize)
        let wasTouchedWithoutGrowth = state.modificationDate.map {
            size == state.offset && modificationDate > $0
        } ?? false

        if state.hasHourlyUsage != true || size < state.offset || wasTouchedWithoutGrowth || state.creationDate != creationDate {
            state = FileState()
            dirtyFiles.insert(url)
            cacheNeedsSave = true
        }
        state.creationDate = creationDate

        if size > state.offset || state.modificationDate != modificationDate {
            dirtyFiles.insert(url)
            cacheNeedsSave = true
        }
        guard size > state.offset else {
            if state.modificationDate != modificationDate { cacheNeedsSave = true }
            state.modificationDate = modificationDate
            fileStates[url] = state
            return true
        }

        var buffer = state.remainder
        state.remainder = Data()
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: state.offset)
            // Read only the size observed at the start, even if Codex keeps appending.
            while state.offset < size {
                // Foundation decoding and file reads create autoreleased objects. A
                // history scan can run for seconds without returning to the run loop.
                let didRead = try autoreleasepool {
                    guard let data = try handle.read(upToCount: Int(min(1_024 * 1_024, size - state.offset))),
                          !data.isEmpty else { return false }
                    state.offset += UInt64(data.count)
                    bytesReadDuringLastScan += UInt64(data.count)
                    cacheNeedsSave = true
                    let previousCount = buffer.count
                    buffer.append(data)
                    var lineStart = buffer.startIndex
                    // Search only new bytes. Rescanning a growing image/tool-result line
                    // on every chunk makes a large rollout take quadratic time.
                    for offset in Self.newlineOffsets(in: data) {
                        let index = buffer.index(buffer.startIndex, offsetBy: previousCount + offset)
                        let line = buffer[lineStart..<index]
                        if Self.containsUsageRecord(line) {
                            process(Data(line), state: &state)
                        }
                        lineStart = buffer.index(after: index)
                    }
                    if lineStart != buffer.startIndex {
                        buffer = Data(buffer[lineStart..<buffer.endIndex])
                    }
                    return true
                }
                if !didRead { break }
            }
            state.remainder = buffer
            state.modificationDate = modificationDate
            fileStates[url] = state
            return true
        } catch {
            // A session may be moved or replaced while Codex is writing it.
            // Leave the previous total intact and retry on the next refresh.
            state.remainder = buffer
            fileStates[url] = state
            return false
        }
    }

    private static let tokenCountMarker = Data("\"token_count\"".utf8)
    private static let turnContextMarker = Data("\"turn_context\"".utf8)

    private static func containsUsageRecord(_ line: Data) -> Bool {
        // Most rollout bytes are conversation content, images and tool results.
        // Avoid decoding those records; the decoder still validates every candidate.
        line.range(of: tokenCountMarker) != nil || line.range(of: turnContextMarker) != nil
    }

    private static func newlineOffsets(in data: Data) -> [Int] {
        data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return [] }
            var offsets: [Int] = []
            var cursor = 0
            while cursor < bytes.count,
                  let match = memchr(base.advanced(by: cursor), 0x0A, bytes.count - cursor) {
                let offset = base.distance(to: UnsafeRawPointer(match))
                offsets.append(offset)
                cursor = offset + 1
            }
            return offsets
        }
    }

    private func process(
        _ data: Data,
        state: inout FileState
    ) {
        guard let entry = try? decoder.decode(RolloutEntry.self, from: data) else {
            return
        }

        if entry.type == "turn_context" {
            if let model = entry.payload?.model?.trimmingCharacters(in: .whitespacesAndNewlines),
               !model.isEmpty {
                state.pricing = Self.pricing(for: model)
            }
            return
        }

        guard
              entry.type == "event_msg",
              entry.payload?.type == "token_count",
              let timestamp = entry.timestamp,
              let eventDate = fractionalDateFormatter.date(from: timestamp)
                ?? standardDateFormatter.date(from: timestamp),
              let tokenUsage = entry.payload?.info?.lastTokenUsage
        else { return }

        // Quota updates can repeat the previous request's last_token_usage.
        if let reportedTotal = entry.payload?.info?.totalTokenUsage?.totalTokens {
            guard reportedTotal != state.lastReportedTotalTokens else { return }
            state.lastReportedTotalTokens = reportedTotal
        }

        if let retentionCutoff, eventDate < retentionCutoff { return }

        let inputTokens = max(tokenUsage.inputTokens ?? 0, 0)
        let cachedInputTokens = min(
            max(tokenUsage.cachedInputTokens ?? 0, 0),
            inputTokens
        )
        let remainingInputTokens = inputTokens - cachedInputTokens
        let cacheWriteInputTokens = min(
            max(tokenUsage.cacheWriteInputTokens ?? 0, 0),
            remainingInputTokens
        )
        let outputTokens = max(tokenUsage.outputTokens ?? 0, 0)
        let reasoningOutputTokens = min(
            max(tokenUsage.reasoningOutputTokens ?? 0, 0),
            outputTokens
        )
        let totalTokens = max(
            tokenUsage.totalTokens
                ?? Self.saturatingAdd(inputTokens, outputTokens),
            0
        )

        let usage = LocalTokenUsage(
            totalTokens: totalTokens,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            apiEquivalentCostUSD: Self.apiEquivalentCostUSD(
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                cacheWriteInputTokens: cacheWriteInputTokens,
                outputTokens: outputTokens,
                pricing: state.pricing
            )
        )
        let day = calendar.startOfDay(for: eventDate)
        state.usageByDay[day, default: .zero] = state.usageByDay[day, default: .zero].adding(usage)
        if let hour = calendar.dateInterval(of: .hour, for: eventDate)?.start {
            state.usageByHour[hour, default: .zero] = state.usageByHour[hour, default: .zero].adding(usage)
        }
    }

    private static func apiEquivalentCostUSD(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        cacheWriteInputTokens: Int64,
        outputTokens: Int64,
        pricing: ModelPricing
    ) -> Double {
        let uncachedInputTokens = max(
            inputTokens - cachedInputTokens - cacheWriteInputTokens,
            0
        )
        let isLongContext = pricing.supportsLongContextPricing && inputTokens > 272_000
        let inputMultiplier = isLongContext ? 2.0 : 1.0
        let outputMultiplier = isLongContext ? 1.5 : 1.0

        let inputCost = Double(uncachedInputTokens)
            * pricing.inputUSDPerMillion
            * inputMultiplier
        let cachedInputCost = Double(cachedInputTokens)
            * pricing.cachedInputUSDPerMillion
            * inputMultiplier
        let cacheWriteCost = Double(cacheWriteInputTokens)
            * pricing.cacheWriteInputUSDPerMillion
            * inputMultiplier
        let outputCost = Double(outputTokens)
            * pricing.outputUSDPerMillion
            * outputMultiplier
        return (inputCost + cachedInputCost + cacheWriteCost + outputCost) / 1_000_000
    }

    private static func pricing(for model: String?) -> ModelPricing {
        // Standard USD rates per million tokens, checked on 2026-09-21.
        // https://developers.openai.com/api/docs/pricing
        // Codex-specific rates: https://developers.openai.com/api/docs/models/<model-id>
        let identifier = model?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let rates: [(String, Double, Double, Double, Bool)] = [
            ("gpt-6-astra", 10, 1, 50, true),
            ("gpt-5.6-sol", 4, 0.4, 20, true),
            ("gpt-5.6-terra", 2, 0.2, 12, true),
            ("gpt-5.6-luna", 0.2, 0.02, 1.2, true),
            ("gpt-5.5-pro", 30, 30, 180, true),
            ("gpt-5.5", 5, 0.5, 30, true),
            ("gpt-5.4-pro", 30, 30, 180, true),
            ("gpt-5.4-mini", 0.75, 0.075, 4.5, false),
            ("gpt-5.4-nano", 0.2, 0.02, 1.25, false),
            ("gpt-5.4", 2.5, 0.25, 15, true),
            ("gpt-5.3-codex", 1.75, 0.175, 14, false),
            ("gpt-5.2-codex", 1.75, 0.175, 14, false),
            ("gpt-5.2-pro", 21, 21, 168, false),
            ("gpt-5.2", 1.75, 0.175, 14, false),
            ("gpt-5.1-codex-mini", 0.25, 0.025, 2, false),
            ("gpt-5.1-codex-max", 1.25, 0.125, 10, false),
            ("gpt-5.1-codex", 1.25, 0.125, 10, false),
            ("gpt-5.1", 1.25, 0.125, 10, false),
            ("gpt-5-codex", 1.25, 0.125, 10, false),
            ("gpt-5-mini", 0.25, 0.025, 2, false),
            ("gpt-5-nano", 0.05, 0.005, 0.4, false),
            ("gpt-5", 1.25, 0.125, 10, false),
            ("codex-mini-latest", 1.5, 0.375, 6, false),
            ("o4-mini", 1.1, 0.275, 4.4, false),
            ("o3", 2, 0.5, 8, false),
        ]
        for (name, input, cached, output, longContext) in rates {
            let suffix = identifier.hasPrefix(name + "-")
                ? String(identifier.dropFirst(name.count + 1)) : ""
            let isDatedSnapshot = suffix.range(
                of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression
            ) != nil
            if identifier == name || isDatedSnapshot {
                return ModelPricing(
                    inputUSDPerMillion: input,
                    cachedInputUSDPerMillion: cached,
                    outputUSDPerMillion: output,
                    supportsLongContextPricing: longContext
                )
            }
        }

        // GPT-5.6 Sol is also the fallback for Codex internal routing names.
        return ModelPricing(
            inputUSDPerMillion: 4.00,
            cachedInputUSDPerMillion: 0.40,
            outputUSDPerMillion: 20.00,
            supportsLongContextPricing: true
        )
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }
}
