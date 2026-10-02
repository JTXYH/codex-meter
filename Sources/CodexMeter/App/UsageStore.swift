import AppKit
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared: UsageStore = {
#if DEBUG
        if ProcessInfo.processInfo.environment["CODEX_METER_DEMO"] == "1" {
            return UsageStore(
                loader: DebugDemoUsageLoader(),
                localUsageLoader: DebugDemoLocalTokenUsageLoader()
            )
        }
#endif
        return UsageStore()
    }()

    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var hasLoadedRemoteSnapshot = false
    @Published private(set) var state: State = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var localTodayUsage = LocalTokenUsage.zero
    @Published private(set) var localLifetimeUsage: LocalTokenUsage?
    @Published private(set) var localMonthlyUsage: [MonthlyTokenUsage] = []
    @Published private(set) var localDailyModelUsage: [DailyModelTokenUsage] = []
    @Published private(set) var localHourlyModelUsage: [HourlyModelTokenUsage] = []
    @Published private(set) var localDailyUsage: [PeriodTokenUsage] = []
    @Published private(set) var localHourlyUsage: [PeriodTokenUsage] = []
    @Published private(set) var localStatisticsHour: Date?
    @Published private(set) var localTodayQuotaUsage: [TodayQuotaUsage] = []
    @Published private(set) var localTodayQuotaReadings: [LocalQuotaReading] = []
    @Published private(set) var localHistoricalQuotaReadings: [LocalQuotaReading] = []
    @Published private(set) var hasLoadedLocalTodayUsage = false
    @Published private(set) var hasLoadedLocalLifetimeUsage = false

    private let loader: CodexUsageLoading
    private let localUsageLoader: LocalTokenUsageLoading
    private let lifetimeUsageLoader: LocalTokenUsageLoading
    private let settings: AppSettings
    private var refreshLoop: Task<Void, Never>?
    private var localUsageRefreshLoop: Task<Void, Never>?
    private var lifetimeUsageRefreshLoop: Task<Void, Never>?
    private var isRefreshingLocalUsage = false
    private var isRefreshingLifetimeUsage = false

    init(
        loader: CodexUsageLoading = CodexAppServerClient(),
        localUsageLoader: LocalTokenUsageLoading? = nil,
        lifetimeUsageLoader: LocalTokenUsageLoading? = nil,
        settings: AppSettings? = nil
    ) {
        self.loader = loader
        // Separate actors let today's scan finish while the history scan is still running.
        self.localUsageLoader = localUsageLoader ?? LocalTokenUsageScanner(scope: .today)
        self.lifetimeUsageLoader = lifetimeUsageLoader ?? localUsageLoader
            ?? LocalTokenUsageScanner(scope: .lifetime)
        self.settings = settings ?? .shared
    }

    func startIfNeeded() {
        if refreshLoop == nil {
            refreshLoop = automaticRefreshTask(refreshImmediately: snapshot == nil)
        }
        if localUsageRefreshLoop == nil {
            localUsageRefreshLoop = localUsageTask()
        }
        if lifetimeUsageRefreshLoop == nil {
            lifetimeUsageRefreshLoop = localUsageTask(lifetime: true)
        }
    }

    func rescheduleAutomaticRefresh() {
        guard refreshLoop != nil else { return }
        refreshLoop?.cancel()
        refreshLoop = automaticRefreshTask(refreshImmediately: false)
    }

    private func automaticRefreshTask(refreshImmediately: Bool) -> Task<Void, Never> {
        Task { [weak self] in
            if refreshImmediately {
                await self?.refresh()
            }

            while !Task.isCancelled {
                guard let interval = self?.settings.automaticRefreshIntervalNanoseconds else { return }
                do {
                    try await Task.sleep(nanoseconds: interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    private func localUsageTask(lifetime: Bool = false) -> Task<Void, Never> {
        Task(priority: lifetime ? .utility : .userInitiated) { [weak self] in
            while !Task.isCancelled {
                if lifetime {
                    await self?.refreshLifetimeUsage()
                } else {
                    await self?.refreshLocalUsage()
                }
                do {
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    func refreshLocalUsage(at now: Date = Date()) async {
        guard !isRefreshingLocalUsage else { return }
        isRefreshingLocalUsage = true
        defer { isRefreshingLocalUsage = false }
        let usage = await localUsageLoader.usage(at: now)
        if localTodayUsage != usage.today { localTodayUsage = usage.today }
        if localTodayQuotaUsage != usage.todayQuotaUsage { localTodayQuotaUsage = usage.todayQuotaUsage }
        if localTodayQuotaReadings != usage.quotaReadings { localTodayQuotaReadings = usage.quotaReadings }
        if !hasLoadedLocalTodayUsage { hasLoadedLocalTodayUsage = true }
    }

    func refreshLifetimeUsage(at now: Date = Date()) async {
        guard !isRefreshingLifetimeUsage else { return }
        isRefreshingLifetimeUsage = true
        defer { isRefreshingLifetimeUsage = false }
        let usage = await lifetimeUsageLoader.usage(at: now)
        if localLifetimeUsage != usage.lifetime { localLifetimeUsage = usage.lifetime }
        if localMonthlyUsage != usage.monthlyUsage { localMonthlyUsage = usage.monthlyUsage }
        if localDailyModelUsage != usage.dailyModelUsage { localDailyModelUsage = usage.dailyModelUsage }
        if localHourlyModelUsage != usage.hourlyModelUsage { localHourlyModelUsage = usage.hourlyModelUsage }
        if localHistoricalQuotaReadings != usage.quotaReadings { localHistoricalQuotaReadings = usage.quotaReadings }
        if localDailyUsage != usage.dailyUsage { localDailyUsage = usage.dailyUsage }
        if localHourlyUsage != usage.hourlyUsage { localHourlyUsage = usage.hourlyUsage }
        // Advance the visible time windows even when no new token records arrive.
        let hour = Calendar.current.dateInterval(of: .hour, for: now)?.start
        if localStatisticsHour != hour { localStatisticsHour = hour }
        if !hasLoadedLocalLifetimeUsage { hasLoadedLocalLifetimeUsage = true }
    }

    func monthlyUsage(count: Int, at date: Date = Date()) -> [MonthlyTokenUsage] {
        MonthlyUsageBuilder.months(from: localMonthlyUsage, count: count, endingAt: date)
    }

    func modelUsage(_ period: UsagePeriod, containing date: Date) -> [ModelTokenUsage] {
        if period == .hour {
            return ModelUsageBuilder.models(from: localHourlyModelUsage, containing: date)
        }
        return ModelUsageBuilder.models(from: localDailyModelUsage, period: period, containing: date)
    }

    func periodUsage(_ period: UsagePeriod, count: Int, at date: Date = Date()) -> [PeriodTokenUsage] {
        let records: [PeriodTokenUsage]
        switch period {
        case .hour: records = localHourlyUsage
        case .day, .week: records = localDailyUsage
        case .month, .year: records = localMonthlyUsage.map { PeriodTokenUsage(start: $0.month, usage: $0.usage) }
        }
        return PeriodUsageBuilder.periods(from: records, period: period, count: count, endingAt: date)
    }

    func statisticsUsage(_ period: UsagePeriod, count: Int, at date: Date = Date()) -> [PeriodTokenUsage] {
        // Today's details have their own section; daily statistics start yesterday.
        // Calendar arithmetic preserves the day boundary across daylight-saving changes.
        if period == .day {
            guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return [] }
            return periodUsage(period, count: count, at: yesterday)
        }
        return periodUsage(period, count: count, at: date)
    }

    var localCurrentMonthUsage: LocalTokenUsage? {
        monthlyUsage(count: 1).first?.usage
    }

    var localTodayTokens: Int64 {
        localTodayUsage.totalTokens
    }

    var localTodayQuotaPercent: Double? {
        guard hasLoadedLocalTodayUsage, localTodayTokens > 0 else { return nil }
        return quotaPercent(for: .day, containing: Date())
    }

    func quotaPercent(for period: UsagePeriod, containing date: Date) -> Double? {
        guard let snapshot,
              let window = snapshot.quotaCardPrimaryWindow,
              let duration = window.windowDurationMinutes,
              let resetsAt = window.resetsAt,
              let interval = period.interval(containing: date)
        else { return nil }
        if localHistoricalQuotaReadings.isEmpty && localTodayQuotaReadings.isEmpty {
            guard period == .day, Calendar.current.isDateInToday(date) else { return nil }
            return localTodayQuotaUsage.first {
                $0.bucketID == window.bucketID && $0.windowDurationMinutes == duration
            }?.usedPercentagePoints
        }
        var readings = localHistoricalQuotaReadings + localTodayQuotaReadings
        if snapshot.fetchedAt <= Date() {
            readings.append(LocalQuotaReading(
                date: snapshot.fetchedAt,
                bucketID: window.bucketID,
                windowDurationMinutes: duration,
                resetsAt: resetsAt,
                usedPercent: window.usedPercent
            ))
        }
        return QuotaUsageBuilder.percentagePoints(
            from: readings,
            bucketID: window.bucketID,
            windowDurationMinutes: duration,
            in: interval
        )
    }

    var dashboardSnapshot: CodexUsageSnapshot? {
        guard let snapshot else { return nil }
        guard !hasLoadedRemoteSnapshot else { return snapshot }
        let dailyUsage = localDailyUsage.compactMap { record -> DailyTokenUsage? in
            guard let usage = record.usage else { return nil }
            return DailyTokenUsage(date: record.start, tokens: usage.totalTokens)
        }
        .sorted { $0.date < $1.date }
        return CodexUsageSnapshot(
            fetchedAt: snapshot.fetchedAt,
            account: snapshot.account,
            rateLimitBuckets: snapshot.rateLimitBuckets,
            usageSummary: snapshot.usageSummary,
            dailyUsage: dailyUsage
        )
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if snapshot == nil { state = .loading }
        defer { isRefreshing = false }

        // The first historical scan must not delay showing the account and quota.
        async let localRefresh: Void = refreshLocalUsage()
        Task(priority: .utility) { [weak self] in
            await self?.refreshLifetimeUsage()
        }

        do {
            snapshot = try await loader.fetchSnapshot()
            hasLoadedRemoteSnapshot = true
            state = .loaded
        } catch {
            if snapshot == nil {
                snapshot = CodexUsageSnapshot(
                    fetchedAt: Date(),
                    account: nil,
                    rateLimitBuckets: [],
                    usageSummary: nil,
                    dailyUsage: []
                )
            }
            if let codexError = error as? CodexMeterError {
                state = .failed(L10n.errorMessage(for: codexError, language: settings.language))
            } else {
                state = .failed(error.localizedDescription)
            }
        }
        await localRefresh
    }

    var menuBarRemainingPercent: Double? {
        guard let window = snapshot?.quotaCardPrimaryWindow,
              window.usedPercent.isFinite
        else { return nil }
        return window.remainingPercent
    }

    var menuBarText: String {
        guard let percent = menuBarRemainingPercent else { return "--" }
        return "\(Int(percent.rounded()))%"
    }

    var refreshErrorMessage: String? {
        guard snapshot != nil, case let .failed(message) = state else { return nil }
        return message
    }
}

enum AppActions {
    @MainActor
    static func openSettings() {
        SettingsWindowController.shared.show()
    }

    @MainActor
    static func quit() {
        NSApplication.shared.terminate(nil)
    }
}
