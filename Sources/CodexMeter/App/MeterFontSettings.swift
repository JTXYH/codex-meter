import Foundation

enum MeterTextRole: String, CaseIterable, Identifiable, Sendable {
    case value, title, detail

    var id: String { rawValue }

    var range: ClosedRange<Double> {
        switch self {
        case .value: 10...24
        case .title: 9...18
        case .detail: 8...14
        }
    }

    var defaultSize: Double {
        switch self {
        case .value: 16
        case .title: 12
        case .detail: 10
        }
    }

    func sanitized(_ size: Double) -> Double {
        guard size.isFinite else { return defaultSize }
        let clamped = min(max(size, range.lowerBound), range.upperBound)
        return (clamped * 2).rounded() / 2
    }
}

struct MeterFontSizes: Codable, Equatable, Sendable {
    var value: Double = MeterTextRole.value.defaultSize
    var title: Double = MeterTextRole.title.defaultSize
    var detail: Double = MeterTextRole.detail.defaultSize

    subscript(_ role: MeterTextRole) -> Double {
        get {
            switch role {
            case .value: value
            case .title: title
            case .detail: detail
            }
        }
        set {
            switch role {
            case .value: value = role.sanitized(newValue)
            case .title: title = role.sanitized(newValue)
            case .detail: detail = role.sanitized(newValue)
            }
        }
    }

    var sanitized: Self {
        var result = self
        for role in MeterTextRole.allCases { result[role] = self[role] }
        return result
    }
}

struct MeterFontSettings: Codable, Equatable, Sendable {
    var content = MeterFontSizes()
    var quota = MeterFontSizes()
    var overrides: [String: MeterFontSizes] = [:]

    static var contentSections: [DashboardSection] {
        DashboardSection.allCases.filter { $0 != .quota }
    }

    func sizes(for section: DashboardSection?) -> MeterFontSizes {
        guard let section else { return content }
        return section == .quota ? quota : overrides[section.rawValue] ?? content
    }

    mutating func setSize(_ size: Double, role: MeterTextRole, section: DashboardSection?) {
        if let section {
            var updated = sizes(for: section)
            updated[role] = size
            if section == .quota { quota = updated }
            else { overrides[section.rawValue] = updated }
        } else {
            content[role] = size
            // Global edits align this role across content cards without touching quota.
            for id in Array(overrides.keys) { overrides[id]?[role] = size }
        }
        self = sanitized
    }

    mutating func applyToContentCards(from section: DashboardSection) {
        guard section != .quota else { return }
        content = sizes(for: section)
        overrides = [:]
    }

    mutating func reset(section: DashboardSection?) {
        if let section {
            if section == .quota { quota = MeterFontSizes() }
            else { overrides[section.rawValue] = MeterFontSizes() }
        } else {
            content = MeterFontSizes()
            overrides = [:]
        }
        self = sanitized
    }

    var sanitized: Self {
        var result = self
        result.content = content.sanitized
        result.quota = quota.sanitized
        result.overrides = overrides.reduce(into: [:]) { cleaned, entry in
            guard let section = DashboardSection(rawValue: entry.key), section != .quota else { return }
            let sizes = entry.value.sanitized
            if sizes != result.content { cleaned[entry.key] = sizes }
        }
        return result
    }
}
