//
//  SessionMonitor.swift
//  ClaudeUsageData
//
//  Monitor for detecting active Claude sessions
//

import Foundation
import ClaudeUsageCore

// MARK: - SessionMonitor

public actor SessionMonitor: SessionDataSource {
    private let basePath: String
    private let sessionDurationHours: Double
    private let parser = JSONLParser()

    private var lastFileTimestamps: [String: Date] = [:]
    private var allEntries: [UsageEntry] = []
    private var cachedTokenLimit: Int = 0

    public init(basePath: String = NSHomeDirectory() + "/.claude", sessionDurationHours: Double = 5.0) {
        self.basePath = basePath
        self.sessionDurationHours = sessionDurationHours
    }

    // MARK: - SessionDataSource

    public func getActiveSession() async -> SessionBlock? {
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
        return FileDiscovery.filterFilesModifiedWithin(allFiles, hours: sessionWindowHours)
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
        var blocks: [SessionBlock] = []
        var currentEntries: [UsageEntry] = []
        var blockStart: Date?

        for entry in entries {
            if let start = blockStart {
                if hasSessionGap(from: currentEntries.last, to: entry) {
                    appendBlock(entries: currentEntries, startTime: start, isActive: false, to: &blocks)
                    currentEntries = [entry]
                    blockStart = entry.timestamp
                } else {
                    currentEntries.append(entry)
                }
            } else {
                blockStart = entry.timestamp
                currentEntries = [entry]
            }
        }

        appendFinalBlock(entries: currentEntries, startTime: blockStart, to: &blocks)
        return blocks
    }

    private func hasSessionGap(from lastEntry: UsageEntry?, to entry: UsageEntry) -> Bool {
        guard let lastEntry else { return false }
        let gap = entry.timestamp.timeIntervalSince(lastEntry.timestamp)
        return gap > sessionDurationSeconds
    }

    private func appendBlock(
        entries: [UsageEntry],
        startTime: Date,
        isActive: Bool,
        to blocks: inout [SessionBlock]
    ) {
        if let block = createBlock(entries: entries, startTime: startTime, isActive: isActive) {
            blocks.append(block)
        }
    }

    private func appendFinalBlock(
        entries: [UsageEntry],
        startTime: Date?,
        to blocks: inout [SessionBlock]
    ) {
        guard let start = startTime, !entries.isEmpty else { return }
        let isActive = isFinalBlockActive(entries: entries)
        appendBlock(entries: entries, startTime: start, isActive: isActive, to: &blocks)
    }

    private func isFinalBlockActive(entries: [UsageEntry]) -> Bool {
        guard let lastEntryTime = entries.last?.timestamp else { return false }
        return Date().timeIntervalSince(lastEntryTime) < sessionDurationSeconds
    }

    // MARK: - Block Creation

    private func createBlock(entries: [UsageEntry], startTime: Date, isActive: Bool) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        let tokens = entries.reduce(TokenCounts.zero) { $0 + $1.tokens }
        let cost = entries.reduce(0.0) { $0 + $1.costUSD }
        let models = Array(Set(entries.map(\.model)))
        let actualEndTime = entries.last?.timestamp
        let endTime = computeEndTime(isActive: isActive, actualEndTime: actualEndTime, startTime: startTime)

        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: actualEndTime,
            isActive: isActive,
            entries: entries,
            tokens: tokens,
            costUSD: cost,
            models: models,
            burnRate: calculateBurnRate(entries: entries)
        )
    }

    private func computeEndTime(isActive: Bool, actualEndTime: Date?, startTime: Date) -> Date {
        isActive
            ? Date().addingTimeInterval(sessionDurationSeconds)
            : (actualEndTime ?? startTime)
    }

    // MARK: - Burn Rate Calculation

    private func calculateBurnRate(entries: [UsageEntry]) -> BurnRate {
        guard let duration = sessionDuration(from: entries), duration > TimeConstants.minimumDuration else {
            return .zero
        }

        let totalTokens = entries.reduce(0) { $0 + $1.totalTokens }
        let totalCost = entries.reduce(0.0) { $0 + $1.costUSD }

        return BurnRate(
            tokensPerMinute: Int(Double(totalTokens) / duration.minutes),
            costPerHour: totalCost / duration.hours
        )
    }

    private func sessionDuration(from entries: [UsageEntry]) -> TimeInterval? {
        guard entries.count >= 2,
              let first = entries.first,
              let last = entries.last else {
            return nil
        }
        return last.timestamp.timeIntervalSince(first.timestamp)
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
