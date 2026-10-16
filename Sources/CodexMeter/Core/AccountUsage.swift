import Foundation

/// Token summary buckets contain totals only; model usage comes from a separate endpoint.
struct AccountPeriodUsage: Identifiable, Equatable, Sendable {
    var id: Date { start }
    let start: Date
    let tokens: Int64?
    let recordedDays: Int
    let expectedDays: Int

    var isPartial: Bool { recordedDays > 0 && recordedDays < expectedDays }
}

enum AccountUsageBuilder {
    static func periods(
        from records: [DailyTokenUsage], period: UsagePeriod, count: Int,
        endingAt date: Date = Date(), calendar: Calendar = UsageCalendar.calendar
    ) -> [AccountPeriodUsage] {
        // Daily API buckets cannot be reconstructed into hourly measurements.
        guard period != .hour,
              count > 0 || (period == .year && count == 0),
              let current = period.interval(containing: date, calendar: calendar)?.start,
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        else { return [] }

        // Bound the window before doing calendar work for every source row.
        // The all-years option intentionally retains the entire history.
        let firstPeriod = count > 0
            ? calendar.date(byAdding: period.component, value: 1 - count, to: current)
            : nil
        var days: [Date: Int64] = [:]
        for record in records where record.date < tomorrow && firstPeriod.map({ record.date >= $0 }) != false {
            let day = calendar.startOfDay(for: record.date)
            days[day] = adding(days[day, default: 0], max(0, record.tokens))
        }
        var totals: [Date: Int64] = [:]
        var counts: [Date: Int] = [:]
        for (day, tokens) in days {
            guard let start = period == .day ? day : period.interval(containing: day, calendar: calendar)?.start else { continue }
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
