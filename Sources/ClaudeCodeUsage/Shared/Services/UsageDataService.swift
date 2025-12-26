//
//  UsageDataService.swift
//  Service for loading usage data and statistics
//

import Foundation
import ClaudeCodeUsageKit

// MARK: - Protocol

protocol UsageDataService {
    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
}

// MARK: - Default Implementation

final class DefaultUsageDataService: UsageDataService {
    private let client: ClaudeUsageClient

    init(configuration: AppConfiguration) {
        self.client = ClaudeUsageClient(
            dataSource: .localFiles(basePath: configuration.basePath)
        )
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let entries = try await client.getUsageDetails()
        let stats = aggregateStats(from: entries)
        return (entries, stats)
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let entries = try await client.getTodayUsageEntries()
        let stats = aggregateStats(from: entries)
        return (entries, stats)
    }
}

// MARK: - Pure Transformations

private func aggregateStats(from entries: [UsageEntry]) -> UsageStats {
    let sessionCount = Set(entries.compactMap(\.sessionId)).count
    return StatisticsAggregator().aggregateStatistics(from: entries, sessionCount: sessionCount)
}

// MARK: - Mock for Testing

#if DEBUG
public final class MockUsageDataService: UsageDataService {
    public var mockStats: UsageStats?
    public var mockEntries: [UsageEntry] = []
    public var shouldThrow = false

    public init() {}

    public func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats provided"])
        }
        return (mockEntries, stats)
    }

    public func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        try await loadEntriesAndStats()
    }
}
#endif
