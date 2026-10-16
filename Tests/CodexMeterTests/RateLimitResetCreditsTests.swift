import Foundation
import Testing
@testable import CodexMeter

struct RateLimitResetCreditsTests {
    @Test
    func parsesOfficialResetCreditShapeAndPreservesDates() throws {
        let snapshot = try parse(#"""
        {"availableCount":2,"credits":[
            {"id":"first","resetType":"codexRateLimits","status":"available","grantedAt":1790707824,"expiresAt":1793299824,"title":"Full reset","description":"5-hour and weekly limits"},
            {"id":"second","resetType":"codexRateLimits","status":"available","grantedAt":1791415344,"expiresAt":1794007344,"title":null,"description":null}
        ]}
        """#)
        let credits = try #require(snapshot.resetCredits)
        #expect(credits.availableCount == 2)
        #expect(credits.credits?.count == 2)
        #expect(credits.availableCards.map(\.id) == ["first", "second"])
        #expect(credits.availableCards.first?.grantedAt == Date(timeIntervalSince1970: 1790707824))
        #expect(credits.availableCards.first?.expiresAt == Date(timeIntervalSince1970: 1793299824))
        #expect(credits.availableCards.first?.title == "Full reset")
        #expect(credits.availableCards.first?.description == "5-hour and weekly limits")
        #expect(credits.availableCards.last?.title == nil)
        #expect(snapshot.primaryWindow?.remainingPercent == 75)
        #expect(snapshot.creditsBalance == .amount(42))
    }

    @Test(arguments: [nil, "null", "false", "[]", "{}", #"{"availableCount":-1,"credits":[]}"#,
                     #"{"availableCount":"2","credits":[]}"#] as [String?])
    func absentOrMalformedOptionalExtensionDoesNotBreakQuota(_ value: String?) throws {
        let snapshot = try parse(value)
        #expect(snapshot.resetCredits == nil)
        #expect(snapshot.primaryWindow?.remainingPercent == 75)
    }

    @Test(arguments: [#"{"availableCount":5,"credits":null}"#,
                     #"{"availableCount":5}"#,
                     #"{"availableCount":5,"credits":"invalid"}"#])
    func absentOrMalformedDetailListKeepsOfficialCount(_ value: String) throws {
        let credits = try #require(try parse(value).resetCredits)
        #expect(credits.availableCount == 5)
        #expect(credits.credits == nil)
        #expect(credits.availableCards.isEmpty)
    }

    @Test
    func emptyDetailsRemainDistinctFromCountOnly() throws {
        let credits = try #require(try parse(#"{"availableCount":0,"credits":[]}"#).resetCredits)
        #expect(credits.availableCount == 0)
        #expect(credits.credits == [])
    }

    @Test
    func cappedDetailsKeepCountAndOnlyAvailableCardsAreSorted() throws {
        let credits = try #require(try parse(#"""
        {"availableCount":9,"credits":[
            {"id":"never","resetType":"unknown","status":"available","grantedAt":100,"expiresAt":null},
            {"id":"later","resetType":"codexRateLimits","status":"available","grantedAt":100,"expiresAt":600},
            {"id":"redeemed","resetType":"codexRateLimits","status":"redeemed","grantedAt":100,"expiresAt":150},
            {"id":"redeeming","resetType":"codexRateLimits","status":"redeeming","grantedAt":100,"expiresAt":150},
            {"id":"unknown","resetType":"futureReset","status":"unknown","grantedAt":100,"expiresAt":150},
            {"id":"earlier","resetType":"codexRateLimits","status":"available","grantedAt":100,"expiresAt":300}
        ]}
        """#).resetCredits)
        #expect(credits.availableCount == 9)
        #expect(credits.credits?.count == 6)
        #expect(credits.availableCards.map(\.id) == ["earlier", "later", "never"])
        #expect(credits.availableCards.last?.expiresAt == nil)
        #expect(credits.credits?.first(where: { $0.id == "unknown" })?.resetType == "futureReset")
    }

    @Test
    func corruptDetailRowsDoNotEraseCountOrInventPermanentCards() throws {
        let credits = try #require(try parse(#"""
        {"availableCount":6,"credits":[
            false,
            {"id":"missing-expiry","resetType":"codexRateLimits","status":"available","grantedAt":100},
            {"id":"invalid-expiry","resetType":"codexRateLimits","status":"available","grantedAt":100,"expiresAt":"soon"},
            {"id":"","resetType":"codexRateLimits","status":"available","grantedAt":100,"expiresAt":300},
            {"id":"valid","resetType":"codexRateLimits","status":"available","grantedAt":100,"expiresAt":300,"title":false,"description":17},
            null
        ]}
        """#).resetCredits)
        #expect(credits.availableCount == 6)
        #expect(credits.availableCards.map(\.id) == ["valid"])
        #expect(credits.availableCards.first?.title == nil)
        #expect(credits.availableCards.first?.description == nil)
    }

    private func parse(_ resetCredits: String?) throws -> CodexUsageSnapshot {
        let field = resetCredits.map { ",\"rateLimitResetCredits\":\($0)" } ?? ""
        let result = #"{"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":25,"windowDurationMins":300},"credits":{"balance":"42"}}"# + field + "}}"
        return try CodexResponseParser.parse(
            accountData: Data(#"{"result":{"account":null}}"#.utf8),
            rateLimitsData: Data(result.utf8),
            usageData: Data(#"{"result":{"summary":null}}"#.utf8)
        )
    }
}
