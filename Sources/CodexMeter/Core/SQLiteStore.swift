import Foundation
import SQLite3

/// All application-owned persistent data lives in this database. Access is serialized;
/// scanners perform their file I/O outside the database lock.
final class SQLiteStore: @unchecked Sendable {
    static let shared: SQLiteStore = {
        do { return try SQLiteStore(url: defaultURL) }
        catch { fatalError("Cannot open Codex Meter storage: \(error.localizedDescription)") }
    }()

    static var defaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_METER_DATA_DIRECTORY"] {
            return URL(fileURLWithPath: path).appendingPathComponent("meter.sqlite")
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexMeter/meter.sqlite")
    }

    enum Value {
        case text(String), integer(Int64), real(Double), blob(Data), null
        var string: String? { if case let .text(v) = self { return v }; return nil }
        var data: Data? { if case let .blob(v) = self { return v }; return nil }
        var int: Int64 { if case let .integer(v) = self { return v }; return 0 }
        var double: Double {
            if case let .real(v) = self { return v }
            if case let .integer(v) = self { return Double(v) }
            return 0
        }
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let url: URL?
    private let lock = NSRecursiveLock()
    private var connection: OpaquePointer?
    private var failureMessage: String?
    var lastError: String? { lock.withLock { failureMessage } }

    init(url: URL? = nil) throws {
        self.url = url
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let result = sqlite3_open_v2(url?.path ?? ":memory:", &connection,
                                     SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard result == SQLITE_OK else {
            let error = failure()
            sqlite3_close(connection)
            connection = nil
            throw error
        }
        do {
            sqlite3_busy_timeout(connection, 5_000)
            try execute("PRAGMA foreign_keys = ON")
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA synchronous = NORMAL")
            let version = try rows("PRAGMA user_version").first?.first?.int ?? 0
            guard version <= 2 else { throw Failure(message: "This database requires a newer Codex Meter version.") }
            try transaction {
                try execute("CREATE TABLE IF NOT EXISTS records(namespace TEXT NOT NULL, key TEXT NOT NULL, value BLOB NOT NULL, PRIMARY KEY(namespace,key))")
                try execute("CREATE TABLE IF NOT EXISTS scan_files(scope TEXT NOT NULL, path TEXT NOT NULL, state BLOB NOT NULL, PRIMARY KEY(scope,path))")
                try execute("""
                    CREATE TABLE IF NOT EXISTS daily_usage(
                      scope TEXT NOT NULL, path TEXT NOT NULL, day REAL NOT NULL,
                      total INTEGER NOT NULL, input INTEGER NOT NULL, cached INTEGER NOT NULL,
                      cache_write INTEGER NOT NULL, output INTEGER NOT NULL, reasoning INTEGER NOT NULL,
                      cost REAL NOT NULL, PRIMARY KEY(scope,path,day),
                      FOREIGN KEY(scope,path) REFERENCES scan_files(scope,path) ON DELETE CASCADE)
                    """)
                try execute("CREATE INDEX IF NOT EXISTS daily_usage_day ON daily_usage(day,scope)")
                try execute("""
                    CREATE TABLE IF NOT EXISTS hourly_usage(
                      scope TEXT NOT NULL, path TEXT NOT NULL, hour REAL NOT NULL,
                      total INTEGER NOT NULL, input INTEGER NOT NULL, cached INTEGER NOT NULL,
                      cache_write INTEGER NOT NULL, output INTEGER NOT NULL, reasoning INTEGER NOT NULL,
                      cost REAL NOT NULL, PRIMARY KEY(scope,path,hour),
                      FOREIGN KEY(scope,path) REFERENCES scan_files(scope,path) ON DELETE CASCADE)
                    """)
                try execute("CREATE INDEX IF NOT EXISTS hourly_usage_hour ON hourly_usage(hour,scope)")
                try execute("PRAGMA user_version = 2")
            }
        } catch {
            sqlite3_close(connection)
            connection = nil
            throw error
        }
    }

    deinit { sqlite3_close(connection) }

    private func failure() -> Failure {
        Failure(message: connection.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite is unavailable")
    }

    func recordFailure(_ error: Error) {
        lock.withLock { failureMessage = error.localizedDescription }
    }

    private func prepare(_ sql: String, _ bindings: [Value]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case let .text(v): result = sqlite3_bind_text(statement, index, v, -1, transient)
            case let .integer(v): result = sqlite3_bind_int64(statement, index, v)
            case let .real(v): result = sqlite3_bind_double(statement, index, v)
            case let .blob(v):
                result = v.withUnsafeBytes { bytes in
                    if bytes.isEmpty { return sqlite3_bind_zeroblob(statement, index, 0) }
                    return sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(bytes.count), transient)
                }
            case .null: result = sqlite3_bind_null(statement, index)
            }
            if result != SQLITE_OK { sqlite3_finalize(statement); throw failure() }
        }
        return statement
    }

    func execute(_ sql: String, _ bindings: [Value] = []) throws {
        try lock.withLock {
            let statement = try prepare(sql, bindings)
            defer { sqlite3_finalize(statement) }
            var result = sqlite3_step(statement)
            while result == SQLITE_ROW { result = sqlite3_step(statement) }
            guard result == SQLITE_DONE else { throw failure() }
        }
    }

    func rows(_ sql: String, _ bindings: [Value] = []) throws -> [[Value]] {
        try lock.withLock {
            let statement = try prepare(sql, bindings)
            defer { sqlite3_finalize(statement) }
            var result: [[Value]] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return result }
                guard status == SQLITE_ROW else { throw failure() }
                result.append((0..<sqlite3_column_count(statement)).map { index in
                    switch sqlite3_column_type(statement, index) {
                    case SQLITE_INTEGER: return .integer(sqlite3_column_int64(statement, index))
                    case SQLITE_FLOAT: return .real(sqlite3_column_double(statement, index))
                    case SQLITE_TEXT: return .text(String(cString: sqlite3_column_text(statement, index)))
                    case SQLITE_BLOB:
                        let length = Int(sqlite3_column_bytes(statement, index))
                        return .blob(sqlite3_column_blob(statement, index).map { Data(bytes: $0, count: length) } ?? Data())
                    default: return .null
                    }
                })
            }
        }
    }

    @discardableResult
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try lock.withLock {
            try execute("BEGIN IMMEDIATE")
            do {
                let value = try body()
                try execute("COMMIT")
                return value
            } catch {
                try? execute("ROLLBACK")
                throw error
            }
        }
    }

    func data(namespace: String, key: String) throws -> Data? {
        try rows("SELECT value FROM records WHERE namespace=? AND key=?", [.text(namespace), .text(key)]).first?.first?.data
    }

    func setData(_ data: Data?, namespace: String, key: String) throws {
        if let data {
            try execute("INSERT INTO records VALUES(?,?,?) ON CONFLICT(namespace,key) DO UPDATE SET value=excluded.value",
                        [.text(namespace), .text(key), .blob(data)])
        } else {
            try execute("DELETE FROM records WHERE namespace=? AND key=?", [.text(namespace), .text(key)])
        }
    }

    var retentionCutoff: Date? {
        get throws {
            guard let data = try data(namespace: "metadata", key: "retentionCutoff"),
                  let value = Double(String(decoding: data, as: UTF8.self)) else { return nil }
            return Date(timeIntervalSinceReferenceDate: value)
        }
    }

    func storageInfo() throws -> StorageInfo {
        try lock.withLock {
            let row = try rows("SELECT COUNT(*), MIN(day), MAX(day) FROM daily_usage WHERE scope='lifetime'").first!
            let images = try rows("SELECT COALESCE(SUM(length(value)),0) FROM records WHERE namespace='images'").first!.first!.int
            let count = try rows("SELECT COUNT(*) FROM scan_files").first!.first!.int
            let bytes: Int64 = [url, url.map { URL(fileURLWithPath: $0.path + "-wal") }, url.map { URL(fileURLWithPath: $0.path + "-shm") }]
                .compactMap { $0 }.reduce(0) { sum, file in
                    sum + ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0)
                }
            return StorageInfo(bytes: bytes, imageBytes: images, dailyRows: row[0].int, checkpoints: count,
                               oldest: row[0].int > 0 ? Date(timeIntervalSinceReferenceDate: row[1].double) : nil,
                               newest: row[0].int > 0 ? Date(timeIntervalSinceReferenceDate: row[2].double) : nil)
        }
    }

    /// The retained cutoff also applies to newly discovered, moved, or rewritten logs.
    func cleanUsage(before cutoff: Date) throws {
        try lock.withLock {
            try transaction {
                let effective = max(try retentionCutoff ?? .distantPast, cutoff)
                try setData(Data(String(effective.timeIntervalSinceReferenceDate).utf8), namespace: "metadata", key: "retentionCutoff")
                try execute("DELETE FROM daily_usage WHERE day < ?", [.real(effective.timeIntervalSinceReferenceDate)])
                try execute("DELETE FROM hourly_usage WHERE hour < ?", [.real(effective.timeIntervalSinceReferenceDate)])
            }
            try execute("PRAGMA wal_checkpoint(TRUNCATE)")
            try execute("VACUUM")
            try execute("PRAGMA wal_checkpoint(TRUNCATE)")
        }
    }
}

