import AppKit
import Foundation
import Testing
@testable import CodexMeter

struct AccountModelUsageTests {
    @Test
    func missingOrNonFileCredentialConfigurationNeverAuthorizesWorkspaceInference() {
        #expect(CodexResponseParser.usesFileCredentialStore(
            Data(#"{"result":{"config":{"cli_auth_credentials_store":"file"}}}"#.utf8)))
        for value in [#"{"result":{"config":{}}}"#,
                      #"{"result":{"config":{"cli_auth_credentials_store":"keyring"}}}"#,
                      #"{"result":{"config":{"cli_auth_credentials_store":"auto"}}}"#,
                      #"{"result":{"config":{"cli_auth_credentials_store":"ephemeral"}}}"#,
                      #"{"error":{"code":-32601,"message":"unsupported"}}"#] {
            #expect(!CodexResponseParser.usesFileCredentialStore(Data(value.utf8)))
        }
    }

    @Test
    func aSnapshotWithoutConfirmedWorkspaceCannotFetchModels() async {
        let client = CodexAccountModelClient(loginReader: CodexSavedLoginReader(
            authURL: URL(fileURLWithPath: "/nonexistent-codex-meter-test-auth")))
        let day = Date()
        let range = AccountModelDateRange(period: .day, containing: day, now: day)!
        await #expect(throws: AccountModelUsageError.unsupported) {
            try await client.fetchModels(in: range, account: CodexAccount(type: "chatgpt", email: "same@example.com", planType: "pro"))
        }
    }

