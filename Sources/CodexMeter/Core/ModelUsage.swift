import Foundation

struct DailyModelTokenUsage: Equatable, Sendable {
    let day: Date
    let model: String
    let usage: LocalTokenUsage
}

struct HourlyModelTokenUsage: Equatable, Sendable {
    let hour: Date
    let model: String
    let usage: LocalTokenUsage
}

struct ModelTokenUsage: Identifiable, Equatable, Sendable {
    var id: String { model }
    let model: String
    let usage: LocalTokenUsage
}

enum ModelUsageBuilder {
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

    static func models(
        from records: [HourlyModelTokenUsage],
        containing date: Date,
        calendar: Calendar = .current
    ) -> [ModelTokenUsage] {
        guard let interval = calendar.dateInterval(of: .hour, for: date) else { return [] }
        var byModel: [String: LocalTokenUsage] = [:]
        for record in records where record.hour >= interval.start && record.hour < interval.end {
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
