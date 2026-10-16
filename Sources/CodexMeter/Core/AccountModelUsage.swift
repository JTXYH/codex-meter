import Foundation

/// Account-wide model usage. The share is based on the endpoint's relative
/// credits within one response, not on token counts or local session records.
struct AccountModelIdentity: Identifiable, Equatable, Hashable, Sendable {
    let model: String
    let serviceTier: String?
    let usageShare: Double?
    var id: String { "\(model)\u{1F}\(serviceTier ?? "standard")" }
    var isFast: Bool { serviceTier == "fast" }

    init(model: String, serviceTier: String? = nil, usageShare: Double? = nil) {
        self.model = model
        let tier = serviceTier?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.serviceTier = tier == nil || tier == "" || tier == "standard" ? nil : tier
        self.usageShare = usageShare.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
    }
}

enum AccountModelLoadState: Equatable, Sendable {
    case idle, loading, loaded, unsupported, failed
}

struct AccountModelList: Equatable, Sendable {
    var models: [AccountModelIdentity] = []
    var state: AccountModelLoadState = .idle
    var isStale = false
}

struct AccountModelDateRange: Hashable, Sendable {
    let start: Date
    /// The API's end_date is inclusive.
    let end: Date

    init?(period: UsagePeriod, containing date: Date, now: Date = Date(), calendar: Calendar = UsageCalendar.calendar) {
        guard period != .hour,
              let interval = period.interval(containing: date, calendar: calendar),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end)
        else { return nil }
        start = calendar.startOfDay(for: interval.start)
        end = min(calendar.startOfDay(for: lastDay), calendar.startOfDay(for: now))
        guard start <= end else { return nil }
    }

    func dateString(_ date: Date, calendar: Calendar = UsageCalendar.calendar) -> String {
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", values.year ?? 0, values.month ?? 0, values.day ?? 0)
    }
}

protocol AccountModelUsageLoading {
    func fetchModels(in range: AccountModelDateRange, account: CodexAccount) async throws -> [AccountModelIdentity]
}

enum AccountModelUsageError: Error, Equatable {
    case unsupported
    case authenticationUnavailable
    case accountChanged
    case invalidResponse
    case requestFailed
}

enum AccountModelResponseParser {
    static func parse(_ data: Data, range: AccountModelDateRange, calendar: Calendar = UsageCalendar.calendar) throws -> [AccountModelIdentity] {
        let response: Response
        do { response = try JSONDecoder().decode(Response.self, from: data) }
        catch { throw AccountModelUsageError.invalidResponse }
        guard response.groupBy == "day" else { throw AccountModelUsageError.unsupported }
        var result: [AccountModelIdentity] = []
        var indexes: [String: Int] = [:]
        var weights: [Double] = []
        var completeWeights = response.units == "percent"
        for bucket in response.data {
            guard let date = DateOnlyParser.date(from: bucket.date, timeZone: calendar.timeZone) else {
                throw AccountModelUsageError.invalidResponse
            }
            let day = calendar.startOfDay(for: date)
            guard day >= range.start, day <= range.end else { continue }
            for item in bucket.models {
                let model = item.model.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !model.isEmpty, model.count <= 256,
                      model.rangeOfCharacter(from: .controlCharacters) == nil else {
                    throw AccountModelUsageError.invalidResponse
                }
                let identity = AccountModelIdentity(model: model, serviceTier: item.speed)
                let index: Int
                if let existing = indexes[identity.id] {
                    index = existing
                } else {
                    index = result.count
                    indexes[identity.id] = index
                    result.append(identity)
                    weights.append(0)
                }
                if let credits = item.credits, credits.isFinite, credits >= 0 {
                    weights[index] += credits
                } else {
                    completeWeights = false
                }
            }
        }
        // The server normalizes all buckets in one response to a common scale.
        // Sum those weights before normalizing; independently fetched daily
        // percentages would discard their relative daily usage.
        let total = weights.reduce(0, +)
        guard completeWeights, total.isFinite, total > 0 else { return result }
        return result.enumerated().map { index, model in
            AccountModelIdentity(model: model.model, serviceTier: model.serviceTier, usageShare: weights[index] / total)
        }
    }

