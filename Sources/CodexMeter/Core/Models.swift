import Foundation

struct CodexAccount: Equatable, Sendable {
    let type: String
    let email: String?
    let planType: String?
    /// Selected ChatGPT workspace/account, when available from the current login.
    let accountID: String?

    init(type: String, email: String?, planType: String?, accountID: String? = nil) {
        self.type = type
        self.email = email
        self.planType = planType
        self.accountID = accountID
    }

    var usageIdentity: String {
        "\(type)\u{1F}\(accountID ?? "")\u{1F}\(email?.lowercased() ?? "")"
    }

    var displayPlan: String {
        guard let planType, !planType.isEmpty else { return "Codex" }
        return planType.prefix(1).uppercased() + planType.dropFirst()
    }
}

struct RateLimitWindow: Identifiable, Equatable, Sendable {
    let id: String
    let bucketID: String
    let bucketName: String
    let kind: Kind
    let usedPercent: Double
    let windowDurationMinutes: Int?
    let resetsAt: Date?

    enum Kind: String, Equatable, Sendable {
        case primary
        case secondary
    }

    var clampedUsedPercent: Double {
        min(max(usedPercent, 0), 100)
    }

    var remainingPercent: Double {
        max(0, 100 - clampedUsedPercent)
    }
}

struct RateLimitBucket: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let planType: String?
    let hasCredits: Bool?
    let unlimitedCredits: Bool?
    let creditBalance: String?
    let windows: [RateLimitWindow]
}

enum CreditBalance: Equatable, Sendable {
    case amount(Decimal)
    case unlimited
    case unavailable

    init(balance: String?, unlimited: Bool?) {
        if unlimited == true {
            self = .unlimited
            return
        }

        guard let balance = balance?.trimmingCharacters(in: .whitespacesAndNewlines),
              balance.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: balance, locale: Locale(identifier: "en_US_POSIX")),
              !amount.isNaN
        else {
            self = .unavailable
            return
        }
        self = .amount(amount)
    }
}

struct TokenUsageSummary: Equatable, Sendable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let longestRunningTurnSeconds: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
}

struct DailyTokenUsage: Identifiable, Equatable, Sendable {
    var id: Date { date }
    let date: Date
    let tokens: Int64
}

struct CodexUsageSnapshot: Equatable, Sendable {
    let fetchedAt: Date
    let account: CodexAccount?
    let rateLimitBuckets: [RateLimitBucket]
    let usageSummary: TokenUsageSummary?
    let dailyUsage: [DailyTokenUsage]
    let resetCredits: RateLimitResetCredits?

    init(fetchedAt: Date, account: CodexAccount?, rateLimitBuckets: [RateLimitBucket],
         usageSummary: TokenUsageSummary?, dailyUsage: [DailyTokenUsage],
         resetCredits: RateLimitResetCredits? = nil) {
        self.fetchedAt = fetchedAt
        self.account = account
        self.rateLimitBuckets = rateLimitBuckets
        self.usageSummary = usageSummary
        self.dailyUsage = dailyUsage
        self.resetCredits = resetCredits
    }

    // Select one bucket before choosing windows; different buckets have independent quotas.
    private var preferredRateLimitBucket: RateLimitBucket? {
        rateLimitBuckets.first(where: { $0.id == "codex" })
            ?? rateLimitBuckets.first
    }

    var creditsBalance: CreditBalance {
        let bucket = preferredRateLimitBucket
        return CreditBalance(balance: bucket?.creditBalance, unlimited: bucket?.unlimitedCredits)
    }

    var primaryWindow: RateLimitWindow? {
        let windows = preferredRateLimitBucket?.windows
        return windows?.first(where: { $0.kind == .primary })
            ?? windows?.first
    }

    var fiveHourWindow: RateLimitWindow? {
        preferredRateLimitBucket?.windows.first(where: { $0.windowDurationMinutes == 300 })
    }

