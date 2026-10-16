import Foundation
import Testing
@testable import CodexMeter

/// Explicit release-only benchmark. Baseline builders below are frozen copies
/// from before the compact-panel aggregation changes; do not update them with production code.
struct AccountUsagePerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CODEX_METER_PERF"] == "1"))
    func repeatedLargeHistoryAndModelAggregation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15)))
        let days: [Date] = (0..<3_650).map { calendar.date(byAdding: .day, value: -$0, to: now)! }
        var records: [DailyTokenUsage] = []
        records.reserveCapacity(100_000)
        for index in 0..<100_000 {
            let day: Date = days[index % days.count]
            let offset: TimeInterval = Double(index % 5) * 30.0
            let tokens: Int64 = Int64(index % 1_000 + 1)
            records.append(DailyTokenUsage(date: day.addingTimeInterval(offset), tokens: tokens))
        }
        let expectedPeriods = BeforeAccountUsageBuilder.periods(from: records, period: .day, count: 30,
                                                                 endingAt: now, calendar: calendar)
        #expect(expectedPeriods.count == 30)
        let lower = try #require(calendar.date(byAdding: .day, value: -29, to: now))
        let periodTokens: [Int64] = expectedPeriods.compactMap(\.tokens)
        let periodTotal: Int64 = periodTokens.reduce(Int64(0), +)
        let recentRecords: [DailyTokenUsage] = records.filter { $0.date >= lower }
        let expectedPeriodTotal: Int64 = recentRecords.reduce(Int64(0)) { $0 + $1.tokens }
        #expect(periodTotal == expectedPeriodTotal)
        try measure("history_before", iterations: 100, expected: expectedPeriods) {
            BeforeAccountUsageBuilder.periods(from: records, period: .day, count: 30, endingAt: now, calendar: calendar)
        }
        try measure("history_after", iterations: 100, expected: expectedPeriods) {
            AccountUsageBuilder.periods(from: records, period: .day, count: 30, endingAt: now, calendar: calendar)
        }

        let expectedHeatmap = BeforeHeatmapBuilder.columns(from: records, endingAt: now, dayCount: 120, calendar: calendar)
        let cells: [HeatmapDay?] = expectedHeatmap.flatMap { $0 }
        let heatDays: [HeatmapDay] = cells.compactMap { $0 }
        #expect(heatDays.count == 120)
        let heatLower = try #require(calendar.date(byAdding: .day, value: -119, to: now))
        let heatTotal: Int64 = heatDays.reduce(Int64(0)) { $0 + $1.tokens }
        let heatRecords: [DailyTokenUsage] = records.filter { $0.date >= heatLower }
        let expectedHeatTotal: Int64 = heatRecords.reduce(Int64(0)) { $0 + $1.tokens }
        #expect(heatTotal == expectedHeatTotal)
        try measure("heatmap_before", iterations: 100, expected: expectedHeatmap) {
            BeforeHeatmapBuilder.columns(from: records, endingAt: now, dayCount: 120, calendar: calendar)
        }
        try measure("heatmap_after", iterations: 100, expected: expectedHeatmap) {
            HeatmapBuilder.columns(from: records, endingAt: now, dayCount: 120, calendar: calendar)
        }

        let usage = LocalTokenUsage(totalTokens: 110, inputTokens: 100, cachedInputTokens: 0,
                                   cacheWriteInputTokens: 0, outputTokens: 10, reasoningOutputTokens: 0)
        let models: [DailyModelTokenUsage] = (0..<10_000).map { DailyModelTokenUsage(day: now, model: "model-\($0)", usage: usage) }
        let expectedModels = BeforeModelUsageBuilder.models(from: models, period: .day, containing: now, calendar: calendar)
        #expect(expectedModels.count == 10_000)
        let modelTotal: Int64 = expectedModels.reduce(Int64(0)) { $0 + $1.usage.totalTokens }
        #expect(modelTotal == 1_100_000)
        try measure("models_before", iterations: 100, expected: expectedModels) {
            BeforeModelUsageBuilder.models(from: models, period: .day, containing: now, calendar: calendar)
        }
        try measure("models_after", iterations: 100, expected: expectedModels) {
            ModelUsageBuilder.models(from: models, period: .day, containing: now, calendar: calendar)
        }
        print("ACCOUNT_PERF_DATASET historical_records=100000 days=3650 unique_models=10000 iterations=100")
    }

    private func measure<T: Equatable>(_ phase: String, iterations: Int, expected: T, operation: () -> T) throws {
        let start = ContinuousClock.now
        for _ in 0..<iterations { #expect(operation() == expected) }
        let elapsed = start.duration(to: .now).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        let result = AggregatePerformanceRecord(phase: phase, iterations: iterations, seconds: seconds,
                                                meanMilliseconds: seconds * 1_000 / Double(iterations))
        print("ACCOUNT_PERF " + String(decoding: try JSONEncoder().encode(result), as: UTF8.self))
    }
}

