import Foundation
import Testing
@testable import CodexMeter

struct FormattersTests {
    @Test(arguments: [
        (Int64(53_000_000), "5千3百万"),
        (50_000_000, "5千万"),
        (890_000_000, "8亿9千万"),
        (2_100_000, "210万"),
        (5_400_000, "540万"),
        (1_000_000, "100万"),
        (386_000, "38.6万"),
        (17_000, "1.7万"),
        (1_900, "1.9千"),
        (99_500_000, "1亿"),
        (9_950_000, "1千万"),
        (999_950, "100万"),
        (9_950, "1万"),
        (53_500_000, "5千4百万"),
        (52_500_000, "5千2百万"),
        (999, "999"),
        (0, "0"),
        (-53_000_000, "-5千3百万"),
        (-2_100_000, "-210万"),
        (Int64.max, "92233720368亿5千万"),
        (Int64.min, "-92233720368亿5千万"),
    ])
    func formatsChineseTokenUnits(value: Int64, expected: String) {
        #expect(MeterFormatters.tokens(value) == expected)
        #expect(MeterFormatters.tokens(value, language: .traditionalChinese)
            == expected.replacingOccurrences(of: "万", with: "萬")
                .replacingOccurrences(of: "亿", with: "億"))
    }

    @Test(arguments: [-1, 0, 1, 2, 3])
    func formatsResetDatesAcrossYearBoundary(dayOffset: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Taipei"))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 12, day: 31, hour: 23, minute: 50
        )))
        let day = try #require(calendar.date(byAdding: .day, value: dayOffset, to: now))
        let reset = try #require(calendar.date(bySettingHour: 16, minute: 10, second: 0, of: day))
        let expected: String
        switch dayOffset {
        case 0: expected = "16:10"
        case 1: expected = "明天 16:10"
        case 2: expected = "后天 16:10"
        default:
            expected = reset.formatted(
                Date.FormatStyle(locale: AppLanguage.simplifiedChinese.locale,
                                 calendar: calendar, timeZone: calendar.timeZone)
                    .month().day().hour().minute()
            )
        }
        let weekly = RateLimitWindow(
            id: "weekly", bucketID: "codex", bucketName: "Codex", kind: .primary,
            usedPercent: 94, windowDurationMinutes: 10_080, resetsAt: reset
        )
        #expect(MeterFormatters.quotaResetDescription(for: weekly, now: now, calendar: calendar)
            == "\(expected) 重置")
    }

    @Test
    func usesCalendarDaysAcrossDaylightSaving() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 7, hour: 23, minute: 50
        )))
        let reset = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 9, hour: 0, minute: 10
        )))
        #expect(reset.timeIntervalSince(now) < 24 * 60 * 60)
        #expect(MeterFormatters.resetDate(reset, now: now, calendar: calendar) == "后天 00:10")
        #expect(MeterFormatters.resetDate(reset, now: now, language: .traditionalChinese,
                                        calendar: calendar).hasPrefix("後天 "))
    }
}
