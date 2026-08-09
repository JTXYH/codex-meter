import Foundation

enum EmailPrivacy {
    private static let hiddenLocalPart = "••••"
    private static let hiddenAddress = "••••••••"

    static func masked(_ email: String) -> String {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = address.lastIndex(of: "@"),
              separator > address.startIndex,
              separator < address.index(before: address.endIndex)
        else {
            return hiddenAddress
        }

        let localPart = address[..<separator]
        let domainStart = address.index(after: separator)
        let domain = address[domainStart...]
        let visibleCount = min(2, max(0, localPart.count - 1))
        let visiblePrefix = localPart.prefix(visibleCount)
        return "\(visiblePrefix)\(hiddenLocalPart)@\(domain)"
    }
}
