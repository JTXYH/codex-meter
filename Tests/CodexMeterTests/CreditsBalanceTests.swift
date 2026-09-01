import Foundation
import Testing
@testable import CodexMeter

struct CreditsBalanceTests {
    @Test(arguments: [nil, "", "  \n", "NaN", "Infinity", "12 credits", "1,250.5", "1.2.3"] as [String?])
    func missingOrInvalidBalancesAreUnavailable(balance: String?) {
        #expect(CreditBalance(balance: balance, unlimited: false) == .unavailable)
    }

    @Test
    func preservesZeroAndDecimalBalances() {
        #expect(CreditBalance(balance: "0", unlimited: false) == .amount(0))
        #expect(CreditBalance(balance: " 1250.50\n", unlimited: nil) == .amount(decimal("1250.5")))
        #expect(CreditBalance(balance: "0.000001", unlimited: false) == .amount(decimal("0.000001")))
        #expect(CreditBalance(balance: "-0.25", unlimited: false) == .amount(decimal("-0.25")))
    }

    @Test(arguments: [nil, "0", "1250.5"] as [String?])
    func unlimitedTakesPriorityOverNumericBalance(balance: String?) {
        #expect(CreditBalance(balance: balance, unlimited: true) == .unlimited)
    }

    @Test
    func formatsCreditsAsUSDWithTwoFractionDigits() {
        #expect(MeterFormatters.credits(.amount(0), language: .english) == "$0.00")
        #expect(MeterFormatters.credits(.amount(2_500), language: .english) == "$100.00")
        #expect(MeterFormatters.credits(.amount(1_905), language: .english) == "$76.20")
        #expect(MeterFormatters.credits(.amount(decimal("1250.5")), language: .english) == "$50.02")
        #expect(MeterFormatters.credits(.amount(decimal("0.000001")), language: .english) == "$0.00")
        #expect(MeterFormatters.credits(.amount(decimal("-0.25")), language: .english) == "-$0.01")
        #expect(MeterFormatters.credits(.amount(1_905), language: .spanish) == "$76.20")
        #expect(MeterFormatters.credits(.unlimited, language: .english) == "Unlimited")
        #expect(MeterFormatters.credits(.unavailable, language: .simplifiedChinese) == "暂无数据")
    }

    @Test(arguments: AppLanguage.allCases)
    func localizesBalanceStates(language: AppLanguage) {
        for key: L10n.Key in [
            .creditsBalance, .creditsBalanceUnavailable, .unlimitedCredits,
            .display, .displayHint,
            .showQuotaCard, .showQuotaCardHint,
            .showTokenActivityCard, .showTokenActivityCardHint,
            .showUsageHeatmapCard, .showUsageHeatmapCardHint,
            .showUsageSummaryCard, .showUsageSummaryCardHint,
            .showCreditsBalanceCard, .showCreditsBalanceCardHint,
        ] {
            #expect(!L10n.text(key, language: language).isEmpty)
        }
        #expect(MeterFormatters.credits(.unlimited, language: language)
            != MeterFormatters.credits(.unavailable, language: language))
    }

    @Test
    func prefersCodexBucketWithoutAddingOtherBalances() throws {
        let snapshot = try parse(#"{"rateLimitsByLimitId":{"other":{"credits":{"balance":"999"}},"codex":{"credits":{"hasCredits":true,"unlimited":false,"balance":"1250.5"}}}}"#)
        #expect(snapshot.creditsBalance == .amount(decimal("1250.5")))
    }

    @Test
    func doesNotReplaceMissingCodexBalanceWithAnotherBucketOrZero() throws {
        let snapshot = try parse(#"{"rateLimitsByLimitId":{"other":{"credits":{"balance":"999"}},"codex":{"credits":{"hasCredits":false,"unlimited":false,"balance":null}}}}"#)
        #expect(snapshot.creditsBalance == .unavailable)
    }

    @Test
    func usesSingleBucketAndPreservesBalanceRegardlessOfHasCreditsFlag() throws {
        let snapshot = try parse(#"{"rateLimits":{"credits":{"hasCredits":false,"balance":"12.5"}}}"#)
        #expect(snapshot.creditsBalance == .amount(decimal("12.5")))
    }

    @Test
    func supportsUnlimitedAndMissingCreditPayloads() throws {
        #expect(try parse(#"{"rateLimits":{"credits":{"unlimited":true}}}"#).creditsBalance == .unlimited)
        #expect(try parse(#"{"rateLimits":{"credits":null}}"#).creditsBalance == .unavailable)
        #expect(try parse(#"{"rateLimits":null}"#).creditsBalance == .unavailable)
    }

    @Test
    func usesFirstBucketWhenCodexBucketIsAbsent() throws {
        let snapshot = try parse(#"{"rateLimitsByLimitId":{"other":{"credits":{"balance":"42"}}}}"#)
        #expect(snapshot.creditsBalance == .amount(42))
    }

    private func decimal(_ value: String) -> Decimal {
        Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))!
    }

    private func parse(_ result: String) throws -> CodexUsageSnapshot {
        try CodexResponseParser.parse(
            accountData: Data(#"{"id":1,"result":{"account":{"type":"chatgpt"}}}"#.utf8),
            rateLimitsData: Data("{\"id\":2,\"result\":\(result)}".utf8),
            usageData: Data(#"{"id":3,"result":{"summary":null}}"#.utf8)
        )
    }
}
