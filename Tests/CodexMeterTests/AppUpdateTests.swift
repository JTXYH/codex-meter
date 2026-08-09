import Foundation
import Testing
@testable import CodexMeter

struct AppUpdateTests {
    @Test
    func comparesNumericVersionComponents() throws {
        let versionOneNine = try #require(AppVersion("1.9.0"))
        let versionOneTen = try #require(AppVersion("1.10.0"))
        let versionTwo = try #require(AppVersion("v2.0"))

        #expect(versionOneNine < versionOneTen)
        #expect(versionOneTen < versionTwo)
        #expect(AppVersion("1.0") == AppVersion("1.0.0"))
    }

    @Test
    func ordersPrereleasesBeforeStableVersions() throws {
        let beta = try #require(AppVersion("1.1.0-beta.2"))
        let releaseCandidate = try #require(AppVersion("1.1.0-rc.1"))
        let stable = try #require(AppVersion("1.1.0"))

        #expect(beta < releaseCandidate)
        #expect(releaseCandidate < stable)
    }

    @Test
    func rejectsMalformedVersions() {
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1..2") == nil)
        #expect(AppVersion("1.0.0-") == nil)
    }

    @Test
    func detectsAnAvailableUpdate() throws {
        let release = AppUpdateRelease(
            digest: nil,
            downloadURL: try #require(URL(
                string: "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0-macOS.zip"
            )),
            fileName: "CodexMeter-1.1.0-macOS.zip",
            fileSize: 1_024,
            notes: "Update notes",
            publishedAt: "2026-08-09T00:00:00Z",
            releasePageURL: try #require(URL(
                string: "https://github.com/JTXYH/codex-meter/releases/tag/v1.1.0"
            )),
            title: "Codex Meter 1.1.0",
            version: "1.1.0"
        )

        #expect(release.isNewer(than: "1.0.0"))
        #expect(!release.isNewer(than: "1.1.0"))
        #expect(release.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsUntrustedUpdateMetadata() throws {
        let release = AppUpdateRelease(
            digest: "sha256:\(String(repeating: "a", count: 64))",
            downloadURL: try #require(URL(
                string: "https://github.com/attacker/codex-meter/releases/download/v9.9.9/CodexMeter-9.9.9-macOS.zip"
            )),
            fileName: "CodexMeter-9.9.9-macOS.zip",
            fileSize: 1_024,
            notes: "Update notes",
            publishedAt: "2026-08-09T00:00:00Z",
            releasePageURL: try #require(URL(
                string: "https://github.com/JTXYH/codex-meter/releases/tag/v9.9.9"
            )),
            title: "Codex Meter 9.9.9",
            version: "9.9.9"
        )

        #expect(!release.isTrustedUpdateMetadata)
    }
}
