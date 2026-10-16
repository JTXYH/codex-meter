import Foundation
import Testing
@testable import CodexMeter

struct QuotaResetReadoutTests {
    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    private func calendar(_ zone: String) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: zone)!
        return result
    }

    @Test
    func todayUsesLargeTimeAndOtherDaysUseLargeLocalizedDate() {
        let now = date("2026-10-15T12:00:00Z")
        let taipei = calendar("Asia/Taipei")
        let today = QuotaResetReadout(date: date("2026-10-15T13:06:00Z"), language: .simplifiedChinese, now: now, calendar: taipei)
        #expect(today.primary == "21:06")
        #expect(today.secondary == "今天")
        let tomorrow = QuotaResetReadout(date: date("2026-10-16T01:05:00Z"), language: .simplifiedChinese, now: now, calendar: taipei)
        #expect(tomorrow.primary == "10月16日")
        #expect(tomorrow.secondary == "09:05")
        let english = QuotaResetReadout(date: date("2026-10-16T01:05:00Z"), language: .english, now: now, calendar: taipei)
        #expect(english.primary.contains("Oct"))
        #expect(english.primary.contains("16"))
        #expect(english.secondary == "09:05")
    }

    @Test
    func localMidnightAndYearBoundaryDetermineTheHierarchy() {
        let now = date("2026-12-31T15:55:00Z")
        let reset = date("2026-12-31T16:05:00Z")
        let taipei = QuotaResetReadout(date: reset, language: .simplifiedChinese, now: now, calendar: calendar("Asia/Taipei"))
        #expect(taipei.primary == "2027年1月1日")
        #expect(taipei.secondary == "00:05")
        let utc = QuotaResetReadout(date: reset, language: .english, now: now, calendar: calendar("UTC"))
        #expect(utc.primary == "16:05")
        #expect(utc.secondary == "Today")
    }

    @Test
    func absentResetKeepsThePlaceholderForEveryLanguage() {
        for language in AppLanguage.allCases {
            let result = QuotaResetReadout(date: nil, language: language)
            #expect(result.primary == "—")
            #expect(result.secondary.isEmpty)
        }
    }
}
