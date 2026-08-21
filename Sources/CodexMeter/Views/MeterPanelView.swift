import AppKit
import SwiftUI

struct MeterPanelView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var quotaBackgrounds: QuotaBackgroundStore
    @State private var isEmailRevealed = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.meterPanelTop,
                    Color.meterPanel,
                    Color.meterPanelBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                panelHeader
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().overlay(Color.meterBorder)

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if let snapshot = store.snapshot {
                            VStack(spacing: 12) {
                                HeroUsageCard(snapshot: snapshot)
                                TokenActivityCard(snapshot: snapshot)
                                UsageHeatmapCard(snapshot: snapshot)
                                UsageSummaryCard(snapshot: snapshot)
                            }
                        } else {
                            EmptyStateCard(state: store.state) {
                                Task { await store.refresh() }
                            }
                        }
                    }
                    .padding(14)
                }

                footer
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.meterFooter)
                    .overlay(alignment: .top) {
                        Divider().overlay(Color.meterBorder)
                    }
            }
        }
        .frame(width: 420, height: 700)
        .foregroundStyle(Color.meterPrimary)
        .onAppear {
            store.startIfNeeded()
        }
        .onDisappear {
            isEmailRevealed = false
        }
        .onChange(of: store.snapshot?.account?.email) { _, _ in
            isEmailRevealed = false
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 11) {
            panelIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Codex Meter")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    if let plan = store.snapshot?.account?.displayPlan {
                        Text(plan.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.meterAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.meterAccent.opacity(0.11), in: Capsule())
                    }
                }
                accountSubtitle
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.meterPrimary)
                .background(Color.meterControl, in: Circle())
                .help(L10n.text(.refreshQuota, language: settings.language))
            }
        }
    }

    @ViewBuilder
    private var panelIcon: some View {
        if let remainingPercent = store.snapshot?.featuredWindow?.remainingPercent,
           let image = quotaBackgrounds.selectedPanelIcon(for: remainingPercent) {
            Image(nsImage: image)
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityLabel("Codex")
        } else {
            CodexIconView(size: 36)
        }
    }

    @ViewBuilder
    private var accountSubtitle: some View {
        if let email = store.snapshot?.account?.email,
           !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button {
                isEmailRevealed.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(isEmailRevealed ? email : EmailPrivacy.masked(email))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Image(systemName: isEmailRevealed ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .regular, design: .rounded))
            .foregroundStyle(Color.meterSecondary)
            .frame(maxWidth: 238, alignment: .leading)
            .help(
                L10n.text(
                    isEmailRevealed ? .hideEmail : .showEmail,
                    language: settings.language
                )
            )
            .accessibilityLabel(
                isEmailRevealed
                    ? "\(email), \(L10n.text(.hideEmail, language: settings.language))"
                    : L10n.text(.showEmail, language: settings.language)
            )
        } else {
            Text(L10n.text(.currentMacServer, language: settings.language))
                .font(.system(size: 10.5, weight: .regular, design: .rounded))
                .foregroundStyle(Color.meterSecondary)
                .lineLimit(1)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                AppActions.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 38, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.meterPrimary)
            .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .help(L10n.text(.settings, language: settings.language))

            if let message = store.refreshErrorMessage {
                Label(
                    L10n.text(.loadFailed, language: settings.language),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .help(message)
                .accessibilityValue(message)
            }

            Spacer()

            Button {
                AppActions.quit()
            } label: {
                Image(systemName: "power")
                    .frame(width: 38, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.meterPrimary)
            .background(Color.meterControl, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .help(L10n.text(.quit, language: settings.language))
        }
    }
}

private struct EmptyStateCard: View {
    @EnvironmentObject private var settings: AppSettings

    let state: UsageStore.State
    let retry: () -> Void

    var body: some View {
        PanelCard {
            VStack(spacing: 15) {
                if state == .loading || state == .idle {
                    ProgressView()
                        .controlSize(.large)
                    Text(L10n.text(.loadingQuota, language: settings.language))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Text(L10n.text(.loadingDetail, language: settings.language))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                } else if case let .failed(message) = state {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(L10n.text(.loadFailed, language: settings.language))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(message)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.meterSecondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                    Button(L10n.text(.retry, language: settings.language), action: retry)
                        .buttonStyle(.borderedProminent)
                        .tint(.meterAccent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        }
    }
}