private struct AggregatePerformanceRecord: Encodable {
    let phase: String
    let iterations: Int
    let seconds: Double
    let meanMilliseconds: Double
}

// Frozen pre-change implementations for a reproducible same-process comparison.
private enum BeforeAccountUsageBuilder {
    static func periods(
        from records: [DailyTokenUsage], period: UsagePeriod, count: Int,
        endingAt date: Date = Date(), calendar: Calendar = .current
    ) -> [AccountPeriodUsage] {
        // Daily API buckets cannot be reconstructed into hourly measurements.
        guard period != .hour,
              count > 0 || (period == .year && count == 0),
              let current = period.interval(containing: date, calendar: calendar)?.start,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        else { return [] }

        var days: [Date: Int64] = [:]
        for record in records {
            let day = calendar.startOfDay(for: record.date)
            guard day < tomorrow else { continue }
            days[day] = adding(days[day, default: 0], max(0, record.tokens))
        }
        var totals: [Date: Int64] = [:]
        var counts: [Date: Int] = [:]
        for (day, tokens) in days {
            guard let start = period.interval(containing: day, calendar: calendar)?.start else { continue }
            totals[start] = adding(totals[start, default: 0], tokens)
            counts[start, default: 0] += 1
        }
        let resolvedCount: Int
        if count == 0 {
            let oldest = totals.keys.min() ?? current
            resolvedCount = (calendar.dateComponents([.year], from: oldest, to: current).year ?? 0) + 1
        } else {
            resolvedCount = count
        }
        return (0..<resolvedCount).compactMap { offset in
            guard let start = calendar.date(byAdding: period.component, value: -offset, to: current),
                  let interval = period.interval(containing: start, calendar: calendar)
            else { return nil }
            let end = min(interval.end, tomorrow)
            let expectedDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return AccountPeriodUsage(
                start: start, tokens: totals[start], recordedDays: counts[start, default: 0],
                expectedDays: expectedDays
            )
        }
    }

    private static func adding(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }
}

private enum BeforeHeatmapBuilder {
    static func columns(
        from usage: [DailyTokenUsage],
        endingAt endDate: Date = Date(),
        dayCount: Int = 90,
        calendar inputCalendar: Calendar = .current
    ) -> [[HeatmapDay?]] {
        guard dayCount > 0 else { return [] }

        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "zh_CN")
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: end) else { return [] }

        let weekday = calendar.component(.weekday, from: start)
        let daysSinceMonday = (weekday + 5) % 7
        guard let alignedStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: start) else { return [] }

        let endWeekday = calendar.component(.weekday, from: end)
        let daysUntilSunday = (8 - endWeekday) % 7
        guard let alignedEnd = calendar.date(byAdding: .day, value: daysUntilSunday, to: end) else { return [] }

        var tokenByDay: [Date: Int64] = [:]
        for item in usage {
            let date = calendar.startOfDay(for: item.date)
            guard date >= start, date <= end else { continue }
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

private enum BeforeModelUsageBuilder {
    static func models(
        from records: [DailyModelTokenUsage],
        period: UsagePeriod,
        containing date: Date,
        calendar: Calendar = .current
    ) -> [ModelTokenUsage] {
        guard period != .hour else { return [] }
        guard let interval = period.interval(containing: date, calendar: calendar) else { return [] }
        var byModel: [String: LocalTokenUsage] = [:]
        for record in records where record.day >= interval.start && record.day < interval.end {
            byModel[record.model] = (byModel[record.model] ?? .zero).adding(record.usage)
        }
        return byModel.map { ModelTokenUsage(model: $0.key, usage: $0.value) }
            .sorted {
                if $0.usage.totalTokens != $1.usage.totalTokens {
                    return $0.usage.totalTokens > $1.usage.totalTokens
                }
                return $0.model < $1.model
            }
    }

}
