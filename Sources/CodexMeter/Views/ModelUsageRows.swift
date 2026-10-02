import SwiftUI

struct ModelUsageRows: View {
    @EnvironmentObject private var settings: AppSettings

    let rows: [ModelTokenUsage]
    let isLoaded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(Color.meterAccent).frame(width: 5, height: 5)
                Text(ModelUsageL10n.text(.title, language: settings.language))
                    .meterText(.title)
                Spacer(minLength: 8)
                Text(ModelUsageL10n.text(.localLogs, language: settings.language))
                    .meterText(.detail)
                    .foregroundStyle(Color.meterSecondary)
            }
            .padding(.bottom, 4)

            if !isLoaded || rows.isEmpty {
                Text(isLoaded
                     ? ModelUsageL10n.text(.noRecords, language: settings.language)
                     : L10n.text(.calculatingUsage, language: settings.language))
                    .meterText(.detail)
                    .foregroundStyle(Color.meterSecondary)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            } else {
                let total = rows.reduce(LocalTokenUsage.zero) { $0.adding($1.usage) }.totalTokens
                ForEach(rows) { row in
                    modelRow(row, totalTokens: total)
                    if row.id != rows.last?.id {
                        Rectangle().fill(Color.meterBorder).frame(height: 1)
                    }
                }
            }
        }
        .accessibilityIdentifier("model-usage-rows")
    }

    private func modelRow(_ row: ModelTokenUsage, totalTokens: Int64) -> some View {
        let share = totalTokens > 0 ? Double(row.usage.totalTokens) / Double(totalTokens) : 0
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle().fill(Color.meterAccent).frame(width: 5, height: 5)
                Text(row.model.isEmpty
                     ? ModelUsageL10n.text(.unknownModel, language: settings.language) : row.model)
                    .meterText(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text(MeterFormatters.tokens(row.usage.totalTokens, language: settings.language))
                    .meterText(.title)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            MeterProgressBar(progress: share, height: 4)

            HStack(spacing: 5) {
                Text("\(L10n.text(.inputTokens, language: settings.language)) \(MeterFormatters.tokens(row.usage.inputTokens, language: settings.language))")
                Spacer(minLength: 3)
                Text("\(L10n.text(.outputTokens, language: settings.language)) \(MeterFormatters.tokens(row.usage.outputTokens, language: settings.language))")
                Spacer(minLength: 3)
                Text(MeterFormatters.usd(row.usage.apiEquivalentCostUSD))
            }
            .meterText(.detail)
            .foregroundStyle(Color.meterSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 13)
    }
}
