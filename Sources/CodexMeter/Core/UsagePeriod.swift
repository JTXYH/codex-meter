import Foundation

enum UsagePeriod: String, CaseIterable, Identifiable, Sendable {
    case hour, day, month, year

    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .hour: .hour
        case .day: .day
        case .month: .month
        case .year: .year
        }
    }

    /// Zero represents all recorded years, including gaps up to the current year.
    var ranges: [Int] {
        switch self {
        case .hour: [6, 12, 24]
        case .day: [7, 14, 30]
        case .month: [3, 6, 12]
        case .year: [3, 5, 0]
        }
    }

    var defaultRange: Int {
        switch self {
        case .hour: 24
        case .day: 7
        case .month: 6
        case .year: 3
        }
    }

    func sanitizedRange(_ count: Int) -> Int {
        ranges.contains(count) ? count : defaultRange
    }
}

struct PeriodTokenUsage: Identifiable, Equatable, Sendable {
    var id: Date { start }
    let start: Date
    let usage: LocalTokenUsage?
}

enum PeriodUsageBuilder {
    static func periods(
        from records: [PeriodTokenUsage], period: UsagePeriod, count: Int,
        endingAt date: Date = Date(), calendar: Calendar = .current
    ) -> [PeriodTokenUsage] {
        guard count > 0 || (period == .year && count == 0),
              let current = calendar.dateInterval(of: period.component, for: date)?.start
        else { return [] }
        var values: [Date: LocalTokenUsage] = [:]
        // Stable ordering preserves the scanner's cost summation across refreshes.
        for record in records.sorted(by: { $0.start < $1.start }) {
            guard record.start <= date, let usage = record.usage,
                  let start = calendar.dateInterval(of: period.component, for: record.start)?.start
            else { continue }
            values[start] = (values[start] ?? .zero).adding(usage)
        }
        let resolvedCount: Int
        if count == 0 {
            let oldest = values.keys.min() ?? current
            resolvedCount = (calendar.dateComponents([.year], from: oldest, to: current).year ?? 0) + 1
        } else {
            resolvedCount = count
        }
        return (0..<resolvedCount).compactMap { offset in
            guard let start = calendar.date(byAdding: period.component, value: -offset, to: current) else { return nil }
            return PeriodTokenUsage(start: start, usage: values[start])
        }
    }
}