    var weeklyWindow: RateLimitWindow? {
        preferredRateLimitBucket?.windows.first(where: { $0.windowDurationMinutes == 10_080 })
    }

    var quotaCardPrimaryWindow: RateLimitWindow? {
        fiveHourWindow ?? weeklyWindow ?? primaryWindow
    }

    var quotaCardSecondaryWindow: RateLimitWindow? {
        guard let fiveHourWindow,
              let weeklyWindow,
              fiveHourWindow.id != weeklyWindow.id
        else { return nil }
        return weeklyWindow
    }

    func tokenUsage(on date: Date, calendar: Calendar = UsageCalendar.calendar) -> DailyTokenUsage? {
        dailyUsage.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
    }

    func tokens(on date: Date, calendar: Calendar = UsageCalendar.calendar) -> Int64 {
        tokenUsage(on: date, calendar: calendar)?.tokens ?? 0
    }

    func tokensInLastDays(_ count: Int, endingAt endDate: Date = Date(), calendar: Calendar = UsageCalendar.calendar) -> Int64 {
        guard count > 0,
              let startDate = calendar.date(byAdding: .day, value: -(count - 1), to: calendar.startOfDay(for: endDate)),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))
        else { return 0 }

        return dailyUsage
            .filter { $0.date >= startDate && $0.date < endExclusive }
            .reduce(0) { total, usage in
                let (sum, overflow) = total.addingReportingOverflow(max(0, usage.tokens))
                return overflow ? .max : sum
            }
    }
}

enum HeatmapLevel {
    case none, low, medium, high, peak

    static let activeLevels: [HeatmapLevel] = [.low, .medium, .high, .peak]
}

struct HeatmapDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let tokens: Int64
    let level: HeatmapLevel
}

enum HeatmapBuilder {
    static func columns(
        from usage: [DailyTokenUsage],
        endingAt endDate: Date = Date(),
        dayCount: Int = 90,
        calendar inputCalendar: Calendar = UsageCalendar.calendar
    ) -> [[HeatmapDay?]] {
        guard dayCount > 0 else { return [] }

        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "zh_CN")
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: end),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: end) else { return [] }

        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        guard let alignedStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) else { return [] }

        let endWeekday = calendar.component(.weekday, from: end)
        let daysUntilSunday = (8 - endWeekday) % 7
        guard let alignedEnd = calendar.date(byAdding: .day, value: daysUntilSunday, to: end) else { return [] }

        var tokenByDay: [Date: Int64] = [:]
        for item in usage where item.date >= start && item.date < endExclusive {
            let date = calendar.startOfDay(for: item.date)
            let tokens = max(0, item.tokens)
            let (sum, overflow) = tokenByDay[date, default: 0].addingReportingOverflow(tokens)
            tokenByDay[date] = overflow ? .max : sum
        }
        // Use nearest-rank quartiles of active days so zeros and outliers do not
        // compress ordinary usage into a single shade. Ties keep the same level.
        let activeTokens = tokenByDay.values.filter { $0 > 0 }.sorted()
        let thresholds: [Int64] = activeTokens.isEmpty ? [] : (1...3).map {
            activeTokens[(activeTokens.count * $0 - 1) / 4]
        }

        var columns: [[HeatmapDay?]] = []
        var cursor = alignedStart
        while cursor <= alignedEnd {
            var column: [HeatmapDay?] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: cursor) else {
                    column.append(nil)
                    continue
                }

                guard date >= start, date <= end else {
                    column.append(nil)
                    continue
                }

                let tokens = tokenByDay[date] ?? 0
                let level: HeatmapLevel
                if tokens == 0 {
                    level = .none
                } else if tokens == activeTokens.last {
                    // Also covers a single active day or identical daily totals.
                    level = .peak
                } else {
                    let quartile = thresholds.firstIndex(where: { tokens <= $0 }) ?? 3
                    level = HeatmapLevel.activeLevels[quartile]
                }
                column.append(HeatmapDay(date: date, tokens: tokens, level: level))
            }
            columns.append(column)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return columns
    }
}
