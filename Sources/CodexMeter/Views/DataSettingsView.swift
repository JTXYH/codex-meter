import SwiftUI

struct DataSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    private let database: SQLiteStore
    @State private var info: StorageInfo?
    @State private var period = 90
    @State private var customDays = 30
    @State private var pendingCutoff: Date?
    @State private var confirming = false
    @State private var isWorking = false
    @State private var message: String?
    @State private var error: String?

    init(database: SQLiteStore = .shared, initialInfo: StorageInfo? = nil) {
        self.database = database
        _info = State(initialValue: initialInfo)
    }

    private func text(_ key: StorageL10n.Key) -> String {
        StorageL10n.text(key, language: settings.language)
    }
    private func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    private func date(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day().hour().minute().second().locale(settings.language.locale))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(text(.diskSize), systemImage: "externaldrive")
                        .font(.meter(size: 12))
                    Spacer()
                    if let info {
                        Text(size(info.bytes)).font(.meter(size: 24)).monospacedDigit()
                    } else { ProgressView().controlSize(.small) }
                }
                Divider()
                HStack {
                    Text(text(.imageSize))
                    Spacer()
                    Text(info.map { size($0.imageBytes) } ?? "—").monospacedDigit()
                }
                .font(.meter(size: 11))
                .foregroundStyle(Color.meterSecondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text(text(.history)).font(.meter(size: 11))
                    Text(historyRange)
                        .font(.meter(size: 11)).foregroundStyle(Color.meterSecondary)
                }
                Button(text(.refresh)) { Task { await refreshInfo() } }
                    .controlSize(.small)
            }
            .padding(18)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.meterBorder))

            VStack(alignment: .leading, spacing: 14) {
                Label(text(.cleanup), systemImage: "trash")
                    .font(.meter(size: 13))
                Picker(text(.range), selection: $period) {
                    ForEach([7, 30, 90, 180, 365], id: \.self) { days in
                        Text(StorageL10n.olderThan(days, language: settings.language)).tag(days)
                    }
                    Text(L10n.text(.custom, language: settings.language)).tag(0)
                    Text(text(.all)).tag(-1)
                }
                .pickerStyle(.menu)
                if period == 0 {
                    HStack {
                        Text(text(.customDays)).font(.meter(size: 11))
                        TextField("", value: $customDays, format: .number)
                            .textFieldStyle(.roundedBorder).frame(width: 90)
                        Stepper("", value: $customDays, in: 1...36_500).labelsHidden()
                    }
                }
                Text(text(.preservation))
                    .font(.meter(size: 10.5)).foregroundStyle(Color.meterSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(text(.clean), role: .destructive) {
                        let now = Date()
                        pendingCutoff = period == -1 ? now : Calendar.current.date(
                            byAdding: .day, value: -(period == 0 ? customDays : period),
                            to: Calendar.current.startOfDay(for: now))
                        confirming = pendingCutoff != nil
                    }
                    .disabled(info == nil || (period == 0 && !(1...36_500).contains(customDays)))
                    if isWorking { ProgressView().controlSize(.small) }
                }
                Text(text(.checkpoints))
                    .font(.meter(size: 9)).foregroundStyle(Color.meterTertiary)
            }
            .padding(18)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.meterBorder))
            if let error {
                Text("\(text(.error)): \(error)").font(.meter(size: 11)).foregroundStyle(.red)
            } else if let message {
                Label(message, systemImage: "checkmark.circle").font(.meter(size: 11)).foregroundStyle(Color.meterAccent)
            }
        }
        .disabled(isWorking)
        .task { await refreshInfo() }
        .alert(text(.confirm), isPresented: $confirming) {
            Button(text(.cancel), role: .cancel) { pendingCutoff = nil }
            Button(text(.confirm), role: .destructive) {
                guard let cutoff = pendingCutoff else { return }
                Task { await clean(before: cutoff) }
            }
        } message: {
            Text("\(text(.confirmHint))\n\(pendingCutoff.map(date) ?? "")\n\n\(text(.preservation))")
        }
    }

    private var historyRange: String {
        guard let oldest = info?.oldest, let newest = info?.newest else { return text(.empty) }
        let format = Date.FormatStyle.dateTime.year().month().day().locale(settings.language.locale)
        return "\(oldest.formatted(format)) – \(newest.formatted(format))"
    }

    private func refreshInfo() async {
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
            await store.refreshLifetimeUsage()
            await refreshInfo()
            message = text(.success)
        } catch { self.error = error.localizedDescription }
    }
}
