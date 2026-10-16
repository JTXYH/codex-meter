import SwiftUI

struct DataSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    private let database: SQLiteStore
    private let initialInfoProvided: Bool
    private let onCleanupRequest: ((SettingsCleanupRequest) -> Void)?
    @State private var info: StorageInfo?
    @State private var period = 90
    @State private var customDays = 30
    @State private var localRequest: SettingsCleanupRequest?
    @State private var showingLocalConfirmation = false
    @State private var isWorking = false
    @State private var isLoading = false
    @State private var message: String?
    @State private var error: String?

    init(database: SQLiteStore = .shared, initialInfo: StorageInfo? = nil,
         onCleanupRequest: ((SettingsCleanupRequest) -> Void)? = nil) {
        self.database = database
        self.initialInfoProvided = initialInfo != nil
        self.onCleanupRequest = onCleanupRequest
        _info = State(initialValue: initialInfo)
    }

    private func text(_ key: String) -> String { SettingsCopy.text(key, language: settings.language) }
    private func storageText(_ key: StorageL10n.Key) -> String { StorageL10n.text(key, language: settings.language) }
    private var hasRecords: Bool { (info?.dailyRows ?? 0) > 0 }
    private func formattedSize(includeCount: Bool) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        formatter.includesCount = includeCount
        formatter.includesUnit = !includeCount
        return formatter.string(fromByteCount: info?.bytes ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if info != nil && hasRecords { storageCard }
            else { storageStatus }
            SettingsCard {
                SettingsRow(title: text("cleanup"), detail: text("cleanupDetail")) {
                    SettingsSelect(title: text("cleanup"), selection: $period, options: [7, 30, 90, 180, 365, 0, -1]) {
                        if $0 == 0 { return text("cleanupCustom") }
                        if $0 == -1 { return text("cleanupAll") }
                        return SettingsCopy.cleanupAge($0, language: settings.language)
                    }
                }
                if period == 0 {
                    SettingsDivider()
                    SettingsRow(title: storageText(.customDays), detail: text("cleanupDaysHint")) {
                        HStack(spacing: 8) {
                            SettingsNumberField(title: storageText(.customDays), value: $customDays, range: 1...36_500)
                            Text(text("dayUnit")).font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 15) {
                    Text(text("cleanupPreserve")).font(.system(size: 10)).foregroundStyle(Color.meterSecondary)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true).frame(minHeight: 16.5)
                        .frame(maxWidth: 460, alignment: .leading)
                    HStack(spacing: 10) {
                        Button(action: confirmCleanup) { Text(text("cleanupAction")).frame(minWidth: 52) }
                            .buttonStyle(SettingsButtonStyle(kind: .danger))
                            .disabled(!hasRecords || isWorking || isLoading)
                            .accessibilityIdentifier("settings-cleanup")
                        if isWorking { ProgressView().controlSize(.small) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.bottom, 18)
            }
            if let error, info != nil {
                Text("\(storageText(.error)): \(error)")
                    .font(.system(size: 11)).foregroundStyle(SettingsPalette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let message {
                Label(message, systemImage: "checkmark.circle")
                    .font(.system(size: 11)).foregroundStyle(SettingsPalette.success)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(isWorking)
        .task { if !initialInfoProvided { await refreshInfo() } }
        .sheet(isPresented: $showingLocalConfirmation) {
            if let localRequest {
                SettingsCleanupDialog(request: localRequest) { showingLocalConfirmation = false }
                    .environmentObject(settings)
            }
        }
    }

    private var storageCard: some View {
        SettingsCard {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(text("localSize")).font(.system(size: 13, weight: .semibold))
                        Text(text("localRecords")).font(.system(size: 11)).foregroundStyle(Color.meterSecondary)
                    }
                    Spacer(minLength: 0)
                    sizeLabel
                }
                SettingsDivider().padding(.top, 22)
                HStack(spacing: 10) {
                    Text(text("savedRecords")).foregroundStyle(Color.meterSecondary)
                    Spacer(minLength: 0)
                    Text(historyRange).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.8)
                    Button(text("refreshAction")) { Task { await refreshInfo() } }
                        .buttonStyle(SettingsButtonStyle(kind: .link)).disabled(isLoading)
                }.font(.system(size: 10)).frame(minHeight: 16.5).padding(.top, 16)
            }.padding(20)
        }
    }

    private var sizeLabel: some View {
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(formattedSize(includeCount: true)).font(.system(size: 28, weight: .medium))
            Text(formattedSize(includeCount: false)).font(.system(size: 12)).foregroundStyle(Color.meterSecondary)
        }.monospacedDigit().tracking(-0.5).frame(height: 42)
    }

    private var storageStatus: some View {
        let loading = isLoading || (info == nil && error == nil)
        return SettingsCard {
            VStack(spacing: 0) {
                Group {
                    if loading { ProgressView().controlSize(.small) }
                    else { Text(error == nil ? "—" : "!").font(.system(size: 21)) }
                }
                .foregroundStyle(error == nil ? Color.meterSecondary : SettingsPalette.danger)
                .frame(width: 35, height: 35)
                .background(error == nil ? Color.meterPanel : SettingsPalette.danger.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 14)
                Text(text(loading ? "storageLoading" : error == nil ? "storageEmpty" : "storageError"))
                    .font(.system(size: 13, weight: .semibold))
                Text(text(loading ? "storageLoadingDetail" : error == nil ? "storageEmptyDetail" : "storageErrorDetail"))
                    .font(.system(size: 11)).foregroundStyle(Color.meterSecondary).lineSpacing(3)
                    .multilineTextAlignment(.center).padding(.top, 7)
                if error != nil {
                    Button(text("retry")) { Task { await refreshInfo() } }.buttonStyle(SettingsButtonStyle()).padding(.top, 14)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 31).padding(.horizontal, 23)
        }
    }

    private var historyRange: String {
        guard let oldest = info?.oldest, let newest = info?.newest else { return storageText(.empty) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: oldest)) – \(formatter.string(from: newest))"
    }

    private func confirmCleanup() {
        let days = period == 0 ? customDays : period
        let now = Date()
        let cutoff = period == -1 ? now : Calendar.current.date(byAdding: .day, value: -days,
                                                               to: Calendar.current.startOfDay(for: now))
        guard let cutoff else { return }
        let request = SettingsCleanupRequest(
            detail: period == -1 ? text("cleanupAllDetail") : SettingsCopy.cleanupAgeDetail(days, language: settings.language),
            perform: { Task { await clean(before: cutoff) } }
        )
        if let onCleanupRequest { onCleanupRequest(request) }
        else { localRequest = request; showingLocalConfirmation = true }
    }

    private func refreshInfo() async {
        isLoading = true
        defer { isLoading = false }
        do {
            info = try await Task.detached(priority: .utility) { try database.storageInfo() }.value
            error = database.lastError
        } catch { self.error = error.localizedDescription }
    }

    private func clean(before cutoff: Date) async {
        isWorking = true
        error = nil
        message = nil
        defer { isWorking = false }
        do {
            try await Task.detached(priority: .utility) { try database.cleanUsage(before: cutoff) }.value
            await store.refreshLocalUsage()
            await refreshInfo()
            message = storageText(.success)
        } catch { self.error = error.localizedDescription }
    }
}
