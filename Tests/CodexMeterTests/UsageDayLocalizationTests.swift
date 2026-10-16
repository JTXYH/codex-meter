import Foundation
import Testing
@testable import CodexMeter

struct UsageDayLocalizationTests {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test
    func localTooltipExplainsTaipeiDayBoundaryWithoutChangingBucketDate() {
        let bucket = date("2026-10-15T00:00:00Z")
        #expect(UsageDayL10n.date(bucket, template: "Md", language: .simplifiedChinese) == "10/15")
        let help = UsageDayL10n.help(containing: bucket, language: .simplifiedChinese,
                                    localTimeZone: TimeZone(identifier: "Asia/Taipei")!)
        #expect(help.contains("Asia/Taipei"))
        #expect(help.contains("10月15日"))
        #expect(help.contains("10月16日"))
        #expect(help.contains("08:00"))
        #expect(help.components(separatedBy: "UTC+08:00").count == 3)
    }

    @Test
    func localTooltipTracksBothOffsetsAcrossDaylightSavingChange() {
        let bucket = date("2026-11-01T00:00:00Z")
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let help = UsageDayL10n.help(containing: bucket, language: .english, localTimeZone: zone)
        #expect(help.contains("Oct 31"))
        #expect(help.contains("Nov 1"))
        #expect(help.contains("17:00 (UTC-07:00)"))
        #expect(help.contains("16:00 (UTC-08:00)"))
        #expect(UsageDayL10n.date(bucket, template: "MMM", language: .english) == "Nov")
        #expect(UsageDayL10n.date(bucket, template: "Md", language: .english) == "11/1")
    }

    @Test
    func weekTooltipUsesTheSelectedUtcMondayToMondayRangeInEveryLanguage() {
        let sunday = date("2026-10-18T12:00:00Z")
        for language in AppLanguage.allCases {
            let help = UsageDayL10n.help(containing: sunday, period: .week, language: language,
                                        localTimeZone: TimeZone(secondsFromGMT: 0)!)
            #expect(help.components(separatedBy: "UTC+00:00").count == 3)
            #expect(help.contains("12"))
            #expect(help.contains("19"))
            #expect(help.contains("00:00"))
            #expect(UsageDayL10n.title(language: language).contains("UTC"))
        }
    }
}
