//
//  SessionRepository.swift
//  Repository for active Claude session data
//

import Foundation

// MARK: - SessionRepository

public actor SessionRepository: SessionDataSource {
    private let basePath: String
    private let sessionDurationHours: Double
    private let parser = JSONLParser()

    private var lastFileTimestamps: [String: Date] = [:]
    private var allEntries: [UsageEntry] = []
    private var cachedTokenLimit: Int = 0
    private var cachedSession: (session: SessionBlock?, timestamp: Date)?

    public init(basePath: String = NSHomeDirectory() + "/.claude", sessionDurationHours: Double = 5.0) {
        self.basePath = basePath
        self.sessionDurationHours = sessionDurationHours
    }

    // MARK: - SessionDataSource

    public func getActiveSession() async -> SessionBlock? {
        if let cached = cachedSession, isCacheValid(timestamp: cached.timestamp) {
            return cached.session
        }

        let session = loadActiveSession()
        cachedSession = (session, Date())
        return session
    }

    private func loadActiveSession() -> SessionBlock? {
        loadModifiedFiles()
        let blocks = identifySessionBlocks()
        cachedTokenLimit = maxTokensFromCompletedBlocks(blocks)
        return mostRecentActiveBlock(from: blocks)?
            .with(tokenLimit: cachedTokenLimit > 0 ? cachedTokenLimit : nil)
    }

    public func getBurnRate() async -> BurnRate? {
        await getActiveSession()?.burnRate
    }

    public func getAutoTokenLimit() async -> Int? {
        _ = await getActiveSession()
        return cachedTokenLimit > 0 ? cachedTokenLimit : nil
    }

    // MARK: - Cache Management

    public func clearCache() {
        lastFileTimestamps.removeAll()
        allEntries.removeAll()
        cachedTokenLimit = 0
        cachedSession = nil
    }

    // MARK: - File Loading

    private func loadModifiedFiles() {
        let files = findUsageFiles()
        files
            .filter(shouldReloadFile)
            .forEach(reloadFile)
        allEntries.sort()
    }

    private func findUsageFiles() -> [FileMetadata] {
        guard let allFiles = try? FileDiscovery.discoverFiles(in: basePath) else {
            return []
        }
        return FileDiscovery.filter(allFiles, by: FileFilters.modifiedWithin(hours: sessionWindowHours))
    }

    private func reloadFile(_ file: FileMetadata) {
        var fileHashes = Set<String>()
        let newEntries = parser.parseFile(
            at: file.path,
            project: file.projectName,
            processedHashes: &fileHashes
        )
        allEntries.removeAll { $0.sourceFile == file.path }
        allEntries.append(contentsOf: newEntries)
        lastFileTimestamps[file.path] = file.modificationDate
    }

    private func shouldReloadFile(_ file: FileMetadata) -> Bool {
        guard let lastTimestamp = lastFileTimestamps[file.path] else {
            return true
        }
        return file.modificationDate > lastTimestamp
    }

    // MARK: - Session Block Detection

    private func identifySessionBlocks() -> [SessionBlock] {
        guard !allEntries.isEmpty else { return [] }
        return groupEntriesIntoBlocks(allEntries)
    }

    private func groupEntriesIntoBlocks(_ entries: [UsageEntry]) -> [SessionBlock] {
        let entryGroups = splitAtSessionGaps(entries)
        return mapGroupsToBlocks(entryGroups)
    }

    private func splitAtSessionGaps(_ entries: [UsageEntry]) -> [[UsageEntry]] {
        guard !entries.isEmpty else { return [] }
        let splitIndices = findSplitIndices(in: entries)
        return partitionEntries(entries, at: splitIndices)
    }

    private func findSplitIndices(in entries: [UsageEntry]) -> [Int] {
        zip(entries, entries.dropFirst())
            .enumerated()
            .filter { hasSessionGap(from: $0.element.0, to: $0.element.1) }
            .map { $0.offset + 1 }
    }

    private func partitionEntries(_ entries: [UsageEntry], at splitIndices: [Int]) -> [[UsageEntry]] {
        let boundaries = [0] + splitIndices + [entries.count]
        return zip(boundaries, boundaries.dropFirst())
            .map { start, end in Array(entries[start..<end]) }
    }

    private func hasSessionGap(from previous: UsageEntry, to next: UsageEntry) -> Bool {
        next.timestamp.timeIntervalSince(previous.timestamp) > sessionDurationSeconds
    }

    private func mapGroupsToBlocks(_ groups: [[UsageEntry]]) -> [SessionBlock] {
        guard !groups.isEmpty else { return [] }
        let historicalBlocks = groups.dropLast().compactMap(createHistoricalBlock)
        let finalBlock = groups.last.flatMap(createFinalBlock)
        return historicalBlocks + [finalBlock].compactMap { $0 }
    }

    // MARK: - Block Creation Strategies

    /// Historical blocks are always inactive - they represent completed sessions
    /// Uses exact session start time (no windowing needed)
    private func createHistoricalBlock(entries: [UsageEntry]) -> SessionBlock? {
        guard let sessionStart = entries.first?.timestamp else { return nil }
        let displayTime = exactSessionStartTime(sessionStart)
        return createBlock(entries: entries, displayStartTime: displayTime, isActive: false)
    }

    /// Final block may be active if recent activity detected
    /// Active sessions use modulo windowing; inactive use exact time
    private func createFinalBlock(entries: [UsageEntry]) -> SessionBlock? {
        guard let sessionStart = entries.first?.timestamp else { return nil }
        let isActive = hasRecentActivity(entries: entries)
        let displayTime = isActive
            ? rollingWindowStartTime(from: sessionStart)
            : exactSessionStartTime(sessionStart)
        return createBlock(entries: entries, displayStartTime: displayTime, isActive: isActive)
    }

    private func hasRecentActivity(entries: [UsageEntry]) -> Bool {
        guard let lastEntryTime = entries.last?.timestamp else { return false }
        return Date().timeIntervalSince(lastEntryTime) < sessionDurationSeconds
    }

    // MARK: - Block Creation

    private func createBlock(entries: [UsageEntry], displayStartTime: Date, isActive: Bool) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        return SessionBlock(
            id: UUID().uuidString,
            startTime: displayStartTime,
            endTime: sessionWindowEndTime(from: displayStartTime),
            actualEndTime: entries.last?.timestamp,
            isActive: isActive,
            entries: entries,
            tokens: aggregateTokens(from: entries),
            costUSD: aggregateCost(from: entries),
            models: uniqueModels(from: entries),
            burnRate: calculateBurnRate(entries: entries)
        )
    }

    // MARK: - Time Calculation Strategies

    /// Exact time: used for historical/completed sessions
    /// Returns the actual session start timestamp unchanged
    private func exactSessionStartTime(_ sessionStart: Date) -> Date {
        sessionStart
    }

    /// Rolling window: used for active sessions
    /// Calculates start of current window using modulo arithmetic
    private func rollingWindowStartTime(from sessionStart: Date) -> Date {
        let totalDuration = Date().timeIntervalSince(sessionStart)
        let elapsedInCurrentWindow = totalDuration.truncatingRemainder(dividingBy: sessionDurationSeconds)
        return Date().addingTimeInterval(-elapsedInCurrentWindow)
    }

    private func sessionWindowEndTime(from startTime: Date) -> Date {
        startTime.addingTimeInterval(sessionDurationSeconds)
    }

    // MARK: - Pure Aggregations

    private func aggregateTokens(from entries: [UsageEntry]) -> TokenCounts {
        entries.reduce(TokenCounts.zero) { $0 + $1.tokens }
    }

    private func aggregateCost(from entries: [UsageEntry]) -> Double {
        entries.reduce(0.0) { $0 + $1.costUSD }
    }

    private func uniqueModels(from entries: [UsageEntry]) -> [String] {
        Array(Set(entries.map(\.model)))
    }

    // MARK: - Burn Rate Calculation

    private func calculateBurnRate(entries: [UsageEntry]) -> BurnRate {
        guard let duration = sessionDuration(from: entries), duration > TimeConstants.minimumDuration else {
            return .zero
        }
        return buildBurnRate(entries: entries, duration: duration)
    }

    private func buildBurnRate(entries: [UsageEntry], duration: TimeInterval) -> BurnRate {
        BurnRate(
            tokensPerMinute: Int(Double(aggregateTotalTokens(from: entries)) / duration.minutes),
            costPerHour: aggregateCost(from: entries) / duration.hours
        )
    }

    private func sessionDuration(from entries: [UsageEntry]) -> TimeInterval? {
        guard let first = entries.first, let last = entries.last, entries.count >= 2 else {
            return nil
        }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }

    private func aggregateTotalTokens(from entries: [UsageEntry]) -> Int {
        entries.reduce(0) { $0 + $1.totalTokens }
    }

    // MARK: - Block Queries

    private func maxTokensFromCompletedBlocks(_ blocks: [SessionBlock]) -> Int {
        blocks
            .filter { !$0.isActive }
            .map(\.tokens.total)
            .max() ?? 0
    }

    private func mostRecentActiveBlock(from blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { ($0.actualEndTime ?? $0.startTime) < ($1.actualEndTime ?? $1.startTime) }
    }

    // MARK: - Time Constants

    private var sessionDurationSeconds: TimeInterval {
        sessionDurationHours * TimeConstants.secondsPerHour
    }

    private var sessionWindowHours: Double {
        sessionDurationHours * TimeConstants.sessionWindowMultiplier
    }
}

// MARK: - Cache Validation

private func isCacheValid(timestamp: Date, ttl: TimeInterval = CacheConfig.ttl) -> Bool {
    Date().timeIntervalSince(timestamp) < ttl
}

private enum CacheConfig {
    static let ttl: TimeInterval = 2.0
}

// MARK: - Time Constants

private enum TimeConstants {
    static let secondsPerHour: TimeInterval = 3600
    static let secondsPerMinute: TimeInterval = 60
    static let minimumDuration: TimeInterval = 60
    static let sessionWindowMultiplier: Double = 2
}

// MARK: - TimeInterval Helpers

private extension TimeInterval {
    var minutes: Double { self / TimeConstants.secondsPerMinute }
    var hours: Double { self / TimeConstants.secondsPerHour }
}
