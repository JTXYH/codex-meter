import Foundation
import Testing
@testable import CodexMeter

struct QuotaUsageTests {
    @Test(arguments: [58.0, 84.0, 378.0, 531.0])
    func resetTimeDriftDoesNotDuplicateYesterdayUsage(drift: TimeInterval) {
        // The 9/30 logs reported 61 -> 71%, with a second reset timestamp
        // whose older reading was 29%. Minute grouping incorrectly gave 52%.
        let reset = date("2026-10-03T16:58:12Z")
        let readings = [
            reading("2026-09-28T04:00:00Z", used: 29, reset: reset.addingTimeInterval(drift)),
            reading("2026-09-29T10:47:42Z", used: 61, reset: reset),
            reading("2026-09-29T17:00:36Z", used: 61, reset: reset),
            reading("2026-09-30T15:51:00Z", used: 71, reset: reset.addingTimeInterval(4)),
            reading("2026-09-30T15:53:17Z", used: 71, reset: reset.addingTimeInterval(drift)),
            reading("2026-09-30T16:01:31Z", used: 80, reset: reset),
        ]
        let yesterday = DateInterval(start: date("2026-09-29T16:00:00Z"),
                                     end: date("2026-09-30T16:00:00Z"))
        #expect(amount(readings, in: yesterday) == 10)
        #expect(amount(Array(readings.reversed()) + readings, in: yesterday) == 10)
    }

    @Test
    func minuteBoundaryDriftKeepsRealFiveHourResetsSeparate() {
        let reset = date("2026-09-30T15:00:29Z")
        let readings = [
            reading("2026-09-30T14:00:00Z", used: 20, reset: reset, duration: 300),
            reading("2026-09-30T14:01:00Z", used: 25, reset: reset.addingTimeInterval(1), duration: 300),
            reading("2026-09-30T17:00:00Z", used: 3,
                    reset: reset.addingTimeInterval(5 * 3_600), duration: 300),
        ]
        let day = DateInterval(start: date("2026-09-30T00:00:00Z"),
                               end: date("2026-10-01T00:00:00Z"))
        #expect(amount(readings, duration: 300, in: day) == 28)
    }

    @Test
    func realWeeklyResetPreservesTheBaselineAndBucketIsolation() {
        let firstReset = date("2026-09-30T00:00:00Z")
        let nextReset = firstReset.addingTimeInterval(7 * 86_400)
        let readings = [
            reading("2026-09-28T23:00:00Z", used: 61, reset: firstReset),
            reading("2026-09-29T23:00:00Z", used: 71, reset: firstReset),
            reading("2026-09-30T01:00:00Z", used: 3, reset: nextReset),
            reading("2026-10-01T01:00:00Z", used: 7, reset: nextReset.addingTimeInterval(58)),
            reading("2026-09-30T01:00:00Z", used: 100, reset: nextReset, bucket: "other"),
            reading("2026-09-30T01:00:00Z", used: 100,
                    reset: date("2026-09-30T05:00:00Z"), duration: 300),
        ]
        let interval = DateInterval(start: date("2026-09-29T00:00:00Z"),
                                    end: date("2026-10-02T00:00:00Z"))
        #expect(amount(readings, in: interval) == 17)
    }

    private func amount(_ readings: [LocalQuotaReading], duration: Int = 10_080,
                        in interval: DateInterval) -> Double? {
        QuotaUsageBuilder.percentagePoints(from: readings, bucketID: "codex",
                                          windowDurationMinutes: duration, in: interval)
    }

    private func reading(_ time: String, used: Double, reset: Date,
                         duration: Int = 10_080, bucket: String = "codex") -> LocalQuotaReading {
        LocalQuotaReading(date: date(time), bucketID: bucket,
                          windowDurationMinutes: duration, resetsAt: reset, usedPercent: used)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
