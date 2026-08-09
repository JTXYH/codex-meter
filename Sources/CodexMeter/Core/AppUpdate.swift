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

        let withoutBuildMetadata = value.split(separator: "+", maxSplits: 1).first.map(String.init) ?? value
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
        guard AppVersion(version) != nil,
              Self.isTrustedGitHubURL(downloadURL, route: "download"),
              Self.isTrustedGitHubURL(releasePageURL, route: "tag"),
              Self.isSafeFileName(fileName),
              downloadURL.lastPathComponent == fileName,
              fileSize > 0,
              fileSize <= Self.maximumPackageSize,
              digest.map(Self.isValidSHA256Digest) ?? true else {
            return false
        }
        return true
    }

    private static func isTrustedGitHubURL(_ url: URL, route: String) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == trustedGitHubHost,
              url.port == nil,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil else {
            return false
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 5,
              components[0].caseInsensitiveCompare(trustedOwner) == .orderedSame,
              components[1].caseInsensitiveCompare(trustedRepository) == .orderedSame,
              components[2] == "releases",
              components[3] == route else {
            return false
        }
        return route != "download" || components.count >= 6
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
              url.scheme == "https" else {
            return nil
        }
        feedURL = url
        self.session = session
    }

    init?(feedURL: URL, session: URLSession = .shared) {
        guard feedURL.scheme == "https" else { return nil }
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
        guard let httpResponse = response as? HTTPURLResponse else {
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
}
