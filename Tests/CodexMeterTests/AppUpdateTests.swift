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
        #expect(AppVersion("1.0.0+") == nil)
        #expect(AppVersion("1.0.0+build+other") == nil)
        #expect(AppVersion("1.0.0+build..other") == nil)
        #expect(AppVersion("1.0.0+build_1") == nil)
    }

    @Test
    func acceptsValidBuildMetadataWithoutChangingPrecedence() throws {
        let firstBuild = try #require(AppVersion("1.0.0+build.1-x"))
        let secondBuild = try #require(AppVersion("1.0.0+BUILD.2"))
        let prereleaseBuild = try #require(AppVersion("1.1.0-rc.1+build.7"))
        let prerelease = try #require(AppVersion("1.1.0-rc.1"))

        #expect(firstBuild == secondBuild)
        #expect(prereleaseBuild == prerelease)
    }

    @Test
    func rejectsUnsafeUpdateFeedURLs() throws {
        let unsafeURLs = [
            "http://updates.example.com/v1/releases/latest",
            "https://user@updates.example.com/v1/releases/latest",
            "https://updates.example.com:8443/v1/releases/latest",
            "https://updates.example.com/v1/releases/latest?channel=stable",
            "https://updates.example.com/v1/releases/latest#manifest",
        ]

        for value in unsafeURLs {
            let url = try #require(URL(string: value))
            #expect(AppUpdateClient(feedURL: url) == nil)
        }
    }

    @Test
    func rejectsAFeedResponseFromADifferentFinalURL() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RedirectedFeedURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let feedURL = try #require(URL(
            string: "https://updates.example.com/v1/releases/latest"
        ))
        let client = try #require(AppUpdateClient(feedURL: feedURL, session: session))

        do {
            _ = try await client.availableUpdate(currentVersion: "1.0.0")
            Issue.record("Expected a response from a different final URL to be rejected")
        } catch AppUpdateClientError.invalidResponse {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
    func acceptsVPrefixedManifestVersionWithCanonicalAssetName() throws {
        let release = try makeRelease(version: "v1.1.0")

        #expect(release.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsDifferentDownloadAndReleaseTags() throws {
        let release = try makeRelease(
            releasePageURL: "https://github.com/JTXYH/codex-meter/releases/tag/1.1.0"
        )

        #expect(!release.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsTagThatDoesNotExactlyMatchNormalizedVersion() throws {
        let release = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0.0-macOS.zip",
            fileName: "CodexMeter-1.1.0.0-macOS.zip",
            version: "1.1.0.0"
        )

        #expect(!release.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsAssetNameThatDoesNotMatchNormalizedVersion() throws {
        let incompleteName = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0.zip",
            fileName: "CodexMeter-1.1.0.zip"
        )
        let nonZIPAsset = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0-macOS.dmg",
            fileName: "CodexMeter-1.1.0-macOS.dmg"
        )

        #expect(!incompleteName.isTrustedUpdateMetadata)
        #expect(!nonZIPAsset.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsMoreThanOneVersionPrefix() throws {
        let release = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/vv1.1.0/CodexMeter-v1.1.0-macOS.zip",
            fileName: "CodexMeter-v1.1.0-macOS.zip",
            releasePageURL: "https://github.com/JTXYH/codex-meter/releases/tag/vv1.1.0",
            version: "vv1.1.0"
        )

        #expect(!release.isTrustedUpdateMetadata)
    }

    @Test
    func rejectsExtraOrEncodedReleasePathComponents() throws {
        let nestedDownload = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/nested/CodexMeter-1.1.0-macOS.zip"
        )
        let nestedReleasePage = try makeRelease(
            releasePageURL: "https://github.com/JTXYH/codex-meter/releases/tag/v1.1.0/notes"
        )
        let encodedRouteSeparator = try makeRelease(
            downloadURL: "https://github.com/JTXYH/codex-meter/releases%2Fdownload/v1.1.0/CodexMeter-1.1.0-macOS.zip"
        )

        #expect(!nestedDownload.isTrustedUpdateMetadata)
        #expect(!nestedReleasePage.isTrustedUpdateMetadata)
        #expect(!encodedRouteSeparator.isTrustedUpdateMetadata)
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

    private func makeRelease(
        digest: String? = nil,
        downloadURL: String = "https://github.com/JTXYH/codex-meter/releases/download/v1.1.0/CodexMeter-1.1.0-macOS.zip",
        fileName: String = "CodexMeter-1.1.0-macOS.zip",
        releasePageURL: String = "https://github.com/JTXYH/codex-meter/releases/tag/v1.1.0",
        version: String = "1.1.0"
    ) throws -> AppUpdateRelease {
        AppUpdateRelease(
            digest: digest,
            downloadURL: try #require(URL(string: downloadURL)),
            fileName: fileName,
            fileSize: 1_024,
            notes: "Update notes",
            publishedAt: "2026-08-09T00:00:00Z",
            releasePageURL: try #require(URL(string: releasePageURL)),
            title: "Codex Meter \(version)",
            version: version
        )
    }
}

private final class RedirectedFeedURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseURL = URL(string: "https://redirected.example.com/manifest"),
              let response = HTTPURLResponse(
                url: responseURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: AppUpdateClientError.invalidResponse)
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
