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
        try await timed("loadStats") {
            let range = getDateRange()
            return try await client.getUsageByDateRange(startDate: range.start, endDate: range.end)
        }
    }

    func loadEntries() async throws -> [UsageEntry] {
        try await timed("loadEntries") { [client] in
            try await client.getUsageDetails()
        }
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        try await timed("loadEntriesAndStats") { [client] in
            let entries = try await client.getUsageDetails()
            return (entries, aggregateStats(from: entries))
        }
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        try await timed("loadTodayEntriesAndStats") { [client] in
            let entries = try await client.getTodayUsageEntries()
            return (entries, aggregateStats(from: entries))
        }
    }

    func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }
}

// MARK: - Pure Transformations

private func aggregateStats(from entries: [UsageEntry]) -> UsageStats {
    let sessionCount = countUniqueSessions(in: entries)
    return StatisticsAggregator().aggregateStatistics(from: entries, sessionCount: sessionCount)
}

private func countUniqueSessions(in entries: [UsageEntry]) -> Int {
    Set(entries.compactMap(\.sessionId)).count
}

// MARK: - Debug Timing

private func timed<T>(_ label: String, operation: () async throws -> T) async rethrows -> T {
    #if DEBUG
    let start = Date()
    let result = try await operation()
    let duration = Date().timeIntervalSince(start)
    print("[UsageDataService] \(label) completed in \(String(format: "%.3f", duration))s")
    return result
    #else
    return try await operation()
    #endif
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
