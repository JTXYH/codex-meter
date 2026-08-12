import Foundation

struct LocalTokenUsage: Equatable, Sendable {
    static let zero = LocalTokenUsage(
        totalTokens: 0,
        inputTokens: 0,
        cachedInputTokens: 0,
        cacheWriteInputTokens: 0,
        outputTokens: 0,
        reasoningOutputTokens: 0,
        apiEquivalentCostUSD: 0
    )

    let totalTokens: Int64
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let cacheWriteInputTokens: Int64
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
    let apiEquivalentCostUSD: Double

    var cacheHitPercentage: Double {
        guard inputTokens > 0 else { return 0 }
        return min(max(Double(cachedInputTokens) / Double(inputTokens), 0), 1)
    }

    func adding(_ other: LocalTokenUsage) -> LocalTokenUsage {
        LocalTokenUsage(
            totalTokens: Self.saturatingAdd(totalTokens, other.totalTokens),
            inputTokens: Self.saturatingAdd(inputTokens, other.inputTokens),
            cachedInputTokens: Self.saturatingAdd(cachedInputTokens, other.cachedInputTokens),
            cacheWriteInputTokens: Self.saturatingAdd(
                cacheWriteInputTokens,
                other.cacheWriteInputTokens
            ),
            outputTokens: Self.saturatingAdd(outputTokens, other.outputTokens),
            reasoningOutputTokens: Self.saturatingAdd(
                reasoningOutputTokens,
                other.reasoningOutputTokens
            ),
            apiEquivalentCostUSD: Self.finiteSum(
                apiEquivalentCostUSD,
                other.apiEquivalentCostUSD
            )
        )
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }

    private static func finiteSum(_ lhs: Double, _ rhs: Double) -> Double {
        let sum = lhs + rhs
        return sum.isFinite ? max(sum, 0) : .greatestFiniteMagnitude
    }
}

protocol LocalTokenUsageLoading: Sendable {
    func todayUsage(at now: Date) async -> LocalTokenUsage
}