    @Test
    func combinesResponseWeightsAcrossDaysAndPreservesSpeedTiers() throws {
        let calendar = calendar("Asia/Taipei")
        let now = date(2026, 10, 15, calendar: calendar)
        let range = try #require(AccountModelDateRange(period: .month, containing: now, now: now, calendar: calendar))
        let data = Data(#"""
        {"group_by":"day","units":"percent","data":[
          {"date":"2026-10-14","models":[
            {"model":"model-a","speed":"standard","credits":99.8},
            {"model":"model-b","speed":"fast","credits":0.2},
            {"model":"model-a","speed":null,"credits":0.0}
          ],"attribution":[{"model":"not-a-model-row","value":0}]},
          {"date":"2026-10-15","models":[
            {"model":"model-b","speed":"fast","credits":40},
            {"model":"model-b","speed":"standard","credits":60}
          ]},
          {"date":"2026-10-16","models":[{"model":"outside-range","speed":"fast"}]}
        ]}
        """#.utf8)
        let models = try AccountModelResponseParser.parse(data, range: range, calendar: calendar)
        #expect(models.map(\.model) == ["model-a", "model-b", "model-b"])
        #expect(abs(try #require(models[0].usageShare) - 0.499) < 0.0000001)
        #expect(abs(try #require(models[1].usageShare) - 0.201) < 0.0000001)
        #expect(abs(try #require(models[2].usageShare) - 0.3) < 0.0000001)
        #expect(models.map(\.isFast) == [false, true, false])
        #expect(Set(models.map(\.id)).count == 3)
    }

    @Test
    func normalizesTheWholeResponseRatherThanAveragingDays() throws {
        let calendar = calendar("Asia/Taipei")
        let now = date(2026, 10, 15, calendar: calendar)
        let range = try #require(AccountModelDateRange(period: .month, containing: now, now: now, calendar: calendar))
        let data = Data(#"""
        {"group_by":"day","units":"percent","data":[
          {"date":"2026-10-14","models":[{"model":"a","credits":10}]},
          {"date":"2026-10-15","models":[{"model":"b","credits":90},{"model":"zero","credits":0}]}
        ]}
        """#.utf8)
        let rows = try AccountModelResponseParser.parse(data, range: range, calendar: calendar)
        #expect(rows.map(\.usageShare) == [0.1, 0.9, 0])
    }

    @Test
    func incompleteUnknownOrZeroWeightsKeepNamesWithoutFabricatingShares() throws {
        let calendar = calendar("Asia/Taipei")
        let now = date(2026, 10, 15, calendar: calendar)
        let range = try #require(AccountModelDateRange(period: .day, containing: now, now: now, calendar: calendar))
        for weights in [#"[{"model":"a","credits":100},{"model":"b"}]"#,
                        #"[{"model":"a","credits":100},{"model":"b","credits":-1}]"#,
                        #"[{"model":"a","credits":100},{"model":"b","credits":"unknown"}]"#,
                        #"[{"model":"a","credits":0},{"model":"b","credits":0}]"#,
                        #"[{"model":"a","credits":1e308},{"model":"b","credits":1e308}]"#] {
            let data = Data("{\"group_by\":\"day\",\"units\":\"percent\",\"data\":[{\"date\":\"2026-10-15\",\"models\":\(weights)}]}".utf8)
            let rows = try AccountModelResponseParser.parse(data, range: range, calendar: calendar)
            #expect(rows.map(\.model) == ["a", "b"])
            #expect(rows.allSatisfy { $0.usageShare == nil })
        }
        for units in ["null", "\"unknown\""] {
            let data = Data("{\"group_by\":\"day\",\"units\":\(units),\"data\":[{\"date\":\"2026-10-15\",\"models\":[{\"model\":\"a\",\"credits\":100}]}]}".utf8)
            #expect(try AccountModelResponseParser.parse(data, range: range, calendar: calendar).first?.usageShare == nil)
        }
    }

    @Test
    func shareLabelsKeepSmallPositiveUsageVisible() {
        #expect(ModelUsageL10n.share(0.99786246, language: .english) == "99.79%")
        #expect(ModelUsageL10n.share(0.00003752, language: .english) == "0.0038%")
        #expect(ModelUsageL10n.share(0.00000001, language: .english) == "<0.0001%")
        #expect(ModelUsageL10n.share(0, language: .english) == "0%")
        #expect(ModelUsageL10n.share(nil, language: .english) == "—")
        #expect(ModelUsageL10n.share(.nan, language: .english) == "—")
    }

    @Test
    func emptySuccessIsDifferentFromUnsupportedOrMalformedResponse() throws {
        let calendar = calendar("Asia/Taipei")
        let now = date(2026, 10, 15, calendar: calendar)
        let range = try #require(AccountModelDateRange(period: .day, containing: now, now: now, calendar: calendar))
        #expect(try AccountModelResponseParser.parse(Data(#"{"group_by":"day","data":[]}"#.utf8), range: range).isEmpty)
        #expect(throws: AccountModelUsageError.unsupported) {
            try AccountModelResponseParser.parse(Data(#"{"group_by":"month","data":[]}"#.utf8), range: range)
        }
        for invalid in [#"{}"#, #"{"group_by":"day","data":[{"date":"2026-10-15"}]}"#,
                        #"{"group_by":"day","data":[{"date":"2026-02-30","models":[]}]}"#] {
            #expect(throws: AccountModelUsageError.invalidResponse) {
                try AccountModelResponseParser.parse(Data(invalid.utf8), range: range, calendar: calendar)
            }
        }
    }

    @Test
    func inclusiveDateRangeUsesCalendarBoundariesAcrossDSTAndClipsCurrentPeriods() throws {
        let calendar = calendar("America/Los_Angeles")
        let now = date(2026, 3, 9, calendar: calendar)
        let range = try #require(AccountModelDateRange(period: .week, containing: date(2026, 3, 8, calendar: calendar),
                                                       now: now, calendar: calendar))
        #expect(range.dateString(range.start, calendar: calendar) == "2026-03-02")
        #expect(range.dateString(range.end, calendar: calendar) == "2026-03-08")
        let year = try #require(AccountModelDateRange(period: .year, containing: now, now: now, calendar: calendar))
        #expect(year.dateString(year.start, calendar: calendar) == "2026-01-01")
        #expect(year.dateString(year.end, calendar: calendar) == "2026-03-09")
        let leap = try #require(AccountModelDateRange(period: .month, containing: date(2024, 2, 16, calendar: calendar),
                                                     now: now, calendar: calendar))
        #expect(leap.dateString(leap.end, calendar: calendar) == "2024-02-29")
        #expect(AccountModelDateRange(period: .hour, containing: now, now: now, calendar: calendar) == nil)
        #expect(AccountModelDateRange(period: .day, containing: date(2026, 3, 10, calendar: calendar),
                                     now: now, calendar: calendar) == nil)
    }

    @Test
    func savedLoginMustMatchBothEmailAndWorkspace() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("auth.json")
        let payload = Data(#"{"email":"tester@example.com"}"#.utf8).base64EncodedString()
        let auth: [String: Any] = ["tokens": ["id_token": "header.\(payload).signature",
                                                  "access_token": "test-only-token", "account_id": "workspace-a"]]
        try JSONSerialization.data(withJSONObject: auth).write(to: url)
        let reader = CodexSavedLoginReader(authURL: url)
        let matching = CodexAccount(type: "chatgpt", email: "Tester@example.com", planType: "pro", accountID: "workspace-a")
        #expect(try reader.read(for: matching).accountID == "workspace-a")
        for account in [CodexAccount(type: "chatgpt", email: "other@example.com", planType: "pro", accountID: "workspace-a"),
                        CodexAccount(type: "chatgpt", email: "tester@example.com", planType: "pro", accountID: "workspace-b")] {
            #expect(throws: AccountModelUsageError.accountChanged) { try reader.read(for: account) }
        }
        try Data(#"{"tokens":null}"#.utf8).write(to: url)
        #expect(throws: AccountModelUsageError.authenticationUnavailable) { try reader.read(for: matching) }
    }

    @Test @MainActor
    func modelFailurePreservesThePreviousListWithoutInvalidatingAccountTokens() async throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let settings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()))
        let day = UsageCalendar.calendar.startOfDay(for: Date()).addingTimeInterval(-86_400)
        let remote = snapshot(accountID: "a", day: day)
        let models = [AccountModelIdentity(model: "official-model", serviceTier: "fast")]
        let modelLoader = SequencedModelLoader(results: [.success(models), .failure(AccountModelUsageError.requestFailed)])
        let store = UsageStore(loader: ModelSnapshotLoader(values: [remote]), localUsageLoader: FixedLocalUsageLoader(),
                               settings: settings, modelLoader: modelLoader)
        await store.refresh()
        #expect(store.accountModels(for: .day, containing: day).state == .idle)
        await store.loadAccountModels(for: .day, containing: day)
        #expect(store.accountModels(for: .day, containing: day) == AccountModelList(models: models, state: .loaded))
        await store.loadAccountModels(for: .day, containing: day, force: true)
        #expect(store.accountModels(for: .day, containing: day) == AccountModelList(models: models, state: .failed, isStale: true))
        #expect(store.statisticsUsage(.day, count: 1).first?.tokens == 764_709_144)
        #expect(store.state == .loaded)
        #expect(store.modelUsage(.day, containing: day).isEmpty)
    }

    @Test @MainActor
    func reselectingADateStillFinishesWhenThePreviousViewTaskWasCancelled() async throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let settings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()))
        let day = UsageCalendar.calendar.date(byAdding: .day, value: -1, to: UsageCalendar.calendar.startOfDay(for: Date()))!
        let loader = DelayedFirstModelLoader()
        let store = UsageStore(loader: ModelSnapshotLoader(values: [snapshot(accountID: "old", day: day)]),
                               localUsageLoader: FixedLocalUsageLoader(), settings: settings, modelLoader: loader)
        await store.refresh()
        let cancelledView = Task { await store.loadAccountModels(for: .day, containing: day) }
        await loader.waitForFirstRequest()
        cancelledView.cancel()
        // A second view selecting the same date finds an existing cache request.
        await store.loadAccountModels(for: .day, containing: day)
        await loader.completeFirstRequest()
        await cancelledView.value
        #expect(store.accountModels(for: .day, containing: day).models.map(\.model) == ["old"])
        #expect(store.accountModels(for: .day, containing: day).state == .loaded)
    }

    @Test @MainActor
    func accountSwitchDiscardsAnInFlightOldWorkspaceResult() async throws {
        let appearance = NSApplication.shared.appearance
        defer { NSApplication.shared.appearance = appearance }
        let settings = AppSettings(defaults: SQLitePreferences(database: try SQLiteStore()))
        let day = UsageCalendar.calendar.startOfDay(for: Date()).addingTimeInterval(-86_400)
        let loader = DelayedFirstModelLoader()
        let store = UsageStore(loader: ModelSnapshotLoader(values: [snapshot(accountID: "old", day: day),
                                                                    snapshot(accountID: "new", day: day)]),
                               localUsageLoader: FixedLocalUsageLoader(), settings: settings, modelLoader: loader)
        await store.refresh()
        let oldRequest = Task { await store.loadAccountModels(for: .day, containing: day) }
        await loader.waitForFirstRequest()
        #expect(store.accountModels(for: .day, containing: day).state == .loading)
        await store.refresh()
        #expect(store.accountModels(for: .day, containing: day).models.map(\.model) == ["new"])
        await loader.completeFirstRequest()
        await oldRequest.value
        #expect(store.accountModels(for: .day, containing: day).models.map(\.model) == ["new"])
        #expect(store.accountModels(for: .day, containing: day).state == .loaded)
    }

    private func snapshot(accountID: String, day: Date) -> CodexUsageSnapshot {
        CodexUsageSnapshot(fetchedAt: Date(),
                           account: CodexAccount(type: "chatgpt", email: "tester@example.com", planType: "pro", accountID: accountID),
                           rateLimitBuckets: [], usageSummary: nil,
                           dailyUsage: [DailyTokenUsage(date: day, tokens: 764_709_144)])
    }
    private func calendar(_ timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private actor SequencedModelLoader: AccountModelUsageLoading {
    var results: [Result<[AccountModelIdentity], Error>]
    init(results: [Result<[AccountModelIdentity], Error>]) { self.results = results }
    func fetchModels(in range: AccountModelDateRange, account: CodexAccount) async throws -> [AccountModelIdentity] {
        try results.removeFirst().get()
    }
}

private actor DelayedFirstModelLoader: AccountModelUsageLoading {
    var first: CheckedContinuation<[AccountModelIdentity], Never>?
    var waiter: CheckedContinuation<Void, Never>?
    var count = 0
    func fetchModels(in range: AccountModelDateRange, account: CodexAccount) async throws -> [AccountModelIdentity] {
        count += 1
        if count == 1 {
            let result = await withCheckedContinuation { continuation in
                first = continuation
                waiter?.resume()
                waiter = nil
            }
            try Task.checkCancellation()
            return result
        }
        return [AccountModelIdentity(model: account.accountID ?? "missing")]
    }
    func waitForFirstRequest() async {
        if first != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func completeFirstRequest() { first?.resume(returning: [AccountModelIdentity(model: "old")]); first = nil }
}

private actor ModelSnapshotLoader: CodexUsageLoading {
    var values: [CodexUsageSnapshot]
    init(values: [CodexUsageSnapshot]) { self.values = values }
    func fetchSnapshot() async throws -> CodexUsageSnapshot { values.removeFirst() }
}
