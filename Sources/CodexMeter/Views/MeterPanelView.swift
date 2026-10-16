import AppKit
import SwiftUI

/// Used by the panel, settings previews and screenshot verification.
struct DashboardCard: View {
    let section: DashboardSection
    let snapshot: CodexUsageSnapshot
    var body: some View { content.meterTypography(for: section) }

    @ViewBuilder private var content: some View {
        switch section {
        case .quota: HeroUsageCard(snapshot: snapshot)
        case .tokenActivity: TokenActivityCard()
        case .activityOverview: ActivityOverviewCard(snapshot: snapshot)
        case .monthlyUsage: MonthlyUsageCard()
        case .usageHeatmap: UsageHeatmapCard(snapshot: snapshot)
        case .usageSummary: UsageSummaryCard(snapshot: snapshot)
        case .creditsBalance: CreditsBalanceCard(snapshot: snapshot)
        case .resetCredits: ResetCreditsCard(snapshot: snapshot)
        }
    }
}

struct MeterPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var presentation = PanelPresentationState()
    @State private var isEmailRevealed = false
    private var theme: PanelTheme { settings.panelTheme }
    private var allHidden: Bool { settings.dashboardSectionOrder.allSatisfy { !settings.isDashboardSectionVisible($0) } }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    panelHeader
                        .padding(.horizontal, 15)
                        .frame(height: 47)
                        .background(Color.meterCard)
                    PanelRule()
                    if store.hasLoadedRemoteSnapshot, store.refreshErrorMessage != nil { staleBanner }
                    if allHidden {
                        modulesEmptyState
                    } else {
                        PanelContentView(isPresented: presentation.isPresented)
                    }
                }
            }
            .background(Color.meterCard)
            PanelRule()
            footer.frame(height: 39).background(Color.meterCard)
        }
        .frame(width: 418, height: 698)
        .padding(1)
        .background(Color.meterPanel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.meterBorder, lineWidth: 1).allowsHitTesting(false) }
        .scaleEffect(reduceMotion || presentation.isPresented ? 1 : 0.985,
                     anchor: UnitPoint(x: presentation.anchorX, y: 0))
        .animation(reduceMotion ? nil : .easeOut(duration: presentation.isPresented ? 0.22 : 0.14), value: presentation.isPresented)
        .foregroundStyle(Color.meterPrimary)
        .environment(\.meterTheme, theme)
        .meterTypography()
        .focusEffectDisabled()
        .onAppear { store.startIfNeeded() }
        .onDisappear { isEmailRevealed = false }
        .onChange(of: store.snapshot?.account?.email) { _, _ in isEmailRevealed = false }
    }

    private var panelHeader: some View {
        HStack(spacing: 9) {
            CodexIconView(size: 26)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text("Codex Meter").meterText(.title, size: 12, weight: .semibold)
                    if let plan = store.snapshot?.account?.displayPlan {
                        Text(plan.uppercased()).meterText(.detail, size: 8, weight: .medium)
                            .frame(minHeight: 12)
                            .tracking(0.5).foregroundStyle(theme.accent)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 4))
                    }
                }.frame(minHeight: 18)
                accountSubtitle.frame(minHeight: 13)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button { Task { await store.refresh() } } label: {
                PanelRotatingMark(isRotating: store.isRefreshing && store.hasLoadedRemoteSnapshot) {
                    PanelToolbarIcon(kind: .refresh)
                }
                .frame(width: 26, height: 26)
            }
            .buttonStyle(PanelToolbarButtonStyle(hoverColor: .meterPanel)).disabled(store.isRefreshing)
            .help(L10n.text(.refreshQuota, language: settings.language))
            .accessibilityLabel(L10n.text(.refreshQuota, language: settings.language))
            .accessibilityIdentifier("panel-refresh")
        }
    }

    @ViewBuilder private var accountSubtitle: some View {
        if let email = store.snapshot?.account?.email, !email.isEmpty {
            Button { isEmailRevealed.toggle() } label: {
                Text(isEmailRevealed ? email : EmailPrivacy.masked(email))
                    .meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
                    .lineLimit(1).truncationMode(.middle).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.text(isEmailRevealed ? .hideEmail : .showEmail, language: settings.language))
            .accessibilityLabel(L10n.text(isEmailRevealed ? .hideEmail : .showEmail, language: settings.language))
            .accessibilityValue(isEmailRevealed ? email : EmailPrivacy.masked(email))
        } else {
            Text(RedesignL10n.text(accountStatusKey, language: settings.language))
                .meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
        }
    }

    private var accountStatusKey: RedesignL10n.Key {
        if !store.hasLoadedRemoteSnapshot, case .failed(let message) = store.state {
            return message == L10n.errorMessage(for: .codexNotFound, language: settings.language)
                ? .codexMissing : .accountFailed
        }
        if store.hasLoadedRemoteSnapshot, store.snapshot?.account == nil { return .waitingLogin }
        return .waitingAccount
    }

    private var footer: some View {
        HStack {
            Button { AppActions.openSettings() } label: {
                PanelToolbarIcon(kind: .settings)
                    .padding(.horizontal, 7).padding(.vertical, 4).contentShape(Rectangle())
                    .accessibilityHidden(true)
            }.buttonStyle(PanelToolbarButtonStyle(hoverColor: theme.accentSoft))
                .help(L10n.text(.settings, language: settings.language))
                .accessibilityLabel(L10n.text(.settings, language: settings.language))
                .accessibilityIdentifier("panel-settings")
            Spacer()
            Button { AppActions.quit() } label: {
                PanelToolbarIcon(kind: .power, size: 17)
                    .padding(.horizontal, 7).padding(.vertical, 4).contentShape(Rectangle())
                    .accessibilityHidden(true)
            }.buttonStyle(PanelToolbarButtonStyle(hoverColor: theme.accentSoft)).help(L10n.text(.quit, language: settings.language))
                .accessibilityLabel(L10n.text(.quit, language: settings.language))
        }
        .foregroundStyle(Color.meterSecondary).padding(.horizontal, 8)
        .overlay {
            Text(syncText).meterText(.detail, size: 9).foregroundStyle(Color.meterTertiary)
                .lineLimit(1).allowsHitTesting(false)
        }
    }

    private var syncText: String {
        if store.isRefreshing {
            return RedesignL10n.text(store.hasLoadedRemoteSnapshot ? .refreshing : .readInProgress, language: settings.language)
        }
        if case .failed(let message) = store.state {
            let key: RedesignL10n.Key = store.hasLoadedRemoteSnapshot ? .updateFailed
                : message == L10n.errorMessage(for: .codexNotFound, language: settings.language) ? .waitingCodex : .readFailed
            return RedesignL10n.text(key, language: settings.language)
        }
        if store.hasLoadedRemoteSnapshot, store.snapshot?.account == nil {
            return RedesignL10n.text(.waitingLogin, language: settings.language)
        }
        if let date = store.snapshot?.fetchedAt {
            if Date().timeIntervalSince(date) < 60 { return RedesignL10n.text(.justUpdated, language: settings.language) }
            return L10n.updatedAt(date, language: settings.language)
        }
        return RedesignL10n.text(.waitingAccount, language: settings.language)
    }

    private var staleBanner: some View {
        HStack {
            Text(RedesignL10n.text(.stale, language: settings.language))
            Spacer(minLength: 6)
            Button(L10n.text(.retry, language: settings.language)) { Task { await store.refresh() } }.buttonStyle(.plain)
        }
        .meterText(.detail, size: 10).foregroundStyle(Color.meterDanger).frame(minHeight: 15)
        .padding(.horizontal, 10).padding(.vertical, 9)
        .background(Color.meterDanger.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 10).help(store.refreshErrorMessage ?? "")
    }

    private var modulesEmptyState: some View {
        VStack(spacing: 12) {
            Text("☷").font(.system(size: 29))
                .frame(width: 56, height: 56).foregroundStyle(theme.accent)
                .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 16)).padding(.bottom, 5)
            Text(RedesignL10n.text(.selectModules, language: settings.language)).meterText(.title, size: 17, weight: .medium).frame(minHeight: 25.5)
            Text(RedesignL10n.text(.selectModulesHint, language: settings.language)).meterText(.detail, size: 12)
                .foregroundStyle(Color.meterSecondary).lineSpacing(7.2).padding(.vertical, 3.6).frame(maxWidth: 260)
            Button(RedesignL10n.text(.configureLayout, language: settings.language)) { SettingsWindowController.shared.show(section: .display) }
                .buttonStyle(PanelPrimaryActionStyle())
        }.frame(maxWidth: .infinity).frame(height: 475).multilineTextAlignment(.center)
    }
}

