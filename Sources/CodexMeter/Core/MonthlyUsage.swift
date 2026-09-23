import Foundation

struct MonthlyTokenUsage: Identifiable, Equatable, Sendable {
    var id: Date { month }
    let month: Date
    let usage: LocalTokenUsage?
}

enum MonthlyUsageBuilder {
    static func months(
        from usage: [MonthlyTokenUsage],
        count: Int,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> [MonthlyTokenUsage] {
        guard count > 0,
              let currentMonth = calendar.dateInterval(of: .month, for: date)?.start
        else { return [] }
        var byMonth: [Date: LocalTokenUsage] = [:]
        for item in usage {
            guard let month = calendar.dateInterval(of: .month, for: item.month)?.start,
                  let value = item.usage else { continue }
            byMonth[month] = (byMonth[month] ?? .zero).adding(value)
        }
        return (0..<count).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth) else { return nil }
            return MonthlyTokenUsage(month: month, usage: byMonth[month])
        }
    }
}