struct StorageInfo: Sendable {
    let bytes: Int64
    let imageBytes: Int64
    let dailyRows: Int64
    let checkpoints: Int64
    let oldest: Date?
    let newest: Date?
}

/// UserDefaults remains an injectable legacy/test adapter. Production uses SQLite.
protocol PreferencesStore {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func string(forKey key: String) -> String?
    func integer(forKey key: String) -> Int
    func data(forKey key: String) -> Data?
    func stringArray(forKey key: String) -> [String]?
}
extension UserDefaults: PreferencesStore {}

final class SQLitePreferences: PreferencesStore {
    static let shared = SQLitePreferences(database: .shared, legacy:
        ProcessInfo.processInfo.environment["CODEX_METER_DATA_DIRECTORY"] == nil ? .standard : nil)
    let database: SQLiteStore
    static let legacyKeys = [
        "menuBarIconSize", "appAppearance", "appLanguage", "launchAtLogin",
        "showQuotaCard", "showTokenActivityCard", "showActivityOverviewCard", "showMonthlyUsageCard",
        "monthlyUsageMonthCount", "showUsageHeatmapCard", "showUsageSummaryCard", "showCreditsBalanceCard",
        "dashboardSectionOrder", "automaticRefreshIntervalOption", "automaticRefreshIntervalMinutes",
        "customRefreshIntervalMinutes", "codexExecutablePath", "quotaBackgroundsEnabled",
        "quotaBackgroundProfiles", "selectedQuotaBackgroundProfileID"
    ]

