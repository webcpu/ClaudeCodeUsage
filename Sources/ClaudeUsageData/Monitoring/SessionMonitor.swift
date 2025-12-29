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
    private var processedHashes = Set<String>()
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
        return mostRecentActiveBlock(from: blocks)
    }

    public func getBurnRate() async -> BurnRate? {
        await getActiveSession()?.burnRate
    }

    public func getAutoTokenLimit() async -> Int? {
        _ = await getActiveSession()
        return cachedTokenLimit > 0 ? cachedTokenLimit : nil
    }

    // MARK: - File Loading

    private func loadModifiedFiles() {
        let files = findUsageFiles()

        for file in files {
            guard shouldReloadFile(file) else { continue }

            var localHashes = processedHashes
            let entries = parser.parseFile(
                at: file.path,
                project: file.projectName,
                processedHashes: &localHashes
            )
            processedHashes = localHashes

            allEntries.append(contentsOf: entries)
            lastFileTimestamps[file.path] = file.modificationDate
        }

        allEntries.sort()
    }

    private func findUsageFiles() -> [FileMetadata] {
        (try? FileDiscovery.discoverFiles(in: basePath)) ?? []
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

        let sessionDuration = sessionDurationHours * 3600
        var blocks: [SessionBlock] = []
        var currentBlockEntries: [UsageEntry] = []
        var blockStartTime: Date?

        for entry in allEntries {
            if let start = blockStartTime {
                let gap = entry.timestamp.timeIntervalSince(currentBlockEntries.last?.timestamp ?? start)
                if gap > sessionDuration {
                    // End current block, start new one
                    if let block = createBlock(entries: currentBlockEntries, startTime: start, isActive: false) {
                        blocks.append(block)
                    }
                    currentBlockEntries = [entry]
                    blockStartTime = entry.timestamp
                } else {
                    currentBlockEntries.append(entry)
                }
            } else {
                blockStartTime = entry.timestamp
                currentBlockEntries = [entry]
            }
        }

        // Handle final block
        if let start = blockStartTime, !currentBlockEntries.isEmpty {
            let lastEntryTime = currentBlockEntries.last?.timestamp ?? start
            let isActive = Date().timeIntervalSince(lastEntryTime) < sessionDuration
            if let block = createBlock(entries: currentBlockEntries, startTime: start, isActive: isActive) {
                blocks.append(block)
            }
        }

        return blocks
    }

    private func createBlock(entries: [UsageEntry], startTime: Date, isActive: Bool) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        let tokens = entries.reduce(TokenCounts.zero) { $0 + $1.tokens }
        let cost = entries.reduce(0.0) { $0 + $1.costUSD }
        let models = Array(Set(entries.map(\.model)))
        let actualEndTime = entries.last?.timestamp

        let burnRate = calculateBurnRate(entries: entries)
        let endTime = isActive
            ? Date().addingTimeInterval(sessionDurationHours * 3600)
            : (actualEndTime ?? startTime)

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
            burnRate: burnRate,
            tokenLimit: cachedTokenLimit > 0 ? cachedTokenLimit : nil
        )
    }

    private func calculateBurnRate(entries: [UsageEntry]) -> BurnRate {
        guard entries.count >= 2,
              let first = entries.first,
              let last = entries.last else {
            return .zero
        }

        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        guard duration > 60 else { return .zero }  // Need at least 1 minute

        let totalTokens = entries.reduce(0) { $0 + $1.totalTokens }
        let totalCost = entries.reduce(0.0) { $0 + $1.costUSD }

        let minutes = duration / 60.0
        let tokensPerMinute = Int(Double(totalTokens) / minutes)
        let costPerHour = (totalCost / duration) * 3600

        return BurnRate(tokensPerMinute: tokensPerMinute, costPerHour: costPerHour)
    }

    // MARK: - Helpers

    private func maxTokensFromCompletedBlocks(_ blocks: [SessionBlock]) -> Int {
        blocks
            .filter { !$0.isActive }
            .map { $0.tokens.total }
            .max() ?? 0
    }

    private func mostRecentActiveBlock(from blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { ($0.actualEndTime ?? $0.startTime) < ($1.actualEndTime ?? $1.startTime) }
    }

    // MARK: - Cache Management

    public func clearCache() {
        lastFileTimestamps.removeAll()
        processedHashes.removeAll()
        allEntries.removeAll()
        cachedTokenLimit = 0
    }
}
