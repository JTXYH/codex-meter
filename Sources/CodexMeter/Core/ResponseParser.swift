import Foundation

enum CodexResponseParser {
    static func parse(
        accountData: Data,
        rateLimitsData: Data,
        usageData: Data,
        fetchedAt: Date = Date()
    ) throws -> CodexUsageSnapshot {
        let decoder = JSONDecoder()
        let accountResult: AccountResult = try decodeResult(accountData, decoder: decoder)
        let rateLimitsResult: RateLimitsResult = try decodeResult(rateLimitsData, decoder: decoder)
        let usageResult: UsageResult = try decodeResult(usageData, decoder: decoder)

        let account = accountResult.account.map {
            CodexAccount(type: $0.type, email: $0.email, planType: $0.planType)
        }

        let wireBuckets: [(String, WireRateLimitBucket)]
        if let byID = rateLimitsResult.rateLimitsByLimitId, !byID.isEmpty {
            wireBuckets = byID.sorted { lhs, rhs in
                if lhs.key == "codex" { return rhs.key != "codex" }
                if rhs.key == "codex" { return false }
                return lhs.key < rhs.key
            }
        } else if let fallback = rateLimitsResult.rateLimits {
            wireBuckets = [(fallback.limitId.nonEmpty ?? "codex", fallback)]
        } else {
            wireBuckets = []
        }

        let buckets = wireBuckets.map { fallbackID, bucket -> RateLimitBucket in
            let bucketID = bucket.limitId.nonEmpty ?? (fallbackID.isEmpty ? "codex" : fallbackID)
            let bucketName = bucket.limitName.nonEmpty ?? (bucketID == "codex" ? "Codex" : bucketID)
            var windows: [RateLimitWindow] = []
            if let primary = bucket.primary {
                windows.append(makeWindow(primary, kind: .primary, bucketID: bucketID, bucketName: bucketName))
            }
            if let secondary = bucket.secondary {
                windows.append(makeWindow(secondary, kind: .secondary, bucketID: bucketID, bucketName: bucketName))
            }
            return RateLimitBucket(
                id: bucketID,
                name: bucketName,
                planType: bucket.planType,
                hasCredits: bucket.credits?.hasCredits,
                unlimitedCredits: bucket.credits?.unlimited,
                creditBalance: bucket.credits?.balance,
                windows: windows
            )
        }

        let summary = usageResult.summary.map {
            TokenUsageSummary(
                lifetimeTokens: $0.lifetimeTokens,
                peakDailyTokens: $0.peakDailyTokens,
                longestRunningTurnSeconds: $0.longestRunningTurnSec,
                currentStreakDays: $0.currentStreakDays,
                longestStreakDays: $0.longestStreakDays
            )
        }

        var tokensByDate: [Date: Int64] = [:]
        for bucket in usageResult.dailyUsageBuckets ?? [] {
            guard let date = DateOnlyParser.date(from: bucket.startDate) else { continue }
            let tokens = max(0, bucket.tokens)
            let current = tokensByDate[date, default: 0]
            let (sum, overflow) = current.addingReportingOverflow(tokens)
            tokensByDate[date] = overflow ? .max : sum
        }
        let dailyUsage = tokensByDate
            .map { DailyTokenUsage(date: $0.key, tokens: $0.value) }
            .sorted { $0.date < $1.date }

        return CodexUsageSnapshot(
            fetchedAt: fetchedAt,
            account: account,
            rateLimitBuckets: buckets,
            usageSummary: summary,
            dailyUsage: dailyUsage
        )
    }

    private static func makeWindow(
        _ wire: WireRateLimitWindow,
        kind: RateLimitWindow.Kind,
        bucketID: String,
        bucketName: String
    ) -> RateLimitWindow {
        RateLimitWindow(
            id: "\(bucketID)-\(kind.rawValue)",
            bucketID: bucketID,
            bucketName: bucketName,
            kind: kind,
            usedPercent: wire.usedPercent,
            windowDurationMinutes: wire.windowDurationMins,
            resetsAt: wire.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    private static func decodeResult<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        let envelope = try decoder.decode(RPCEnvelope<T>.self, from: data)
        if let error = envelope.error {
            throw CodexMeterError.server(sanitizedErrorMessage(error.message))
        }
        guard let result = envelope.result else {
            throw CodexMeterError.invalidResponse("Codex App Server 返回了空结果")
        }
        return result
    }

    private static func sanitizedErrorMessage(_ value: String) -> String {
        let sanitized = value
            .components(separatedBy: .controlCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(sanitized.prefix(1_024))
    }
}

private struct RPCEnvelope<Result: Decodable>: Decodable {
    let result: Result?
    let error: RPCErrorPayload?
}

private struct RPCErrorPayload: Decodable {
    let code: Int?
    let message: String
}

private struct AccountResult: Decodable {
    let account: WireAccount?
}

private struct WireAccount: Decodable {
    let type: String
    let email: String?
    let planType: String?
}

private struct RateLimitsResult: Decodable {
    let rateLimits: WireRateLimitBucket?
    let rateLimitsByLimitId: [String: WireRateLimitBucket]?
}

private struct WireRateLimitBucket: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: WireRateLimitWindow?
    let secondary: WireRateLimitWindow?
    let credits: WireCredits?
    let planType: String?
}

private struct WireRateLimitWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int64?
}

private struct WireCredits: Decodable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?
}

private struct UsageResult: Decodable {
    let summary: WireUsageSummary?
    let dailyUsageBuckets: [WireDailyUsage]?
}

private struct WireUsageSummary: Decodable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let longestRunningTurnSec: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
}

private struct WireDailyUsage: Decodable {
    let startDate: String
    let tokens: Int64
}

enum DateOnlyParser {
    static func date(from value: String, timeZone: TimeZone = .current) -> Date? {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: 12
        )
        guard let date = calendar.date(from: components) else { return nil }
        let verified = calendar.dateComponents([.year, .month, .day], from: date)
        guard verified.year == year, verified.month == month, verified.day == day else {
            return nil
        }
        return date
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
