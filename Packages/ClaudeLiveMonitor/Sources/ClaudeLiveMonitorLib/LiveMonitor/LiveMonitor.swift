//
//  LiveMonitor.swift
//
//  Manages reading and processing of Claude usage files with thread-safe access.
//  Split into extensions for focused responsibilities:
//    - +FileOperations: File discovery and loading
//    - +SessionBlocks: Session block identification, creation, and calculations
//

import Foundation

// MARK: - Live Monitor

/// LiveMonitor manages the reading and processing of Claude usage files.
/// Uses Swift actor for thread-safe access - no manual locking needed.
public actor LiveMonitor {
    let config: LiveMonitorConfig
    var lastFileTimestamps: [String: Date] = [:]
    var processedHashes: Set<String> = Set()
    var allEntries: [UsageEntry] = []
    var maxTokensFromPreviousSessions: Int = 0
    let parser = JSONLParser()

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

    // MARK: - Block Selection

    func maxTokensFromCompletedBlocks(_ blocks: [SessionBlock]) -> Int {
        blocks
            .filter { !$0.isActive && !$0.isGap }
            .map(\.tokenCounts.total)
            .max() ?? 0
    }

    func mostRecentActiveBlock(from blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { ($0.actualEndTime ?? $0.startTime) < ($1.actualEndTime ?? $1.startTime) }
    }
}

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
