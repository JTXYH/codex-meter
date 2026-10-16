import SwiftUI

struct PanelTokenAmount {
    let number: String
    let unit: String
    var text: String { number + unit }

    init(_ value: Int64?, language: AppLanguage) {
        guard let value else { number = "—"; unit = ""; return }
        let n = Double(value)
        let chinese = language == .simplifiedChinese || language == .traditionalChinese
        let eastAsian = chinese || language == .japanese || language == .korean
        let scale: Double
        if eastAsian {
            if abs(n) >= 100_000_000 {
                scale = 100_000_000
                unit = language == .simplifiedChinese ? "亿" : language == .korean ? "억" : "億"
            } else if abs(n) >= 10_000 {
                scale = 10_000
                unit = (language == .simplifiedChinese || language == .japanese) ? "万" : language == .korean ? "만" : "萬"
            } else { scale = 1; unit = "" }
        } else {
            switch abs(n) {
            case 1_000_000_000...: scale = 1_000_000_000; unit = "B"
            case 1_000_000...: scale = 1_000_000; unit = "M"
            case 1_000...: scale = 1_000; unit = "K"
            default: scale = 1; unit = ""
            }
        }
        let scaled = n / scale
        let digits = scale == 1 || abs(scaled) >= 1000 || (eastAsian && scale == 10_000 && abs(scaled) >= 100) ? 0 : abs(scaled) >= 10 ? 1 : 2
        number = scaled.formatted(.number.grouping(.never).precision(.fractionLength(0...digits)).locale(language.locale))
    }
}

struct PanelTokenNumber: View {
    @EnvironmentObject private var settings: AppSettings
    let value: Int64?
    var size: CGFloat
    var unitSize: CGFloat? = nil
    var spacing: CGFloat = 2

    var body: some View {
        let amount = PanelTokenAmount(value, language: settings.language)
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            Text(amount.number).meterText(.value, size: size, weight: .medium)
                .tracking(size >= 25 ? -1 : -0.6)
            if !amount.unit.isEmpty {
                Text(amount.unit).meterText(.value, size: unitSize ?? size, weight: .medium)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { String($0) + " Token" } ?? "—")
    }
}

struct PanelCardHeading: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 10) {
            Text(title).meterText(.title, size: 13, weight: .semibold).tracking(0.1)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }.frame(minHeight: 19.5)
    }
}

struct PanelRule: View {
    var body: some View { Rectangle().fill(Color.meterBorder).frame(height: 1) }
}
