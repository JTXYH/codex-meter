import Foundation

struct AppVersion: Comparable, Equatable, Sendable {
    private enum PrereleaseIdentifier: Equatable, Sendable {
        case number(Int)
        case text(String)
    }

    private let components: [Int]
    private let prerelease: [PrereleaseIdentifier]

    init?(_ rawValue: String) {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.first == "v" || value.first == "V" {
            value.removeFirst()
        }

        let buildMetadataParts = value.split(
            separator: "+",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard let versionWithoutBuildMetadata = buildMetadataParts.first else { return nil }
        if buildMetadataParts.count == 2 {
            guard Self.isValidBuildMetadata(buildMetadataParts[1]) else { return nil }
        }

        let withoutBuildMetadata = String(versionWithoutBuildMetadata)
        let versionParts = withoutBuildMetadata.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard let core = versionParts.first, !core.isEmpty else { return nil }

        let rawComponents = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(rawComponents.count) else { return nil }
        var parsedComponents: [Int] = []
        for component in rawComponents {
            guard !component.isEmpty,
                  component.allSatisfy(\.isNumber),
                  let number = Int(component) else {
                return nil
            }
            parsedComponents.append(number)
        }

        var parsedPrerelease: [PrereleaseIdentifier] = []
        if versionParts.count == 2 {
            let rawPrerelease = versionParts[1]
            let identifiers = rawPrerelease.split(separator: ".", omittingEmptySubsequences: false)
            guard !identifiers.isEmpty else { return nil }
            for identifier in identifiers {
                guard !identifier.isEmpty,
                      identifier.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else {
                    return nil
                }
                if identifier.allSatisfy(\.isNumber), let number = Int(identifier) {
                    parsedPrerelease.append(.number(number))
                } else {
                    parsedPrerelease.append(.text(String(identifier).lowercased()))
                }
            }
        }

        components = parsedComponents
        prerelease = parsedPrerelease
    }

    private static func isValidBuildMetadata(_ metadata: Substring) -> Bool {
        let identifiers = metadata.split(separator: ".", omittingEmptySubsequences: false)
        guard !identifiers.isEmpty else { return false }
        return identifiers.allSatisfy { identifier in
            !identifier.isEmpty && identifier.unicodeScalars.allSatisfy { scalar in
                let value = scalar.value
                return (48...57).contains(value)
                    || (65...90).contains(value)
                    || (97...122).contains(value)
                    || value == 45
            }
        }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let componentCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<componentCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }

        if lhs.prerelease.isEmpty != rhs.prerelease.isEmpty {
            return !lhs.prerelease.isEmpty
        }

        for (left, right) in zip(lhs.prerelease, rhs.prerelease) {
            guard left != right else { continue }
            switch (left, right) {
            case let (.number(leftNumber), .number(rightNumber)):
                return leftNumber < rightNumber
            case (.number, .text):
                return true
            case (.text, .number):
                return false
            case let (.text(leftText), .text(rightText)):
                return leftText < rightText
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

struct AppUpdateRelease: Decodable, Equatable, Sendable {
    private enum GitHubReleaseRoute: String {
        case download
        case tag

        var expectedPathComponentCount: Int {
            switch self {
            case .download: 6
            case .tag: 5
            }
        }
    }

    private static let maximumPackageSize = 512 * 1024 * 1024
    private static let trustedGitHubHost = "github.com"
    private static let trustedOwner = "JTXYH"
    private static let trustedRepository = "codex-meter"

    let digest: String?
    let downloadURL: URL
    let fileName: String
    let fileSize: Int
    let notes: String
    let publishedAt: String
    let releasePageURL: URL
    let title: String
    let version: String

    func isNewer(than currentVersion: String) -> Bool {
        guard let latest = AppVersion(version),
              let current = AppVersion(currentVersion) else {
            return false
        }
        return latest > current
    }

    var isTrustedUpdateMetadata: Bool {
        guard let normalizedVersion = Self.normalizedVersionIdentifier(version),
              let downloadLocation = Self.trustedGitHubReleaseLocation(
                downloadURL,
                route: .download
              ),
              let releasePageLocation = Self.trustedGitHubReleaseLocation(
                releasePageURL,
                route: .tag
              ),
              downloadLocation.tag == releasePageLocation.tag,
              Self.normalizedVersionIdentifier(downloadLocation.tag) == normalizedVersion,
              Self.isSafeFileName(fileName),
              downloadLocation.fileName == fileName,
              fileName == "CodexMeter-\(normalizedVersion)-macOS.zip",
              fileSize > 0,
              fileSize <= Self.maximumPackageSize,
              digest.map(Self.isValidSHA256Digest) ?? true else {
            return false
        }
        return true
    }

    private static func normalizedVersionIdentifier(_ rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue == rawValue else { return nil }

        var normalizedValue = trimmedValue
        if normalizedValue.first == "v" || normalizedValue.first == "V" {
            normalizedValue.removeFirst()
        }
        guard !normalizedValue.isEmpty,
              normalizedValue.first != "v",
              normalizedValue.first != "V",
              AppVersion(normalizedValue) != nil else {
            return nil
        }
        return normalizedValue
    }

    private static func trustedGitHubReleaseLocation(
        _ url: URL,
        route: GitHubReleaseRoute
    ) -> (tag: String, fileName: String?)? {
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              urlComponents.scheme?.lowercased() == "https",
              urlComponents.host?.lowercased() == trustedGitHubHost,
              urlComponents.port == nil,
              urlComponents.user == nil,
              urlComponents.password == nil,
              urlComponents.query == nil,
              urlComponents.fragment == nil else {
            return nil
        }

        let encodedPathComponents = urlComponents.percentEncodedPath.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard encodedPathComponents.first?.isEmpty == true else { return nil }

        var pathComponents: [String] = []
        pathComponents.reserveCapacity(encodedPathComponents.count - 1)
        for encodedComponent in encodedPathComponents.dropFirst() {
            guard !encodedComponent.isEmpty,
                  let component = String(encodedComponent).removingPercentEncoding,
                  !component.isEmpty,
                  !component.contains("/"),
                  !component.contains("\\") else {
                return nil
            }
            pathComponents.append(component)
        }

        guard pathComponents.count == route.expectedPathComponentCount,
              pathComponents[0].caseInsensitiveCompare(trustedOwner) == .orderedSame,
              pathComponents[1].caseInsensitiveCompare(trustedRepository) == .orderedSame,
              pathComponents[2] == "releases",
              pathComponents[3] == route.rawValue else {
            return nil
        }

        let fileName = route == .download ? pathComponents[5] : nil
        return (tag: pathComponents[4], fileName: fileName)
    }

    private static func isSafeFileName(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name.utf8.count <= 255,
              !name.contains("/"),
              !name.contains("\\") else {
            return false
        }
        return name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }

    private static func isValidSHA256Digest(_ value: String) -> Bool {
        value.range(
            of: #"^sha256:[0-9a-fA-F]{64}$"#,
            options: .regularExpression
        ) != nil
    }
}

enum AppUpdateClientError: Error {
    case invalidResponse
    case requestFailed(Int)
}

struct AppUpdateClient: Sendable {
    private static let maximumResponseSize = 1_048_576

    private let feedURL: URL
    private let session: URLSession

    init?(bundle: Bundle = .main, session: URLSession = .shared) {
        guard let value = bundle.object(forInfoDictionaryKey: "CodexMeterUpdateFeedURL") as? String,
              let url = URL(string: value),
              Self.isValidFeedURL(url) else {
            return nil
        }
        feedURL = url
        self.session = session
    }

    init?(feedURL: URL, session: URLSession = .shared) {
        guard Self.isValidFeedURL(feedURL) else { return nil }
        self.feedURL = feedURL
        self.session = session
    }

    func availableUpdate(currentVersion: String) async throws -> AppUpdateRelease? {
        var request = URLRequest(
            url: feedURL,
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: 15
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexMeter/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.url == feedURL else {
            throw AppUpdateClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppUpdateClientError.requestFailed(httpResponse.statusCode)
        }
        guard httpResponse.expectedContentLength < 0
                || httpResponse.expectedContentLength <= Int64(Self.maximumResponseSize) else {
            throw AppUpdateClientError.invalidResponse
        }

        var data = Data()
        if httpResponse.expectedContentLength > 0 {
            data.reserveCapacity(Int(httpResponse.expectedContentLength))
        }
        for try await byte in bytes {
            guard data.count < Self.maximumResponseSize else {
                throw AppUpdateClientError.invalidResponse
            }
            data.append(byte)
        }

        let release = try JSONDecoder().decode(AppUpdateRelease.self, from: data)
        guard release.isTrustedUpdateMetadata else {
            throw AppUpdateClientError.invalidResponse
        }
        return release.isNewer(than: currentVersion) ? release : nil
    }

    private static func isValidFeedURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host,
              !host.isEmpty,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            return false
        }
        return true
    }
}
