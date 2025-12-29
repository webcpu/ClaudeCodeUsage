//
//  UsageRepositoryTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("UsageRepository")
struct UsageRepositoryTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("initializes with custom base path")
    func initializesWithCustomPath() async {
        let repo = UsageRepository(basePath: basePath)
        #expect(await repo.basePath == basePath)
    }

    @Test("getTodayEntries returns entries")
    func getTodayEntriesReturnsEntries() async throws {
        let repo = UsageRepository(basePath: basePath)

        let start = Date()
        let entries = try await repo.getTodayEntries()
        let duration = Date().timeIntervalSince(start)

        print("getTodayEntries():")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Entries: \(entries.count)")

        if !entries.isEmpty {
            let totalCost = entries.reduce(0.0) { $0 + $1.costUSD }
            print("  Total cost: $\(String(format: "%.2f", totalCost))")
        }
    }

    @Test("getUsageStats returns aggregated stats")
    func getUsageStatsReturnsStats() async throws {
        let repo = UsageRepository(basePath: basePath)

        let start = Date()
        let stats = try await repo.getUsageStats()
        let duration = Date().timeIntervalSince(start)

        print("getUsageStats():")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Total cost: $\(String(format: "%.2f", stats.totalCost))")
        print("  Total tokens: \(stats.totalTokens)")
        print("  Days with usage: \(stats.byDate.count)")
    }

    @Test("getAllEntries returns all entries")
    func getAllEntriesReturnsAll() async throws {
        let repo = UsageRepository(basePath: basePath)

        let start = Date()
        let entries = try await repo.getAllEntries()
        let duration = Date().timeIntervalSince(start)

        print("getAllEntries():")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Entries: \(entries.count)")

        #expect(entries.count > 0, "Should have entries")
    }

    @Test("measures repository caching")
    func measuresRepositoryCaching() async throws {
        let repo = UsageRepository(basePath: basePath)

        // First call - cold
        let start1 = Date()
        _ = try await repo.getTodayEntries()
        let cold = Date().timeIntervalSince(start1)

        // Second call - warm (file cache populated)
        let start2 = Date()
        _ = try await repo.getTodayEntries()
        let warm = Date().timeIntervalSince(start2)

        print("Repository caching:")
        print("  Cold: \(String(format: "%.3f", cold))s")
        print("  Warm: \(String(format: "%.3f", warm))s")
        print("  Speedup: \(String(format: "%.1f", cold / warm))x")

        #expect(warm < cold, "Cached call should be faster")
    }

    @Test("clearCache invalidates file cache")
    func clearCacheInvalidatesFileCache() async throws {
        let repo = UsageRepository(basePath: basePath)

        // Load data
        _ = try await repo.getTodayEntries()

        // Clear cache
        await repo.clearCache()

        // Measure reload
        let start = Date()
        let entries = try await repo.getTodayEntries()
        let duration = Date().timeIntervalSince(start)

        print("After clearCache:")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Entries: \(entries.count)")
    }

    @Test("entries are sorted by timestamp")
    func entriesAreSortedByTimestamp() async throws {
        let repo = UsageRepository(basePath: basePath)
        let entries = try await repo.getTodayEntries()

        guard entries.count >= 2 else {
            print("Not enough entries to verify sorting")
            return
        }

        var isSorted = true
        for i in 1..<entries.count {
            if entries[i].timestamp < entries[i-1].timestamp {
                isSorted = false
                break
            }
        }

        #expect(isSorted, "Entries should be sorted by timestamp")
        print("Sorting verified for \(entries.count) entries")
    }
}
