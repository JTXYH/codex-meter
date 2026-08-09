import Testing
@testable import CodexMeter

struct EmailPrivacyTests {
    @Test
    func masksEmailWithoutRevealingTheLocalPartLength() {
        #expect(EmailPrivacy.masked("sample.user@example.com") == "sa••••@example.com")
        #expect(EmailPrivacy.masked("abc@example.com") == "ab••••@example.com")
        #expect(EmailPrivacy.masked("ab@example.com") == "a••••@example.com")
        #expect(EmailPrivacy.masked("a@example.com") == "••••@example.com")
    }

    @Test
    func fullyMasksMalformedAddresses() {
        #expect(EmailPrivacy.masked("not-an-email") == "••••••••")
        #expect(EmailPrivacy.masked("") == "••••••••")
    }
}
