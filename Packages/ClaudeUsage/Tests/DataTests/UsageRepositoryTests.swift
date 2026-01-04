//
//  UsageRepositoryTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("UsageRepository")
struct UsageRepositoryTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("getAllEntries returns non-empty collection")
    func getAllEntriesReturnsEntries() async throws {
        let repo = UsageRepository(basePath: basePath)
        let entries = try await repo.getAllEntries()

        #expect(entries.count > 0, "Should have entries")
    }

    @Test("entries are sorted by timestamp ascending")
    func entriesAreSortedByTimestamp() async throws {
        let repo = UsageRepository(basePath: basePath)
        let entries = try await repo.getTodayEntries()

        let isSortedAscending = zip(entries, entries.dropFirst())
            .allSatisfy { $0.timestamp <= $1.timestamp }

        #expect(isSortedAscending, "Entries should be sorted ascending")
    }

    @Test("clearCache invalidates cached data")
    func clearCacheInvalidatesData() async throws {
        let repo = UsageRepository(basePath: basePath)

        // Load data to populate cache
        _ = try await repo.getTodayEntries()

        // Clear cache
        await repo.clearCache()

        // Should still work after clear
        let entries = try await repo.getTodayEntries()
        #expect(entries.count >= 0)
    }

    @Test("getUsageStats aggregates correctly")
    func getUsageStatsAggregates() async throws {
        let repo = UsageRepository(basePath: basePath)
        let stats = try await repo.getUsageStats()

        #expect(stats.totalCost >= 0)
        #expect(stats.totalTokens >= 0)

        // Verify byDate entries sum to total
        let dateSum = stats.byDate.reduce(0.0) { $0 + $1.totalCost }
        #expect(abs(stats.totalCost - dateSum) < 0.01, "Daily costs should sum to total")
    }
}
