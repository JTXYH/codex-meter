import AppKit
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    static let shared: UsageStore = {
#if DEBUG
        if ProcessInfo.processInfo.environment["CODEX_METER_DEMO"] == "1" {
            return UsageStore(
                loader: DebugDemoUsageLoader(),
                localUsageLoader: DebugDemoLocalTokenUsageLoader(),
                modelLoader: DebugDemoAccountModelLoader()
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
    @Published private(set) var localTodayModelUsage: [DailyModelTokenUsage] = []
    @Published private(set) var hasLoadedLocalTodayUsage = false

    private let loader: CodexUsageLoading
    private let localUsageLoader: LocalTokenUsageLoading
    private let accountModelLoader: AccountModelUsageLoading
    @Published private var accountModelCache: [AccountModelDateRange: ModelCacheEntry] = [:]
    private var modelRequests: [AccountModelDateRange: UUID] = [:]
    private var selectedModelPeriod: (period: UsagePeriod, date: Date)?

    private struct ModelCacheEntry {
        var list: AccountModelList
        var fetchedAt: Date?
    }
    private let settings: AppSettings
    private var refreshLoop: Task<Void, Never>?
    private var localUsageRefreshLoop: Task<Void, Never>?
    private var isRefreshingLocalUsage = false
    @Published private var localTodayUsageDay: Date?

    init(
        loader: CodexUsageLoading = CodexAppServerClient(),
        localUsageLoader: LocalTokenUsageLoading? = nil,
        settings: AppSettings? = nil,
        modelLoader: AccountModelUsageLoading = CodexAccountModelClient()
    ) {
        self.loader = loader
        self.localUsageLoader = localUsageLoader ?? LocalTokenUsageScanner(scope: .today)
        self.settings = settings ?? .shared
        self.accountModelLoader = modelLoader
    }

    func startIfNeeded() {
        if refreshLoop == nil {
            refreshLoop = automaticRefreshTask(refreshImmediately: snapshot == nil)
        }
        if localUsageRefreshLoop == nil {
            localUsageRefreshLoop = localUsageTask()
        }
    }

    func stop() {
        refreshLoop?.cancel()
        refreshLoop = nil
        localUsageRefreshLoop?.cancel()
        localUsageRefreshLoop = nil
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

    private func localUsageTask() -> Task<Void, Never> {
        Task(priority: .userInitiated) { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.refreshLocalUsage()
                do {
                    try await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    func refreshLocalUsage(at date: Date? = nil) async {
        guard !isRefreshingLocalUsage else { return }
        isRefreshingLocalUsage = true
        defer { isRefreshingLocalUsage = false }
        var now = date ?? Date()
        while true {
            let day = UsageCalendar.calendar.startOfDay(for: now)
            if localTodayUsageDay != day {
                localTodayUsageDay = day
                localTodayUsage = .zero
                localTodayModelUsage = []
                hasLoadedLocalTodayUsage = false
            }
            let usage = await localUsageLoader.usage(at: now)
            // A large first scan can cross midnight. Do not publish the preceding
            // day's amount under the new day's label; rescan at the new boundary.
            if date == nil {
                let finishedAt = Date()
                if UsageCalendar.calendar.startOfDay(for: finishedAt) != day {
                    now = finishedAt
                    continue
                }
            }
            if localTodayUsage != usage.today { localTodayUsage = usage.today }
            let todayModels = usage.dailyModelUsage.filter {
                UsageCalendar.calendar.isDate($0.day, inSameDayAs: now)
            }
            if localTodayModelUsage != todayModels { localTodayModelUsage = todayModels }
            if !hasLoadedLocalTodayUsage { hasLoadedLocalTodayUsage = true }
            return
        }
    }

    func modelUsage(_ period: UsagePeriod, containing date: Date) -> [ModelTokenUsage] {
        guard period == .day,
              let localTodayUsageDay,
              UsageCalendar.calendar.isDate(date, inSameDayAs: localTodayUsageDay)
        else { return [] }
        return ModelUsageBuilder.models(from: localTodayModelUsage, period: .day, containing: date)
    }

    func periodUsage(_ period: UsagePeriod, count: Int, at date: Date = Date()) -> [AccountPeriodUsage] {
        AccountUsageBuilder.periods(
            from: snapshot?.dailyUsage ?? [], period: period, count: count, endingAt: date
        )
    }

    func statisticsUsage(_ period: UsagePeriod, count: Int, at date: Date = Date()) -> [AccountPeriodUsage] {
        // Today's details have their own section; daily statistics start yesterday.
        // Both sources use the same UTC boundary, independent of device time zone.
        if period == .day {
            guard let yesterday = UsageCalendar.calendar.date(byAdding: .day, value: -1, to: date) else { return [] }
            return periodUsage(period, count: count, at: yesterday)
        }
        return periodUsage(period, count: count, at: date)
    }

    var currentMonthTokens: Int64? {
        periodUsage(.month, count: 1).first?.tokens
    }

    func accountModels(for period: UsagePeriod, containing date: Date, at now: Date = Date()) -> AccountModelList {
        guard let range = AccountModelDateRange(period: period, containing: date, now: now) else {
            return AccountModelList(state: .loaded)
        }
        guard snapshot?.account?.type == "chatgpt" else {
            return AccountModelList(state: hasLoadedRemoteSnapshot ? .unsupported : .idle)
        }
        return accountModelCache[range]?.list ?? AccountModelList()
    }

    func loadAccountModels(
        for period: UsagePeriod, containing date: Date, force: Bool = false, at now: Date = Date()
    ) async {
        selectedModelPeriod = (period, date)
        guard let account = snapshot?.account, account.type == "chatgpt",
              let range = AccountModelDateRange(period: period, containing: date, now: now)
        else { return }
        guard modelRequests[range] == nil else { return }
        let previous = accountModelCache[range]
        if !force, let fetchedAt = previous?.fetchedAt,
           previous?.list.state == .loaded, now.timeIntervalSince(fetchedAt) < 120 { return }
        let requestID = UUID()
        let identity = account.usageIdentity
        modelRequests[range] = requestID
        accountModelCache[range] = ModelCacheEntry(
            list: AccountModelList(models: previous?.list.models ?? [], state: .loading,
                                   isStale: previous?.fetchedAt != nil),
            fetchedAt: previous?.fetchedAt
        )
        // The cache owns this read. A view disappearing or selecting another
        // date must not cancel a request that a later selection can share.
        let fetch = Task { try await accountModelLoader.fetchModels(in: range, account: account) }
        do {
            let models = try await fetch.value
            guard snapshot?.account?.usageIdentity == identity, modelRequests[range] == requestID else { return }
            accountModelCache[range] = ModelCacheEntry(list: AccountModelList(models: models, state: .loaded), fetchedAt: now)
        } catch {
            guard snapshot?.account?.usageIdentity == identity, modelRequests[range] == requestID else { return }
            if error is CancellationError {
                accountModelCache[range] = previous
            } else if error as? AccountModelUsageError == .accountChanged {
                accountModelCache[range] = ModelCacheEntry(list: AccountModelList(state: .failed), fetchedAt: nil)
            } else {
                let unavailable = [AccountModelUsageError.unsupported, .authenticationUnavailable]
                    .contains { $0 == error as? AccountModelUsageError }
                accountModelCache[range] = ModelCacheEntry(
                    list: AccountModelList(models: previous?.list.models ?? [],
                                           state: unavailable ? .unsupported : .failed,
                                           isStale: previous?.fetchedAt != nil),
                    fetchedAt: previous?.fetchedAt
                )
            }
        }
        modelRequests[range] = nil
        // Limit retained UI selections without writing account history to local storage.
        if accountModelCache.count > 96 {
            let oldest = accountModelCache.filter { $0.key != range && modelRequests[$0.key] == nil }
                .min { ($0.value.fetchedAt ?? .distantPast) < ($1.value.fetchedAt ?? .distantPast) }?.key
            if let oldest { accountModelCache[oldest] = nil }
        }
    }

    var dashboardSnapshot: CodexUsageSnapshot? {
        snapshot
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if !hasLoadedRemoteSnapshot { state = .loading }
        defer { isRefreshing = false }

        // Today's live details refresh independently of account statistics.
        async let localRefresh: Void = refreshLocalUsage()

        do {
            let updated = try await loader.fetchSnapshot()
            if snapshot?.account?.usageIdentity != updated.account?.usageIdentity {
                accountModelCache.removeAll()
                modelRequests.removeAll()
            }
            snapshot = updated
            hasLoadedRemoteSnapshot = true
            state = .loaded
            if let selectedModelPeriod {
                await loadAccountModels(for: selectedModelPeriod.period, containing: selectedModelPeriod.date, force: true)
            }
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