actor LocalTokenUsageScanner: LocalTokenUsageLoading {
    private struct FileState {
        var offset: UInt64 = 0
        var remainder = Data()
        var usage = LocalTokenUsage.zero
        var model: String?
        var modificationDate: Date?
    }

    private struct RolloutEntry: Decodable {
        let timestamp: String?
        let type: String?
        let payload: Payload?

        struct Payload: Decodable {
            let type: String?
            let info: TokenInfo?
            let model: String?
        }

        struct TokenInfo: Decodable {
            let lastTokenUsage: TokenUsage?

            enum CodingKeys: String, CodingKey {
                case lastTokenUsage = "last_token_usage"
            }
        }

        struct TokenUsage: Decodable {
            let inputTokens: Int64?
            let cachedInputTokens: Int64?
            let cacheWriteInputTokens: Int64?
            let outputTokens: Int64?
            let reasoningOutputTokens: Int64?
            let totalTokens: Int64?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case cachedInputTokens = "cached_input_tokens"
                case cacheWriteInputTokens = "cache_write_input_tokens"
                case outputTokens = "output_tokens"
                case reasoningOutputTokens = "reasoning_output_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }

    private struct ModelPricing {
        let inputUSDPerMillion: Double
        let cachedInputUSDPerMillion: Double
        let outputUSDPerMillion: Double

        var cacheWriteInputUSDPerMillion: Double {
            inputUSDPerMillion * 1.25
        }
    }

    private let sessionsDirectory: URL
    private let fileManager: FileManager
    private var calendar: Calendar
    private let decoder = JSONDecoder()
    private let fractionalDateFormatter: ISO8601DateFormatter
    private let standardDateFormatter: ISO8601DateFormatter
    private var activeDayStart: Date?
    private var fileStates: [URL: FileState] = [:]

    init(
        sessionsDirectory: URL? = nil,
        fileManager: FileManager = .default,
        calendar inputCalendar: Calendar = .current
    ) {
        self.fileManager = fileManager
        var calendar = inputCalendar
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
        self.sessionsDirectory = sessionsDirectory
            ?? Self.defaultSessionsDirectory(fileManager: fileManager)

        let fractionalDateFormatter = ISO8601DateFormatter()
        fractionalDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.fractionalDateFormatter = fractionalDateFormatter

        let standardDateFormatter = ISO8601DateFormatter()
        standardDateFormatter.formatOptions = [.withInternetDateTime]
        self.standardDateFormatter = standardDateFormatter
    }

    func todayUsage(at now: Date = Date()) async -> LocalTokenUsage {
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return .zero
        }

        if activeDayStart != dayStart {
            activeDayStart = dayStart
            fileStates.removeAll(keepingCapacity: true)
        }

        refreshCandidateFiles(dayStart: dayStart, dayEnd: dayEnd)
        return fileStates.values.reduce(.zero) { total, state in
            total.adding(state.usage)
        }
    }

    private static func defaultSessionsDirectory(fileManager: FileManager) -> URL {
        let environment = ProcessInfo.processInfo.environment
        let codexHome: URL
        if let override = environment["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            codexHome = URL(fileURLWithPath: (override as NSString).expandingTildeInPath)
        } else {
            codexHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        }
        return codexHome.appendingPathComponent("sessions", isDirectory: true)
    }

    private func refreshCandidateFiles(dayStart: Date, dayEnd: Date) {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey,
        ]
        guard let enumerator = fileManager.enumerator(
            at: sessionsDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            fileStates.removeAll(keepingCapacity: true)
            return
        }

        var candidates = Set<URL>()
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl",
                  fileURL.lastPathComponent.hasPrefix("rollout-")
            else { continue }

            let standardizedURL = fileURL.standardizedFileURL
            guard let values = try? standardizedURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modificationDate = values.contentModificationDate,
                  modificationDate >= dayStart
            else { continue }

            candidates.insert(standardizedURL)
            updateFile(
                at: standardizedURL,
                fileSize: max(values.fileSize ?? 0, 0),
                modificationDate: modificationDate,
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        }

        fileStates = fileStates.filter { candidates.contains($0.key) }
    }

    private func updateFile(
        at url: URL,
        fileSize: Int,
        modificationDate: Date,
        dayStart: Date,
        dayEnd: Date
    ) {
        var state = fileStates[url] ?? FileState()
        let size = UInt64(fileSize)
        let wasTouchedWithoutGrowth = state.modificationDate.map {
            size == state.offset && modificationDate > $0
        } ?? false

        if size < state.offset || wasTouchedWithoutGrowth {
            state = FileState()
        }

        guard size > state.offset else {
            state.modificationDate = modificationDate
            fileStates[url] = state
            return
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            try handle.seek(toOffset: state.offset)
            let appendedData = try handle.readToEnd() ?? Data()
            state.offset += UInt64(appendedData.count)
            state.modificationDate = modificationDate

            var buffer = state.remainder
            buffer.append(appendedData)
            var lineStart = buffer.startIndex
            for index in buffer.indices where buffer[index] == 0x0A {
                let line = buffer[lineStart..<index]
                if !line.isEmpty {
                    process(
                        Data(line),
                        state: &state,
                        dayStart: dayStart,
                        dayEnd: dayEnd
                    )
                }
                lineStart = buffer.index(after: index)
            }
            state.remainder = Data(buffer[lineStart..<buffer.endIndex])
            fileStates[url] = state
        } catch {
            // A session may be moved or replaced while Codex is writing it.
            // Leave the previous total intact and retry on the next refresh.
            fileStates[url] = state
        }
    }

    private func process(
        _ data: Data,
        state: inout FileState,
        dayStart: Date,
        dayEnd: Date
    ) {
        guard let entry = try? decoder.decode(RolloutEntry.self, from: data) else {
            return
        }

        if entry.type == "turn_context" {
            if let model = entry.payload?.model?.trimmingCharacters(in: .whitespacesAndNewlines),
               !model.isEmpty {
                state.model = model
            }
            return
        }

        guard
              entry.type == "event_msg",
              entry.payload?.type == "token_count",
              let timestamp = entry.timestamp,
              let eventDate = fractionalDateFormatter.date(from: timestamp)
                ?? standardDateFormatter.date(from: timestamp),
              eventDate >= dayStart,
              eventDate < dayEnd,
              let tokenUsage = entry.payload?.info?.lastTokenUsage
        else { return }

        let inputTokens = max(tokenUsage.inputTokens ?? 0, 0)
        let cachedInputTokens = min(
            max(tokenUsage.cachedInputTokens ?? 0, 0),
            inputTokens
        )
        let remainingInputTokens = inputTokens - cachedInputTokens
        let cacheWriteInputTokens = min(
            max(tokenUsage.cacheWriteInputTokens ?? 0, 0),
            remainingInputTokens
        )
        let outputTokens = max(tokenUsage.outputTokens ?? 0, 0)
        let reasoningOutputTokens = min(
            max(tokenUsage.reasoningOutputTokens ?? 0, 0),
            outputTokens
        )
        let totalTokens = max(
            tokenUsage.totalTokens
                ?? Self.saturatingAdd(inputTokens, outputTokens),
            0
        )

        state.usage = state.usage.adding(LocalTokenUsage(
            totalTokens: totalTokens,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: reasoningOutputTokens,
            apiEquivalentCostUSD: Self.apiEquivalentCostUSD(
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                cacheWriteInputTokens: cacheWriteInputTokens,
                outputTokens: outputTokens,
                model: state.model
            )
        ))
    }

    private static func apiEquivalentCostUSD(
        inputTokens: Int64,
        cachedInputTokens: Int64,
        cacheWriteInputTokens: Int64,
        outputTokens: Int64,
        model: String?
    ) -> Double {
        let pricing = pricing(for: model)
        let uncachedInputTokens = max(
            inputTokens - cachedInputTokens - cacheWriteInputTokens,
            0
        )
        let isLongContext = inputTokens > 272_000
        let inputMultiplier = isLongContext ? 2.0 : 1.0
        let outputMultiplier = isLongContext ? 1.5 : 1.0

        let inputCost = Double(uncachedInputTokens)
            * pricing.inputUSDPerMillion
            * inputMultiplier
        let cachedInputCost = Double(cachedInputTokens)
            * pricing.cachedInputUSDPerMillion
            * inputMultiplier
        let cacheWriteCost = Double(cacheWriteInputTokens)
            * pricing.cacheWriteInputUSDPerMillion
            * inputMultiplier
        let outputCost = Double(outputTokens)
            * pricing.outputUSDPerMillion
            * outputMultiplier
        return (inputCost + cachedInputCost + cacheWriteCost + outputCost) / 1_000_000
    }

    private static func pricing(for model: String?) -> ModelPricing {
        let identifier = model?.lowercased() ?? ""
        if identifier.contains("gpt-5.6-terra") {
            return ModelPricing(
                inputUSDPerMillion: 2.50,
                cachedInputUSDPerMillion: 0.25,
                outputUSDPerMillion: 15.00
            )
        }
        if identifier.contains("gpt-5.6-luna") {
            return ModelPricing(
                inputUSDPerMillion: 1.00,
                cachedInputUSDPerMillion: 0.10,
                outputUSDPerMillion: 6.00
            )
        }

        // GPT-5.6 Sol is also the fallback for Codex internal routing names.
        return ModelPricing(
            inputUSDPerMillion: 5.00,
            cachedInputUSDPerMillion: 0.50,
            outputUSDPerMillion: 30.00
        )
    }

    private static func saturatingAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }
}
