import SwiftUI

struct FontSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: UsageStore
    @State private var editingQuota = false
    @State private var contentSection: DashboardSection?

    init(showQuotaInitially: Bool = false, contentSectionInitially: DashboardSection? = nil) {
        _editingQuota = State(initialValue: showQuotaInitially)
        _contentSection = State(initialValue: contentSectionInitially)
    }

    private var activeSection: DashboardSection? {
        editingQuota ? .quota : contentSection
    }

    private func text(_ key: FontL10n.Key) -> String {
        FontL10n.text(key, language: settings.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(text(.scope), selection: $editingQuota) {
                Text(text(.contentCards)).tag(false)
                Text(text(.quotaCard)).tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .accessibilityIdentifier("font-category")

            VStack(alignment: .leading, spacing: 14) {
                if editingQuota {
                    Label(text(.quotaCard), systemImage: "gauge.with.dots.needle.67percent")
                        .font(.meter(size: 12))
                } else {
                    HStack {
                        Text(text(.scope)).font(.meter(size: 12))
                        Spacer()
                        Picker(text(.scope), selection: $contentSection) {
                            Text(text(.allContent)).tag(Optional<DashboardSection>.none)
                            ForEach(MeterFontSettings.contentSections) { section in
                                Text(FontL10n.section(section, language: settings.language))
                                    .tag(Optional(section))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 244)
                        .accessibilityIdentifier("font-content-scope")
                    }
                }

                ForEach(MeterTextRole.allCases) { role in
                    fontControl(role)
                }

                Divider().overlay(Color.meterBorder)

                HStack(spacing: 10) {
                    Text(text(editingQuota ? .quotaHint : .contentHint))
                        .font(.meter(size: 10))
                        .foregroundStyle(Color.meterSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button(text(.reset)) {
                        settings.fontSettings.reset(section: activeSection)
                    }
                    .controlSize(.small)
                    .accessibilityIdentifier("font-reset")
                }

                if !editingQuota, let contentSection {
                    HStack {
                        Spacer()
                        Button(text(.apply)) {
                            settings.fontSettings.applyToContentCards(from: contentSection)
                            self.contentSection = nil
                        }
                        .controlSize(.small)
                        .tint(Color.meterAccent)
                        .accessibilityIdentifier("font-apply-content")
                    }
                }
            }
            .padding(16)
            .background(Color.meterCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.meterBorder))

            VStack(alignment: .leading, spacing: 10) {
                Text(text(.preview))
                    .font(.meter(size: 11))
                    .foregroundStyle(Color.meterSecondary)
                FontCardPreview(section: activeSection, snapshot: previewSnapshot)
                .frame(width: 392)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
    }

    private func fontControl(_ role: MeterTextRole) -> some View {
        let title = FontL10n.role(role, language: settings.language)
        let size = Binding<Double>(
            get: { settings.fontSettings.sizes(for: activeSection)[role] },
            set: { settings.fontSettings.setSize($0, role: role, section: activeSection) }
        )
        return HStack(spacing: 9) {
            Text(title)
                .font(.meter(size: 11.5))
                .frame(width: 102, alignment: .leading)
            Slider(value: size, in: role.range) { Text(title) }
                .labelsHidden()
                .tint(Color.meterAccent)
                .accessibilityIdentifier("font-\(role.rawValue)-slider")
            TextField(title, value: size, format: .number.precision(.fractionLength(0...1)))
                .font(.meter(size: 11))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 50)
                .accessibilityIdentifier("font-\(role.rawValue)-input")
            Text("pt").font(.meter(size: 10)).foregroundStyle(Color.meterSecondary)
            Stepper(title, value: size, in: role.range, step: 0.5)
                .labelsHidden()
                .accessibilityIdentifier("font-\(role.rawValue)-stepper")
        }
        .frame(minHeight: 30)
    }

    private var previewSnapshot: CodexUsageSnapshot {
        store.snapshot ?? (editingQuota ? quotaPreviewSnapshot : CodexUsageSnapshot(
            fetchedAt: Date(), account: nil, rateLimitBuckets: [], usageSummary: nil, dailyUsage: []
        ))
    }

    private var quotaPreviewSnapshot: CodexUsageSnapshot {
        let window = RateLimitWindow(
            id: "font-preview", bucketID: "font-preview", bucketName: "Codex",
            kind: .primary, usedPercent: 77, windowDurationMinutes: 10_080,
            resetsAt: Date().addingTimeInterval(4 * 24 * 60 * 60)
        )
        return CodexUsageSnapshot(
            fetchedAt: Date(), account: nil,
            rateLimitBuckets: [RateLimitBucket(
                id: "font-preview", name: "Codex", planType: nil, hasCredits: nil,
                unlimitedCredits: false, creditBalance: nil, windows: [window]
            )],
            usageSummary: nil, dailyUsage: []
        )
    }
}

struct FontCardPreview: View {
    @EnvironmentObject private var settings: AppSettings
    let section: DashboardSection?
    let snapshot: CodexUsageSnapshot

    var body: some View {
        VStack(spacing: 12) {
            ForEach(section.map { [$0] } ?? settings.dashboardSectionOrder.filter { $0 != .quota }) { section in
                DashboardCard(section: section, snapshot: snapshot)
                    .accessibilityIdentifier("font-preview-\(section.rawValue)")
            }
        }
    }
}