    init(database: SQLiteStore, legacy: UserDefaults? = nil) {
        self.database = database
        guard let legacy else { return }
        do {
            try database.transaction {
                guard try database.data(namespace: "metadata", key: "preferencesMigrated") == nil else { return }
                for key in Self.legacyKeys {
                    if try database.data(namespace: "preferences", key: key) == nil,
                       let value = legacy.object(forKey: key) {
                        try save(value, key: key)
                    }
                }
                try database.setData(Data([1]), namespace: "metadata", key: "preferencesMigrated")
            }
            for key in Self.legacyKeys { legacy.removeObject(forKey: key) }
        } catch { database.recordFailure(error) }
    }

    private func save(_ value: Any?, key: String) throws {
        let data = try value.map {
            try PropertyListSerialization.data(fromPropertyList: ["value": $0], format: .binary, options: 0)
        }
        try database.setData(data, namespace: "preferences", key: key)
    }

    func set(_ value: Any?, forKey key: String) {
        do { try save(value, key: key) } catch { database.recordFailure(error) }
    }
    func object(forKey key: String) -> Any? {
        do {
            guard let data = try database.data(namespace: "preferences", key: key) else { return nil }
            return (try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])?["value"]
        } catch { database.recordFailure(error); return nil }
    }
    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func integer(forKey key: String) -> Int { (object(forKey: key) as? NSNumber)?.intValue ?? 0 }
    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    func stringArray(forKey key: String) -> [String]? { object(forKey: key) as? [String] }
}
