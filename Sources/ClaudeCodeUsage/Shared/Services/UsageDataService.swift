//
//  UsageDataService.swift
//  Service for loading usage data and statistics
//

import Foundation
import ClaudeCodeUsageKit

// MARK: - Protocol

protocol UsageDataService {
    func loadStats() async throws -> UsageStats
    func loadEntries() async throws -> [UsageEntry]
    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
    func getDateRange() -> (start: Date, end: Date)
}

// MARK: - Default Implementation

final class DefaultUsageDataService: UsageDataService {
    private let client: ClaudeUsageClient

    init(configuration: AppConfiguration) {
        self.client = ClaudeUsageClient(
            dataSource: .localFiles(basePath: configuration.basePath)
        )
    }

    func loadStats() async throws -> UsageStats {
        let startTime = Date()
        let range = getDateRange()
        let result = try await client.getUsageByDateRange(
            startDate: range.start,
            endDate: range.end
        )
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadStats completed in \(String(format: "%.3f", duration))s")
        #endif
        return result
    }

    func loadEntries() async throws -> [UsageEntry] {
        let startTime = Date()
        let result = try await client.getUsageDetails()
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntries completed in \(String(format: "%.3f", duration))s - \(result.count) entries")
        #endif
        return result
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let startTime = Date()
        let entries = try await client.getUsageDetails()

        #if DEBUG
        let entriesTime = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntriesAndStats - entries loaded in \(String(format: "%.3f", entriesTime))s - \(entries.count) entries")
        #endif

        let aggregator = StatisticsAggregator()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)

        #if DEBUG
        let totalTime = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntriesAndStats completed in \(String(format: "%.3f", totalTime))s")
        #endif

        return (entries, stats)
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let startTime = Date()
        let entries = try await client.getTodayUsageEntries()

        let aggregator = StatisticsAggregator()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)

        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadTodayEntriesAndStats completed in \(String(format: "%.3f", duration))s - \(entries.count) entries")
        #endif

        return (entries, stats)
    }

    func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }
}

// MARK: - Mock for Testing

#if DEBUG
public final class MockUsageDataService: UsageDataService {
    public var mockStats: UsageStats?
    public var mockEntries: [UsageEntry] = []
    public var shouldThrow = false

    public init() {}

    public func loadStats() async throws -> UsageStats {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats provided"])
        }
        return stats
    }

    public func loadEntries() async throws -> [UsageEntry] {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        return mockEntries
    }

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
        return try await loadEntriesAndStats()
    }

    public func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }
}
#endif
