import Foundation

struct LocalQuotaReading: Codable, Equatable, Sendable {
    let date: Date
    let bucketID: String
    let windowDurationMinutes: Int
    let resetsAt: Date
    let usedPercent: Double
}

struct TodayQuotaUsage: Equatable, Sendable {
    let bucketID: String
    let windowDurationMinutes: Int
    let usedPercentagePoints: Double
}

enum QuotaUsageBuilder {
    static func percentagePoints(
        from readings: [LocalQuotaReading],
        bucketID: String,
        windowDurationMinutes: Int,
        in interval: DateInterval
    ) -> Double? {
        guard windowDurationMinutes > 0 else { return nil }
        let durationSeconds = Double(windowDurationMinutes) * 60
        // Logs can shift the same reset by several minutes. A rounded minute key
        // would count that window again, often against a much older baseline.
        let resetTimeTolerance = min(10 * 60, durationSeconds / 2)
        let validReadings = readings.filter { reading in
            reading.bucketID == bucketID
                && reading.windowDurationMinutes == windowDurationMinutes
                && reading.date < interval.end
                && reading.usedPercent.isFinite
                && (0...100).contains(reading.usedPercent)
                && reading.resetsAt > reading.date
                && reading.date >= reading.resetsAt.addingTimeInterval(-durationSeconds)
        }.sorted { $0.resetsAt < $1.resetsAt }
        var windows: [[LocalQuotaReading]] = []
        for reading in validReadings {
            // Keep a fixed earliest reset as the anchor so successive small
            // shifts cannot extend a group indefinitely into another window.
            if let anchor = windows.last?.first?.resetsAt,
               reading.resetsAt.timeIntervalSince(anchor) <= resetTimeTolerance {
                windows[windows.count - 1].append(reading)
            } else {
                windows.append([reading])
            }
        }

        var total = 0.0
        var hasReadingsInPeriod = false
        for window in windows {
            let sorted = window.sorted {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.usedPercent < $1.usedPercent
            }
            let current = sorted.filter { $0.date >= interval.start && $0.date < interval.end }
            guard let first = current.first else { continue }
            hasReadingsInPeriod = true
            let startsAt = window[0].resetsAt.addingTimeInterval(-durationSeconds)
            let baseline = startsAt >= interval.start
                ? 0
                : (sorted.last { $0.date < interval.start }?.usedPercent ?? first.usedPercent)
            total += max(0, (current.map(\.usedPercent).max() ?? first.usedPercent) - baseline)
        }
        return hasReadingsInPeriod ? total : nil
    }
}

enum TodayQuotaUsageBuilder {
    private struct QuotaKey: Hashable {
        let bucketID: String
        let duration: Int
    }

    static func totals(
        from readings: [LocalQuotaReading],
        at now: Date,
        calendar: Calendar = .current
    ) -> [TodayQuotaUsage] {
        guard let day = calendar.dateInterval(of: .day, for: now) else { return [] }
        let keys = Set(readings.filter { $0.date >= day.start && $0.date < day.end }.map {
            QuotaKey(bucketID: $0.bucketID, duration: $0.windowDurationMinutes)
        })
        return keys.compactMap { key in
            guard let amount = QuotaUsageBuilder.percentagePoints(
                from: readings,
                bucketID: key.bucketID,
                windowDurationMinutes: key.duration,
                in: day
            ) else { return nil }
            return TodayQuotaUsage(
                bucketID: key.bucketID,
                windowDurationMinutes: key.duration,
                usedPercentagePoints: amount
            )
        }
        .sorted {
            if $0.bucketID != $1.bucketID { return $0.bucketID < $1.bucketID }
            return $0.windowDurationMinutes < $1.windowDurationMinutes
        }
    }
}
