import SwiftUI

/// Remote and local data finish independently. Skeletons never stand in for a zero value.
struct PanelContentView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.meterTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isPresented = true
    @State private var isSlow = false

    private var remoteReady: Bool { store.hasLoadedRemoteSnapshot && store.snapshot?.account != nil }
    private var requiresLogin: Bool { store.hasLoadedRemoteSnapshot && store.snapshot?.account == nil }

    private var hasAccountError: Bool {
        if remoteReady { return false }
        if case .failed = store.state { return true }
        return requiresLogin
    }
    private var isWaiting: Bool { !remoteReady && !hasAccountError }

    private var sections: [DashboardSection] {
        settings.dashboardSectionOrder.filter(settings.isDashboardSectionVisible)
    }
    private let emptySnapshot = CodexUsageSnapshot(fetchedAt: .distantPast, account: nil,
        rateLimitBuckets: [], usageSummary: nil, dailyUsage: [])

    var body: some View {
        VStack(spacing: 0) {
            if hasAccountError, !sections.contains(.quota) {
                PanelCard { accountError }
                    .meterTypography(for: .quota)
                    .environment(\.meterCardHasBottomBorder, !sections.isEmpty)
            }
            ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                Group {
                    if section == .tokenActivity, store.hasLoadedLocalTodayUsage {
                        TokenActivityCard()
                    } else if section != .tokenActivity, remoteReady, let snapshot = store.dashboardSnapshot {
                        DashboardCard(section: section, snapshot: snapshot)
                    } else {
                        placeholder(section)
                    }
                }
                .meterTypography(for: section)
                .environment(\.meterCardHasBottomBorder, section != sections.last)
                .modifier(PanelModuleEntrance(isPresented: isPresented, index: index))
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: store.hasLoadedLocalTodayUsage)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: remoteReady)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: settings.dashboardSectionOrder)
        .task(id: isWaiting) {
            isSlow = false
            guard isWaiting else { return }
            do { try await Task.sleep(for: .seconds(3)); isSlow = true }
            catch { return }
        }
    }

    @ViewBuilder private func placeholder(_ section: DashboardSection) -> some View {
        switch section {
        case .quota: quota
        case .tokenActivity: today
        case .monthlyUsage: history
        case .resetCredits:
            if hasAccountError {
                ResetCreditsCard(snapshot: emptySnapshot)
            } else {
                PanelCard {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(ResetCreditsL10n.text(.title, language: settings.language))
                                .meterText(.title, size: 14, weight: .semibold)
                            Spacer()
                            SkeletonBar(width: 48, height: 18)
                        }.frame(minHeight: 24).padding(.bottom, 12)
                        SkeletonBar(width: 190, height: 12).frame(height: 18).padding(.bottom, 8)
                        ForEach(0..<2) { _ in
                            HStack {
                                SkeletonBar(width: 102, height: 13)
                                Spacer()
                                SkeletonBar(width: 62, height: 13)
                            }.frame(height: 48)
                        }
                    }.padding(.top, 3).padding(.bottom, -1)
                }.accessibilityLabel(ResetCreditsL10n.text(.title, language: settings.language) + " · " + text(.readInProgress))
            }
        default:
            PanelCard {
                VStack(alignment: .leading, spacing: 20) {
                    SkeletonBar(width: 90, height: 12)
                    HStack(spacing: 24) {
                        ForEach(0..<3) { _ in SkeletonBar(width: 80, height: 24) }
                    }
                }.frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
            }.accessibilityLabel(text(.readInProgress))
        }
    }

    private var quota: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    PanelCardHeading(title: text(.currentQuota))
                    if !hasAccountError { SkeletonBar(width: 25, height: 7) }
                }
                if hasAccountError {
                    accountError.frame(maxHeight: .infinity)
                } else {
                    HStack(spacing: theme.isInstrument ? 16 : 20) {
                        OrbitLoadingMark(isAnimating: isPresented)
                            .frame(width: theme.isInstrument ? 78 : 92, height: theme.isInstrument ? 78 : 92)
                            .frame(width: theme.isInstrument ? 85 : 112)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(text(.readingAccount)).meterText(.title, size: 14, weight: .semibold)
                            Text(isSlow ? PanelLoadingL10n.slow(settings.language) : PanelLoadingL10n.hint(settings.language))
                                .meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
                                .fixedSize(horizontal: false, vertical: true).lineSpacing(3)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }.frame(height: 183)
        }.accessibilityElement(children: .combine)
    }

    private var accountError: some View {
        PanelEmptyState(state: store.state, requiresLogin: requiresLogin) {
            Task { await store.refresh() }
        }
    }

    private var today: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(L10n.text(.todayDetails, language: settings.language)).meterText(.title, size: 13, weight: .semibold)
                    UsageDayIndicator(date: Date())
                    Spacer()
                    SkeletonBar(width: 49, height: 7)
                }.frame(minHeight: 19.5).padding(.bottom, 20)
                Text(text(.todayTokens)).meterText(.detail, size: 11).foregroundStyle(Color.meterSecondary).padding(.bottom, 12)
                SkeletonBar(width: 116, height: 29, strong: true).padding(.bottom, 20)
                PanelRule()
                HStack(spacing: 0) {
                    metric(.input)
                    Rectangle().fill(Color.meterBorder).frame(width: 1, height: 41)
                    metric(.output).padding(.leading, 14)
                    Rectangle().fill(Color.meterBorder).frame(width: 1, height: 41)
                    metric(.cached).padding(.leading, 14)
                }.padding(.vertical, 15)
                PanelRule()
                HStack {
                    Text(text(.modelDetails)).meterText(.title, size: 11)
                    Spacer()
                    SkeletonBar(width: 24, height: 8)
                }.padding(.top, 15)
            }.frame(minHeight: 243, alignment: .top)
        }.accessibilityElement(children: .ignore).accessibilityLabel(L10n.text(.todayDetails, language: settings.language) + " · " + text(.readInProgress))
    }

    private func metric(_ key: RedesignL10n.Key) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text(key)).meterText(.detail, size: 10).foregroundStyle(Color.meterSecondary)
            SkeletonBar(width: 54, height: 14)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var history: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(L10n.text(.monthlyUsage, language: settings.language)).meterText(.title, size: 13, weight: .semibold)
                    UsageDayIndicator(date: Date(), period: settings.usageStatisticsPeriod)
                    Spacer()
                    Text(UsageStatisticsL10n.range(settings.usageStatisticsRange(for: settings.usageStatisticsPeriod),
                        period: settings.usageStatisticsPeriod, language: settings.language))
                        .meterText(.detail, size: 9).foregroundStyle(Color.meterSecondary)
                }.frame(minHeight: 19.5).padding(.bottom, 20)
                HStack(spacing: 3) {
                    ForEach(UsagePeriod.statisticsPeriods) { period in
                        Text(UsageStatisticsL10n.period(period, language: settings.language))
                            .meterText(.detail, size: 10)
                            .foregroundStyle(period == settings.usageStatisticsPeriod ? theme.accent : Color.meterSecondary)
                            .frame(maxWidth: .infinity).frame(height: 29)
                            .background(period == settings.usageStatisticsPeriod ? Color.meterCard : .clear, in: RoundedRectangle(cornerRadius: 5))
                    }
                }.padding(3).background(Color.meterPanel, in: RoundedRectangle(cornerRadius: 7)).padding(.bottom, 18)
                SkeletonBar(width: 55, height: 10).padding(.bottom, 14)
                SkeletonBar(width: 124, height: 29, strong: true)
            }.frame(height: 176, alignment: .top)
        }.accessibilityElement(children: .ignore).accessibilityLabel(L10n.text(.monthlyUsage, language: settings.language) + " · " + text(.readInProgress))
    }

    private func text(_ key: RedesignL10n.Key) -> String { RedesignL10n.text(key, language: settings.language) }
}

