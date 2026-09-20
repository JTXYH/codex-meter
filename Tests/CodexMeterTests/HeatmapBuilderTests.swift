import Foundation
import Testing
@testable import CodexMeter

struct HeatmapBuilderTests {
    @Test
    func separatesActiveDaysIntoQuartilesDespiteZerosAndAnOutlier() {
        let days = buildDays(tokens: [
            1_000_000, 2_000_000, 3_000_000, 4_000_000,
            5_000_000, 6_000_000, 7_000_000, Int64.max,
        ])

        #expect(days.count == 120)
        #expect(days.filter { $0.tokens == 0 }.allSatisfy { $0.level == .none })
        #expect(days.filter { $0.tokens > 0 }.map(\.level) == [
            .low, .low, .medium, .medium, .high, .high, .peak, .peak,
        ])
    }

    @Test
    func keepsTiedValuesTogetherAcrossQuartileBoundaries() {
        let days = buildDays(tokens: [10, 10, 10, 20, 30, 40, 40, 50])

        #expect(days.filter { $0.tokens > 0 }.map(\.level) == [
            .low, .low, .low, .medium, .high, .high, .high, .peak,
        ])
    }

    @Test(arguments: [
        [Int64](), [0, -10], [10], [10, 10, 10], [10, 20], [10, 20, 30],
    ])
    func handlesEmptyAndSmallSamples(tokens: [Int64]) {
        let days = buildDays(tokens: tokens)
        let activeDays = days.filter { $0.tokens > 0 }

        #expect(activeDays.count == tokens.filter { $0 > 0 }.count)
        #expect(days.filter { $0.tokens == 0 }.allSatisfy { $0.level == .none })
        #expect(activeDays.allSatisfy { $0.level != .none })
        #expect(activeDays.filter { $0.tokens == tokens.max() }.allSatisfy { $0.level == .peak })
        if Set(activeDays.map(\.tokens)).count > 1 {
            #expect(activeDays.first?.level == .low)
        }
    }

    private func buildDays(tokens: [Int64]) -> [HeatmapDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let end = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        let usage = tokens.enumerated().map { index, value in
            DailyTokenUsage(
                date: calendar.date(byAdding: .day, value: index - (tokens.count - 1), to: end)!,
                tokens: value
            )
        }
        return HeatmapBuilder.columns(from: usage, endingAt: end, dayCount: 120, calendar: calendar)
            .flatMap { $0 }.compactMap { $0 }
    }
}