private struct PanelToolbarButtonStyle: ButtonStyle {
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    let hoverColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered && isEnabled ? hoverColor : .clear, in: RoundedRectangle(cornerRadius: 5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovered = $0 }
    }
}

struct PanelEmptyState: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    let state: UsageStore.State
    var requiresLogin = false
    let retry: () -> Void
    private var isLoading: Bool { !requiresLogin && (state == .loading || state == .idle) }
    private var missingCodex: Bool {
        guard case let .failed(message) = state else { return false }
        return message == L10n.errorMessage(for: .codexNotFound, language: settings.language)
    }
    private var titleKey: RedesignL10n.Key {
        isLoading ? .readingAccount : missingCodex ? .codexMissing : requiresLogin ? .signIn : .accountFailed
    }
    private var detailKey: RedesignL10n.Key {
        isLoading ? .readingAccountHint : missingCodex ? .codexMissingHint : requiresLogin ? .signInHint : .accountFailedHint
    }
    private var symbolName: String {
        isLoading ? "clock" : missingCodex ? "app.dashed" : requiresLogin ? "person.crop.circle" : "exclamationmark"
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbolName)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Color.meterSecondary)
                .frame(width: 50, height: 50)
                .background(Color.meterPanel, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(RedesignL10n.text(titleKey, language: settings.language))
                    .meterText(.title, size: 14, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
                Text(RedesignL10n.text(detailKey, language: settings.language))
                    .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                if !isLoading {
                    Button(action: retry) {
                        Text(RedesignL10n.text(missingCodex || requiresLogin ? .detectAgain : .readAgain, language: settings.language))
                            .meterText(.title, size: 10)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(theme.accent)
                            .background(theme.accentSoft, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .help(errorDetail)
    }
    private var errorDetail: String {
        if case .failed(let message) = state { return message }
        return ""
    }
}

private struct PanelPrimaryActionStyle: ButtonStyle {
    @Environment(\.meterTheme) private var theme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.meterText(.title, size: 12).frame(minHeight: 18)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .foregroundStyle(Color.meterCard)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct PanelRotatingMark<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isRotating: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if isRotating && !reduceMotion {
                // Removing this branch stops frame updates as soon as the request ends.
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)
                    content().rotationEffect(.degrees(turn * 360))
                }
            } else {
                content()
            }
        }
        .transaction { $0.animation = nil }
    }
}