private struct SkeletonBar: View {
    @Environment(\.meterTheme) private var theme
    let width: CGFloat
    let height: CGFloat
    var strong = false
    var body: some View {
        RoundedRectangle(cornerRadius: height > 20 ? 5 : 4)
            .fill(theme.accent.opacity(strong ? 0.14 : 0.06))
            .frame(width: width, height: height).accessibilityHidden(true)
    }
}

private enum PanelLoadingL10n {
    static func hint(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: return "额度与用量将在这里显示。"
        case .traditionalChinese: return "額度與用量將在這裡顯示。"
        case .english: return "Your quota and usage will appear here."
        case .japanese: return "割り当てと使用量がここに表示されます。"
        case .korean: return "할당량과 사용량이 여기에 표시됩니다."
        case .spanish: return "Tu cuota y uso aparecerán aquí."
        }
    }
    static func slow(_ language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese: return "仍在读取，已有数据会先显示。"
        case .traditionalChinese: return "仍在讀取，已有資料會先顯示。"
        case .english: return "Still reading. Available data appears as it arrives."
        case .japanese: return "読み込み中です。取得したデータから表示します。"
        case .korean: return "읽는 중입니다. 준비된 데이터부터 표시합니다."
        case .spanish: return "Seguimos leyendo. Los datos aparecerán a medida que lleguen."
        }
    }
}