    private struct Response: Decodable {
        let data: [Bucket]
        let groupBy: String
        let units: String?
        enum CodingKeys: String, CodingKey { case data, units; case groupBy = "group_by" }
    }
    private struct Bucket: Decodable {
        let date: String
        let models: [Model]
    }
    private struct Model: Decodable {
        let model: String
        let speed: String?
        let credits: Double?

        enum CodingKeys: String, CodingKey { case model, speed, credits }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            model = try values.decode(String.self, forKey: .model)
            speed = try values.decodeIfPresent(String.self, forKey: .speed)
            // A missing or malformed weight must not hide the model identity.
            credits = try? values.decode(Double.self, forKey: .credits)
        }
    }
}

/// Uses the existing Codex login only. Credentials stay in memory, and the request
/// is pinned to the same account as the app-server snapshot.
final class CodexAccountModelClient: AccountModelUsageLoading {
    private let loginReader: CodexSavedLoginReader
    private let session: URLSession
    private let redirectGuard = AccountModelRedirectGuard()

    init(loginReader: CodexSavedLoginReader = CodexSavedLoginReader()) {
        self.loginReader = loginReader
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func fetchModels(in range: AccountModelDateRange, account: CodexAccount) async throws -> [AccountModelIdentity] {
        guard account.accountID?.isEmpty == false else { throw AccountModelUsageError.unsupported }
        let login = try loginReader.read(for: account)
        var components = URLComponents(string: "https://chatgpt.com/backend-api/wham/usage/daily-token-usage-breakdown")!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: range.dateString(range.start)),
            URLQueryItem(name: "end_date", value: range.dateString(range.end)),
            URLQueryItem(name: "group_by", value: "day"),
        ]
        var request = URLRequest(url: components.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("Bearer \(login.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(login.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-cli", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw AccountModelUsageError.requestFailed }
        // Signing out or switching workspaces while a request is in flight must
        // not publish that account's result under the new account.
        let currentLogin = try loginReader.read(for: account)
        guard currentLogin.accountID == login.accountID else { throw AccountModelUsageError.accountChanged }
        guard let http = response as? HTTPURLResponse else { throw AccountModelUsageError.invalidResponse }
        switch http.statusCode {
        case 200: break
        case 401: throw AccountModelUsageError.authenticationUnavailable
        case 403, 404, 405, 501: throw AccountModelUsageError.unsupported
        default: throw AccountModelUsageError.requestFailed
        }
        guard data.count <= 8 * 1_024 * 1_024 else { throw AccountModelUsageError.invalidResponse }
        return try AccountModelResponseParser.parse(data, range: range)
    }
}

private final class AccountModelRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct CodexSavedLoginReader {
    let authURL: URL

    init(authURL: URL? = nil) {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        self.authURL = authURL ?? home.appendingPathComponent("auth.json")
    }

    func read(for account: CodexAccount? = nil) throws -> CodexSavedLogin {
        let login: CodexSavedLogin
        do {
            let auth = try JSONDecoder().decode(AuthFile.self, from: Data(contentsOf: authURL))
            guard let tokens = auth.tokens, !tokens.accessToken.isEmpty, !tokens.accountID.isEmpty,
                  let claims = Self.claims(tokens.idToken), let email = claims["email"] as? String, !email.isEmpty
            else { throw AccountModelUsageError.authenticationUnavailable }
            login = CodexSavedLogin(accountID: tokens.accountID, email: email, accessToken: tokens.accessToken)
        } catch { throw AccountModelUsageError.authenticationUnavailable }
        if let account {
            guard account.type == "chatgpt" else { throw AccountModelUsageError.unsupported }
            guard let email = account.email, email.caseInsensitiveCompare(login.email) == .orderedSame,
                  account.accountID == nil || account.accountID == login.accountID
            else { throw AccountModelUsageError.accountChanged }
        }
        return login
    }

    private static func claims(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }
        var value = String(segments[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private struct AuthFile: Decodable { let tokens: Tokens? }
    private struct Tokens: Decodable {
        let accessToken: String
        let accountID: String
        let idToken: String
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token", accountID = "account_id", idToken = "id_token"
        }
    }
}

struct CodexSavedLogin {
    let accountID: String
    let email: String
    fileprivate let accessToken: String
}
