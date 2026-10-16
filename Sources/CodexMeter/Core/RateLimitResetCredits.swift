import Foundation

/// Official available count and the optional, potentially capped detail list.
struct RateLimitResetCredits: Equatable, Sendable, Decodable {
    let availableCount: Int
    let credits: [RateLimitResetCredit]?

    init(availableCount: Int, credits: [RateLimitResetCredit]?) {
        self.availableCount = availableCount
        self.credits = credits
    }

    var availableCards: [RateLimitResetCredit] {
        var seen = Set<String>()
        return (credits ?? [])
            .filter { $0.status == "available" && seen.insert($0.id).inserted }
            .sorted {
                switch ($0.expiresAt, $1.expiresAt) {
                case let (lhs?, rhs?): return lhs == rhs ? $0.id < $1.id : lhs < rhs
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return $0.id < $1.id
                }
            }
    }

    private enum CodingKeys: String, CodingKey { case availableCount, credits }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let count = try container.decode(Int.self, forKey: .availableCount)
        guard count >= 0 else {
            throw DecodingError.dataCorruptedError(forKey: .availableCount, in: container,
                                                   debugDescription: "A reset credit count cannot be negative")
        }
        availableCount = count
        // A bad detail field must not discard the independently reported count.
        // A lossy element wrapper still advances the decoder for malformed rows.
        credits = (try? container.decodeIfPresent([OptionalCredit].self, forKey: .credits))?
            .compactMap(\.value)
    }

    private struct OptionalCredit: Decodable {
        let value: RateLimitResetCredit?
        init(from decoder: Decoder) throws {
            value = try? RateLimitResetCredit(from: decoder)
        }
    }
}

struct RateLimitResetCredit: Identifiable, Equatable, Sendable, Decodable {
    let id: String
    let resetType: String
    let status: String
    let grantedAt: Date
    /// An explicit null from the server means this card never expires.
    let expiresAt: Date?
    let title: String?
    let description: String?

    init(id: String, resetType: String, status: String, grantedAt: Date,
         expiresAt: Date?, title: String? = nil, description: String? = nil) {
        self.id = id
        self.resetType = resetType
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id, resetType, status, grantedAt, expiresAt, title, description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container,
                                                   debugDescription: "A reset credit must have an ID")
        }
        resetType = try container.decode(String.self, forKey: .resetType)
        status = try container.decode(String.self, forKey: .status)
        grantedAt = Date(timeIntervalSince1970: TimeInterval(try container.decode(Int64.self, forKey: .grantedAt)))
        // Missing or invalid expiry is not equivalent to an explicit null.
        guard container.contains(.expiresAt) else {
            throw DecodingError.keyNotFound(CodingKeys.expiresAt,
                .init(codingPath: decoder.codingPath, debugDescription: "Missing reset credit expiry"))
        }
        expiresAt = try container.decodeIfPresent(Int64.self, forKey: .expiresAt)
            .map { Date(timeIntervalSince1970: TimeInterval($0)) }
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
    }
}
