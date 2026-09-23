import AppKit
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var snapshot: CodexUsageSnapshot?
    @Published private(set) var state: State = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var localTodayUsage = LocalTokenUsage.zero
    @Published private(set) var localLifetimeUsage: LocalTokenUsage?
    @Published private(set) var localMonthlyUsage: [MonthlyTokenUsage] = []
    @Published private(set) var localDailyUsage: [PeriodTokenUsage] = []
    @Published private(set) var localHourlyUsage: [PeriodTokenUsage] = []
    @Published private(set) var localStatisticsHour: Date?
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
        if !hasLoadedLocalTodayUsage { hasLoadedLocalTodayUsage = true }
    }

    func refreshLifetimeUsage(at now: Date = Date()) async {
        guard !isRefreshingLifetimeUsage else { return }
        isRefreshingLifetimeUsage = true
        defer { isRefreshingLifetimeUsage = false }
        let usage = await lifetimeUsageLoader.usage(at: now)
        if localLifetimeUsage != usage.lifetime { localLifetimeUsage = usage.lifetime }
        if localMonthlyUsage != usage.monthlyUsage { localMonthlyUsage = usage.monthlyUsage }
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

    func periodUsage(_ period: UsagePeriod, count: Int, at date: Date = Date()) -> [PeriodTokenUsage] {
        let records: [PeriodTokenUsage]
        switch period {
        case .hour: records = localHourlyUsage
        case .day: records = localDailyUsage
        case .month, .year: records = localMonthlyUsage.map { PeriodTokenUsage(start: $0.month, usage: $0.usage) }
        }
        return PeriodUsageBuilder.periods(from: records, period: period, count: count, endingAt: date)
    }

    var localCurrentMonthUsage: LocalTokenUsage? {
        monthlyUsage(count: 1).first?.usage
    }

    var localTodayTokens: Int64 {
        localTodayUsage.totalTokens
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
            state = .loaded
        } catch {
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
