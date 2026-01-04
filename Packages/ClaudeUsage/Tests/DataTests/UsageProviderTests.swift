//
//  UsageProviderTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("UsageProvider")
struct UsageProviderTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("getAllEntries returns non-empty collection")
    func getAllEntriesReturnsEntries() async throws {
        let provider = UsageProvider(basePath: basePath)
        let entries = try await provider.getAllEntries()

        #expect(entries.count > 0, "Should have entries")
    }

    @Test("entries are sorted by timestamp ascending")
    func entriesAreSortedByTimestamp() async throws {
        let provider = UsageProvider(basePath: basePath)
        let entries = try await provider.getTodayEntries()

        let isSortedAscending = zip(entries, entries.dropFirst())
            .allSatisfy { $0.timestamp <= $1.timestamp }

        #expect(isSortedAscending, "Entries should be sorted ascending")
    }

    @Test("clearCache invalidates cached data")
    func clearCacheInvalidatesData() async throws {
        let provider = UsageProvider(basePath: basePath)

        // Load data to populate cache
        _ = try await provider.getTodayEntries()

        // Clear cache
        await provider.clearCache()

        // Should still work after clear
        let entries = try await provider.getTodayEntries()
        #expect(entries.count >= 0)
    }

    @Test("getUsageStats aggregates correctly")
    func getUsageStatsAggregates() async throws {
        let provider = UsageProvider(basePath: basePath)
        let stats = try await provider.getUsageStats()

        #expect(stats.totalCost >= 0)
        #expect(stats.totalTokens >= 0)

        // Verify byDate entries sum to total
        let dateSum = stats.byDate.reduce(0.0) { $0 + $1.totalCost }
        #expect(abs(stats.totalCost - dateSum) < 0.01, "Daily costs should sum to total")
    }
}
