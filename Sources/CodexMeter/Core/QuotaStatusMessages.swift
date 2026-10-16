import Foundation

enum QuotaStatus: String, CaseIterable, Identifiable, Sendable {
    case ready, low, exhausted
    var id: String { rawValue }

    init(remainingPercent: Double) {
        self = remainingPercent <= 0 ? .exhausted : remainingPercent < 30 ? .low : .ready
    }

    func defaultText(language: AppLanguage) -> String {
        switch self {
        case .ready: RedesignL10n.text(.ready, language: language)
        case .low: RedesignL10n.text(.low, language: language)
        case .exhausted: RedesignL10n.text(.exhausted, language: language)
        }
    }
}

/// Empty values are intentional: they follow the selected language's defaults.
struct QuotaStatusMessages: Codable, Equatable, Sendable {
    static let maximumLength = 40
    var ready = ""
    var low = ""
    var exhausted = ""

    subscript(status: QuotaStatus) -> String {
        get {
            switch status {
            case .ready: ready
            case .low: low
            case .exhausted: exhausted
            }
        }
        set {
            switch status {
            case .ready: ready = newValue
            case .low: low = newValue
            case .exhausted: exhausted = newValue
            }
        }
    }

    func text(for status: QuotaStatus, language: AppLanguage) -> String {
        let custom = sanitized[status].trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? status.defaultText(language: language) : custom
    }

    var sanitized: Self {
        var result = self
        for status in QuotaStatus.allCases {
            // Keep spaces while editing, but turn pasted multiline text into one line.
            let singleLine = self[status].unicodeScalars.compactMap { scalar -> String? in
                if CharacterSet.whitespacesAndNewlines.contains(scalar) { return " " }
                if scalar.properties.generalCategory == .control { return nil }
                return String(scalar)
            }.joined()
            result[status] = String(singleLine.prefix(Self.maximumLength))
        }
        return result
    }
}
