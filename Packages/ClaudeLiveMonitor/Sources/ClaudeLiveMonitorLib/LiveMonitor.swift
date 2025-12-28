import Foundation

// MARK: - Configuration

public struct LiveMonitorConfig {
    public let claudePaths: [String]
    public let sessionDurationHours: Double
    public let tokenLimit: Int?
    public let refreshInterval: TimeInterval
    public let order: SortOrder

    public enum SortOrder {
        case ascending
        case descending
    }

    public init(claudePaths: [String], sessionDurationHours: Double = 5,
                tokenLimit: Int? = nil, refreshInterval: TimeInterval = 1.0,
                order: SortOrder = .descending) {
        self.claudePaths = claudePaths
        self.sessionDurationHours = sessionDurationHours
        self.tokenLimit = tokenLimit
        self.refreshInterval = refreshInterval
        self.order = order
    }
}

// MARK: - Live Monitor

/// LiveMonitor manages the reading and processing of Claude usage files.
/// Uses Swift actor for thread-safe access - no manual locking needed.
public actor LiveMonitor {
    private let config: LiveMonitorConfig
    private var lastFileTimestamps: [String: Date] = [:]
    private var processedHashes: Set<String> = Set()
    private var allEntries: [UsageEntry] = []
    private var maxTokensFromPreviousSessions: Int = 0
    private let parser = JSONLParser()

    public init(config: LiveMonitorConfig) {
        self.config = config
    }

    // MARK: - Public API

    public func getActiveBlock() -> SessionBlock? {
        let files = findUsageFiles()
        guard !files.isEmpty else { return nil }

        loadModifiedFiles(files)

        let blocks = identifySessionBlocks(entries: allEntries)
        maxTokensFromPreviousSessions = maxTokensFromCompletedBlocks(blocks)

        return mostRecentActiveBlock(from: blocks)
    }

    public func getAutoTokenLimit() -> Int? {
        _ = getActiveBlock()
        return maxTokensFromPreviousSessions > 0 ? maxTokensFromPreviousSessions : nil
    }

    public func clearCache() {
        lastFileTimestamps.removeAll()
        processedHashes.removeAll()
        allEntries.removeAll()
        maxTokensFromPreviousSessions = 0
    }

    // MARK: - File Discovery

    private func findUsageFiles() -> [String] {
        config.claudePaths.flatMap { findJSONLFiles(in: $0) }
    }

    private func findJSONLFiles(in claudePath: String) -> [String] {
        let projectsPath = "\(claudePath)/projects"
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: projectsPath),
              let enumerator = fileManager.enumerator(atPath: projectsPath) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? String }
            .filter { $0.hasSuffix(".jsonl") }
            .map { "\(projectsPath)/\($0)" }
    }

    // MARK: - File Loading

    private func loadModifiedFiles(_ files: [String]) {
        let filesToRead = files.filter { isFileModified($0) }
        guard !filesToRead.isEmpty else { return }

        loadEntriesFromFiles(filesToRead)
    }

    private func isFileModified(_ file: String) -> Bool {
        guard let timestamp = fileModificationTime(file) else { return false }
        let wasModified = lastFileTimestamps[file].map { timestamp > $0 } ?? true
        if wasModified {
            lastFileTimestamps[file] = timestamp
        }
        return wasModified
    }

    private func fileModificationTime(_ path: String) -> Date? {
        try? FileManager.default
            .attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    private func loadEntriesFromFiles(_ files: [String]) {
        let newEntries = files.flatMap { parser.parseFile(at: $0, processedHashes: &processedHashes) }
        allEntries.append(contentsOf: newEntries)
        allEntries.sort { $0.timestamp < $1.timestamp }
    }

    // MARK: - Block Selection

    private func maxTokensFromCompletedBlocks(_ blocks: [SessionBlock]) -> Int {
        blocks
            .filter { !$0.isActive && !$0.isGap }
            .map(\.tokenCounts.total)
            .max() ?? 0
    }

    private func mostRecentActiveBlock(from blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { ($0.actualEndTime ?? $0.startTime) < ($1.actualEndTime ?? $1.startTime) }
    }

    // MARK: - Session Block Identification

    private func identifySessionBlocks(entries: [UsageEntry]) -> [SessionBlock] {
        guard !entries.isEmpty else { return [] }

        let sessionDurationSeconds = config.sessionDurationHours * 60 * 60
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        let now = Date()

        return buildBlocks(from: sortedEntries, sessionDuration: sessionDurationSeconds, now: now)
    }

    private func buildBlocks(from entries: [UsageEntry], sessionDuration: TimeInterval, now: Date) -> [SessionBlock] {
        var blocks: [SessionBlock] = []
        var currentBlockStart: Date?
        var currentBlockEntries: [UsageEntry] = []

        for entry in entries {
            let shouldStartNewBlock = currentBlockStart.map { blockStart in
                shouldSplitBlock(
                    entryTime: entry.timestamp,
                    blockStart: blockStart,
                    lastEntryTime: currentBlockEntries.last?.timestamp,
                    sessionDuration: sessionDuration
                )
            } ?? true

            if shouldStartNewBlock {
                if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
                    if let block = createBlock(startTime: blockStart, entries: currentBlockEntries, now: now, sessionDuration: sessionDuration) {
                        blocks.append(block)
                    }
                }
                currentBlockStart = floorToHour(entry.timestamp)
                currentBlockEntries = [entry]
            } else {
                currentBlockEntries.append(entry)
            }
        }

        if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
            if let block = createBlock(startTime: blockStart, entries: currentBlockEntries, now: now, sessionDuration: sessionDuration) {
                blocks.append(block)
            }
        }

        return blocks
    }

    private func shouldSplitBlock(entryTime: Date, blockStart: Date, lastEntryTime: Date?, sessionDuration: TimeInterval) -> Bool {
        let timeSinceBlockStart = entryTime.timeIntervalSince(blockStart)
        let timeSinceLastEntry = lastEntryTime.map { entryTime.timeIntervalSince($0) } ?? 0
        return timeSinceBlockStart > sessionDuration || timeSinceLastEntry > sessionDuration
    }

    // MARK: - Block Creation

    private func createBlock(startTime: Date, entries: [UsageEntry], now: Date, sessionDuration: TimeInterval) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        let endTime = startTime.addingTimeInterval(sessionDuration)
        let actualEndTime = entries.last?.timestamp
        let isActive = computeIsActive(actualEndTime: actualEndTime, now: now, endTime: endTime, sessionDuration: sessionDuration)

        let aggregated = aggregateEntries(entries)
        let burnRate = computeBurnRate(tokens: aggregated.tokenCounts.total, cost: aggregated.costUSD, startTime: startTime, actualEndTime: actualEndTime, now: now)
        let projectedUsage = computeProjectedUsage(currentTokens: aggregated.tokenCounts.total, currentCost: aggregated.costUSD, burnRate: burnRate, actualEndTime: actualEndTime, endTime: endTime, now: now)

        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: actualEndTime,
            isActive: isActive,
            isGap: false,
            entries: entries,
            tokenCounts: aggregated.tokenCounts,
            costUSD: aggregated.costUSD,
            models: aggregated.models,
            usageLimitResetTime: aggregated.usageLimitResetTime,
            burnRate: burnRate,
            projectedUsage: projectedUsage
        )
    }

    // MARK: - Pure Calculations

    private func computeIsActive(actualEndTime: Date?, now: Date, endTime: Date, sessionDuration: TimeInterval) -> Bool {
        guard let actualEndTime else { return false }
        return now.timeIntervalSince(actualEndTime) < sessionDuration && now < endTime
    }

    private func aggregateEntries(_ entries: [UsageEntry]) -> (tokenCounts: TokenCounts, costUSD: Double, models: [String], usageLimitResetTime: Date?) {
        let tokenCounts = entries.reduce(TokenCounts.zero) { accumulated, entry in
            TokenCounts(
                inputTokens: accumulated.inputTokens + entry.usage.inputTokens,
                outputTokens: accumulated.outputTokens + entry.usage.outputTokens,
                cacheCreationInputTokens: accumulated.cacheCreationInputTokens + entry.usage.cacheCreationInputTokens,
                cacheReadInputTokens: accumulated.cacheReadInputTokens + entry.usage.cacheReadInputTokens
            )
        }

        let costUSD = entries.reduce(0.0) { $0 + $1.costUSD }
        let models = Array(Set(entries.map(\.model)))
        let usageLimitResetTime = entries.lazy.compactMap(\.usageLimitResetTime).last

        return (tokenCounts, costUSD, models, usageLimitResetTime)
    }

    private func computeBurnRate(tokens: Int, cost: Double, startTime: Date, actualEndTime: Date?, now: Date) -> BurnRate {
        let elapsedMinutes = (actualEndTime ?? now).timeIntervalSince(startTime) / 60
        let tokensPerMinute = elapsedMinutes > 0 ? Int(Double(tokens) / elapsedMinutes) : 0
        let costPerHour = elapsedMinutes > 0 ? (cost / elapsedMinutes) * 60 : 0

        return BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
    }

    private func computeProjectedUsage(currentTokens: Int, currentCost: Double, burnRate: BurnRate, actualEndTime: Date?, endTime: Date, now: Date) -> ProjectedUsage {
        let remainingMinutes = endTime.timeIntervalSince(actualEndTime ?? now) / 60
        let projectedTokens = currentTokens + Int(Double(burnRate.tokensPerMinute) * remainingMinutes)
        let projectedCost = currentCost + (burnRate.costPerHour * remainingMinutes / 60)

        return ProjectedUsage(
            totalTokens: projectedTokens,
            totalCost: projectedCost,
            remainingMinutes: remainingMinutes
        )
    }

    // MARK: - Date Utilities

    private func floorToHour(_ date: Date) -> Date {
        let secondsSinceEpoch = date.timeIntervalSince1970
        let secondsInHour = 3600.0
        let flooredSeconds = floor(secondsSinceEpoch / secondsInHour) * secondsInHour
        return Date(timeIntervalSince1970: flooredSeconds)
    }
}

// MARK: - TokenCounts Extension

private extension TokenCounts {
    static let zero = TokenCounts(
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
}
