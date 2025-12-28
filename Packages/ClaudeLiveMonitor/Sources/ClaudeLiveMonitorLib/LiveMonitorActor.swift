import Foundation

// MARK: - Configuration Constants

private enum Timing {
    static let gapThresholdSeconds: TimeInterval = 1800  // 30 minutes
    static let activityThresholdSeconds: TimeInterval = 300  // 5 minutes
    static let secondsPerHour: TimeInterval = 3600
}

// MARK: - Actor-based Live Monitor

/// LiveMonitorActor is a thread-safe, actor-based implementation for monitoring Claude usage files.
/// This implementation uses Swift's modern concurrency features for better performance and safety.
public actor LiveMonitorActor {
    private let config: LiveMonitorConfig
    private var lastFileTimestamps: [String: Date] = [:]
    private var processedHashes: Set<String> = Set()
    private var allEntries: [UsageEntry] = []
    private var maxTokensFromPreviousSessions: Int = 0

    private nonisolated let parser = JSONLParser()

    public init(config: LiveMonitorConfig) {
        self.config = config
    }

    // MARK: - Public API

    public func getActiveBlock() -> SessionBlock? {
        refreshEntriesIfNeeded()
        let blocks = identifySessionBlocks(entries: allEntries)
        updateMaxTokensFromCompletedSessions(blocks)
        return findMostRecentActiveBlock(from: blocks)
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

    // MARK: - Orchestration

    private func refreshEntriesIfNeeded() {
        let modifiedFiles = findModifiedUsageFiles()
        guard !modifiedFiles.isEmpty else { return }
        loadEntriesFromFiles(modifiedFiles)
    }

    private func findModifiedUsageFiles() -> [String] {
        findUsageFiles().filter { checkAndUpdateTimestamp(for: $0) }
    }

    private func checkAndUpdateTimestamp(for file: String) -> Bool {
        guard let currentTimestamp = getFileModificationTime(file) else { return false }
        let lastTimestamp = lastFileTimestamps[file]
        let isModified = lastTimestamp.map { currentTimestamp > $0 } ?? true
        if isModified {
            lastFileTimestamps[file] = currentTimestamp
        }
        return isModified
    }

    private func updateMaxTokensFromCompletedSessions(_ blocks: [SessionBlock]) {
        maxTokensFromPreviousSessions = blocks
            .filter { !$0.isActive && !$0.isGap }
            .map(\.tokenCounts.total)
            .max() ?? 0
    }

    private func findMostRecentActiveBlock(from blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { $0.startTime < $1.startTime }
    }

    // MARK: - File Operations

    private func findUsageFiles() -> [String] {
        config.claudePaths.flatMap { findJSONFilesInProjects(basePath: $0) }
    }

    private func findJSONFilesInProjects(basePath: String) -> [String] {
        let projectsPath = basePath.appending("/projects")
        let fileManager = FileManager.default

        guard let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) else {
            return []
        }

        return projectDirs.flatMap { projectDir -> [String] in
            let projectPath = projectsPath.appending("/\(projectDir)")
            guard let files = try? fileManager.contentsOfDirectory(atPath: projectPath) else {
                return []
            }
            return files
                .filter { $0.hasSuffix(".json") }
                .map { projectPath.appending("/\($0)") }
        }
    }

    private nonisolated func getFileModificationTime(_ path: String) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    // MARK: - Entry Loading

    private func loadEntriesFromFiles(_ files: [String]) {
        let newEntries = files.flatMap { parser.parseFile(at: $0, processedHashes: &processedHashes) }
        allEntries.append(contentsOf: newEntries)
        allEntries.sort { $0.timestamp < $1.timestamp }
    }

    // MARK: - Session Block Identification

    private func identifySessionBlocks(entries: [UsageEntry]) -> [SessionBlock] {
        guard !entries.isEmpty else { return [] }

        let sessionDurationSeconds = config.sessionDurationHours * Timing.secondsPerHour
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }

        return buildSessionBlocks(from: sortedEntries, sessionDuration: sessionDurationSeconds)
    }

    private func buildSessionBlocks(
        from sortedEntries: [UsageEntry],
        sessionDuration: TimeInterval
    ) -> [SessionBlock] {
        var blocks: [SessionBlock] = []
        var currentBlockStart: Date?
        var currentBlockEntries: [UsageEntry] = []
        let now = Date()

        for entry in sortedEntries {
            if let blockStart = currentBlockStart {
                if shouldStartNewBlock(entry, blockStart: blockStart, lastEntry: currentBlockEntries.last, sessionDuration: sessionDuration) {
                    if !currentBlockEntries.isEmpty {
                        blocks.append(createSessionBlock(
                            entries: currentBlockEntries,
                            startTime: blockStart,
                            sessionDuration: sessionDuration,
                            now: now
                        ))
                    }
                    currentBlockStart = entry.timestamp
                    currentBlockEntries = [entry]
                } else {
                    currentBlockEntries.append(entry)
                }
            } else {
                currentBlockStart = entry.timestamp
                currentBlockEntries = [entry]
            }
        }

        if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
            blocks.append(createSessionBlock(
                entries: currentBlockEntries,
                startTime: blockStart,
                sessionDuration: sessionDuration,
                now: now
            ))
        }

        return blocks
    }

    private func shouldStartNewBlock(
        _ entry: UsageEntry,
        blockStart: Date,
        lastEntry: UsageEntry?,
        sessionDuration: TimeInterval
    ) -> Bool {
        let timeSinceBlockStart = entry.timestamp.timeIntervalSince(blockStart)
        let timeSinceLastEntry = lastEntry.map { entry.timestamp.timeIntervalSince($0.timestamp) } ?? 0
        return timeSinceBlockStart > sessionDuration || timeSinceLastEntry > Timing.gapThresholdSeconds
    }

    // MARK: - Session Block Creation

    private func createSessionBlock(
        entries: [UsageEntry],
        startTime: Date,
        sessionDuration: TimeInterval,
        now: Date
    ) -> SessionBlock {
        let endTime = startTime.addingTimeInterval(sessionDuration)
        let isActive = isSessionActive(lastEntryTime: entries.last?.timestamp, now: now)
        let tokenCounts = aggregateTokenCounts(entries)
        let costsByModel = aggregateCostsByModel(entries)
        let totalCost = costsByModel.values.reduce(0, +)
        let models = Set(entries.map(\.model))
        let elapsed = calculateElapsedTime(isActive: isActive, startTime: startTime, endTime: endTime, now: now)
        let burnRate = calculateBurnRate(tokenCounts: tokenCounts, totalCost: totalCost, elapsed: elapsed)
        let projectedUsage = calculateProjectedUsage(
            tokenCounts: tokenCounts,
            totalCost: totalCost,
            elapsed: elapsed,
            remainingTime: max(0, endTime.timeIntervalSince(now))
        )

        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: isActive ? nil : entries.last?.timestamp,
            isActive: isActive,
            isGap: false,
            entries: config.order == .ascending ? entries : entries.reversed(),
            tokenCounts: tokenCounts,
            costUSD: totalCost,
            models: Array(models),
            usageLimitResetTime: entries.compactMap(\.usageLimitResetTime).last,
            burnRate: burnRate,
            projectedUsage: projectedUsage
        )
    }

    // MARK: - Pure Calculations

    private func isSessionActive(lastEntryTime: Date?, now: Date) -> Bool {
        guard let lastEntryTime else { return false }
        return now.timeIntervalSince(lastEntryTime) < Timing.activityThresholdSeconds
    }

    private func aggregateTokenCounts(_ entries: [UsageEntry]) -> TokenCounts {
        entries.reduce(
            TokenCounts(inputTokens: 0, outputTokens: 0, cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
        ) { result, entry in
            TokenCounts(
                inputTokens: result.inputTokens + entry.usage.inputTokens,
                outputTokens: result.outputTokens + entry.usage.outputTokens,
                cacheCreationInputTokens: result.cacheCreationInputTokens + entry.usage.cacheCreationInputTokens,
                cacheReadInputTokens: result.cacheReadInputTokens + entry.usage.cacheReadInputTokens
            )
        }
    }

    private func aggregateCostsByModel(_ entries: [UsageEntry]) -> [String: Double] {
        entries.reduce(into: [:]) { costs, entry in
            costs[entry.model, default: 0] += entry.costUSD
        }
    }

    private func calculateElapsedTime(
        isActive: Bool,
        startTime: Date,
        endTime: Date,
        now: Date
    ) -> TimeInterval {
        isActive ? now.timeIntervalSince(startTime) : endTime.timeIntervalSince(startTime)
    }

    private func calculateBurnRate(
        tokenCounts: TokenCounts,
        totalCost: Double,
        elapsed: TimeInterval
    ) -> BurnRate {
        let tokensPerSecond = elapsed > 0 ? Double(tokenCounts.total) / elapsed : 0
        let tokensPerMinute = Int(tokensPerSecond * 60)
        let costPerHour = elapsed > 0 ? (totalCost / elapsed) * Timing.secondsPerHour : 0

        return BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
    }

    private func calculateProjectedUsage(
        tokenCounts: TokenCounts,
        totalCost: Double,
        elapsed: TimeInterval,
        remainingTime: TimeInterval
    ) -> ProjectedUsage {
        let tokensPerSecond = elapsed > 0 ? Double(tokenCounts.total) / elapsed : 0
        let costPerHour = elapsed > 0 ? (totalCost / elapsed) * Timing.secondsPerHour : 0

        return ProjectedUsage(
            totalTokens: tokenCounts.total + Int(tokensPerSecond * remainingTime),
            totalCost: totalCost + costPerHour * (remainingTime / Timing.secondsPerHour),
            remainingMinutes: remainingTime / 60
        )
    }
}
