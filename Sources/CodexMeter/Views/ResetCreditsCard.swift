import SwiftUI

struct ResetCreditsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.meterFontSizes) private var fontSizes
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: CodexUsageSnapshot

    var body: some View {
        let presentation = ResetCreditsPresentation(credits: snapshot.resetCredits, language: settings.language)
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(text(.title)).meterText(.title, size: 14, weight: .semibold)
                    Spacer(minLength: 8)
                    countBadge(presentation.count)
                }.frame(minHeight: 24).padding(.bottom, 12)

                if presentation.groups.isEmpty {
                    emptyState(presentation.count)
                } else {
                    ForEach(presentation.groups) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            summary(group)
                            ForEach(group.rows) { row in
                                cardRow(row)
                            }
                        }.padding(.top, group.id == presentation.groups.first?.id ? 0 : 16)
                    }
                    if presentation.missingCount > 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Circle().fill(Color.meterTertiary).frame(width: 4, height: 4)
                            Text(ResetCreditsL10n.missingDetails(presentation.missingCount, language: settings.language))
                                .meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }.padding(.top, 14)
                    }

                }
            }
            .padding(.top, 3)
            .padding(.bottom, -1)
        }
        .accessibilityIdentifier("reset-credits-card")
    }

    private func countBadge(_ count: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(count.map(String.init) ?? "—").meterText(.value, size: 13, weight: .semibold)
            if count != nil { Text(text(.available)).meterText(.detail, size: 10) }
        }
        .foregroundStyle((count ?? 0) > 0 ? theme.accent : Color.meterSecondary)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background((count ?? 0) > 0 ? theme.accentSoft : Color.meterPanel, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityIdentifier("reset-credits-count")
    }

    private func summary(_ group: ResetCreditsPresentation.Group) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(group.title).meterText(.title, size: 12, weight: .medium)
                if let detail = group.detail {
                    Text(detail).meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary)
                }
            }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title).meterText(.title, size: 12, weight: .medium)
                if let detail = group.detail {
                    Text(detail).meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary)
                }
            }.fixedSize(horizontal: false, vertical: true)
        }.frame(minHeight: 18, alignment: .leading).padding(.bottom, 8)
    }

    private func cardRow(_ row: ResetCreditsPresentation.Row) -> some View {
        HStack(spacing: 14) {
            Text(row.index)
                .font(.custom("Menlo-Regular", size: 10 * CGFloat(fontSizes.detail / 10)))
                .foregroundStyle(Color.meterTertiary)
                .frame(width: 20 * CGFloat(fontSizes.detail / 10), alignment: .leading)
            Text(row.date).meterText(.title, size: 13, weight: .medium)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let time = row.time {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(time).font(.custom("Menlo-Regular", size: 13 * CGFloat(fontSizes.value / 16)))
                    Text(text(.expires)).meterText(.detail, size: 10).foregroundStyle(Color.meterTertiary)
                }.fixedSize()
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.index), \(row.accessibilityDate)")
        .help(row.accessibilityDate)
        .accessibilityIdentifier("reset-credit-\(row.id)")
    }

    private func emptyState(_ count: Int?) -> some View {
        let unavailable = count == nil
        let empty = count == 0
        return VStack(spacing: 0) {
            Image(systemName: unavailable ? "exclamationmark.circle" : "rectangle.on.rectangle")
                .font(.system(size: 29, weight: .light)).foregroundStyle(Color.meterTertiary)
                .frame(width: 37, height: 37).padding(.bottom, 8)
            Text(text(unavailable ? .unavailableTitle : empty ? .emptyTitle : .detailsUnavailable))
                .meterText(.title, size: 13, weight: .medium).padding(.bottom, 5)
            Text(count.map { $0 > 0 ? ResetCreditsL10n.countOnly($0, language: settings.language) : text(.emptyDetail) }
                 ?? text(.unavailableDetail))
                .meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12).padding(.top, 31).padding(.bottom, 35)
        .background(emptyBackground, in: RoundedRectangle(cornerRadius: 9))
    }

    private var emptyBackground: Color {
        color(colorScheme == .dark ? (theme.isInstrument ? 0x293530 : 0x2d2c38)
              : (theme.isInstrument ? 0xf3f7f5 : 0xf6f6fb))
    }
    private func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    private func text(_ key: ResetCreditsL10n.Key) -> String { ResetCreditsL10n.text(key, language: settings.language) }
}

/// Formats the account response without deriving an account count from a possibly capped detail list.
struct ResetCreditsPresentation {
    struct Row: Identifiable {
        let id: String
        let index: String
        let date: String
        let time: String?
        let accessibilityDate: String
    }
    struct Group: Identifiable {
        let id: String
        let resetType: String
        let title: String
        let detail: String?
        var rows: [Row]
    }
    let count: Int?
    let missingCount: Int
    let groups: [Group]

    init(credits: RateLimitResetCredits?, language: AppLanguage, now: Date = Date(), timeZone: TimeZone = .current) {
        count = credits?.availableCount
        let cards = (count ?? 0) > 0 ? (credits?.availableCards ?? []) : []
        missingCount = max(0, (count ?? 0) - cards.count)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        func formatter(_ template: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = language.locale
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }
        let shortDate = formatter("MMMd")
        let fullDate = formatter("yMMMd")
        if language == .simplifiedChinese || language == .traditionalChinese {
            shortDate.dateFormat = "M 月 d 日"
            fullDate.dateFormat = "yyyy 年 M 月 d 日"
        }
        let clock = formatter("HHmm")
        clock.dateFormat = "HH:mm"

        var result: [Group] = []
        for (index, card) in cards.enumerated() {
            let title: String
            let detail: String?
            if card.resetType == "codexRateLimits" {
                title = ResetCreditsL10n.text(.fullReset, language: language)
                detail = ResetCreditsL10n.text(.fullResetScope, language: language)
            } else {
                title = Self.nonempty(card.title) ?? ResetCreditsL10n.text(.unknownType, language: language)
                detail = Self.nonempty(card.description)
            }
            let row: Row
            if let date = card.expiresAt {
                let dateFormatter = calendar.isDate(date, equalTo: now, toGranularity: .year) ? shortDate : fullDate
                row = Row(id: card.id, index: String(format: "%02d", index + 1), date: dateFormatter.string(from: date),
                          time: clock.string(from: date),
                          accessibilityDate: "\(fullDate.string(from: date)) \(clock.string(from: date)) \(Self.offsetLabel(seconds: timeZone.secondsFromGMT(for: date))) \(ResetCreditsL10n.text(.expires, language: language))")
            } else {
                let never = ResetCreditsL10n.text(.neverExpires, language: language)
                row = Row(id: card.id, index: String(format: "%02d", index + 1), date: never, time: nil, accessibilityDate: never)
            }
            // Contiguous groups preserve expiry order even if different card types are interleaved.
            if result.last?.resetType == card.resetType && result.last?.title == title && result.last?.detail == detail {
                result[result.count - 1].rows.append(row)
            } else {
                result.append(Group(id: card.id, resetType: card.resetType, title: title, detail: detail, rows: [row]))
            }
        }
        groups = result
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
    private static func offsetLabel(seconds: Int) -> String {
        let minutes = abs(seconds) / 60
        if minutes == 0 { return "GMT" }
        let suffix = minutes % 60 == 0 ? "\(minutes / 60)" : String(format: "%d:%02d", minutes / 60, minutes % 60)
        return "GMT\(seconds < 0 ? "−" : "+")\(suffix)"
    }
}
