import SwiftUI

/// Today's model details use the local scan. Account history is rendered separately.
struct ModelUsageRows: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterFontSizes) private var fontSizes
    let rows: [ModelTokenUsage]
    let isLoaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isLoaded || rows.isEmpty {
                Text(isLoaded ? ModelUsageL10n.text(.noRecords, language: settings.language)
                     : L10n.text(.calculatingUsage, language: settings.language))
                    .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 10) {
                            Text(row.model.isEmpty ? ModelUsageL10n.text(.unknownModel, language: settings.language) : row.model)
                                .meterText(.title, size: 11).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Text(PanelTokenAmount(row.usage.totalTokens, language: settings.language).text)
                                .font(.system(size: 11 * CGFloat(fontSizes.value / 16), weight: .medium))
                        }.frame(minHeight: 16.5)
                        HStack(spacing: 18) {
                            Text("\(RedesignL10n.text(.input, language: settings.language)) \(PanelTokenAmount(row.usage.inputTokens, language: settings.language).text)")
                            Text("\(RedesignL10n.text(.output, language: settings.language)) \(PanelTokenAmount(row.usage.outputTokens, language: settings.language).text)")
                        }.meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary).frame(minHeight: 13.5)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }.padding(.top, 9).padding(.bottom, row.id == rows.last?.id ? 0 : 9)
                    if row.id != rows.last?.id { PanelRule() }
                }
            }
        }.accessibilityIdentifier("model-usage-rows")
    }
}
