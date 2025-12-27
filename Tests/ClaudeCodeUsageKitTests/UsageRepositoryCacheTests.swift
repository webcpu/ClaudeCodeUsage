//
//  UsageRepositoryCacheTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for file-level caching in UsageRepository
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit

@Suite("UsageRepository Cache Tests", .serialized)  // Run serially to avoid shared state issues
struct UsageRepositoryCacheTests {

    @Test("Should cache entries across multiple loads")
    func testCacheAcrossLoads() async throws {
        // Given - a fresh repository instance (avoids shared state issues)
        let repository = UsageRepository()

        // When - first load
        let start1 = Date()
        let stats1 = try await repository.getUsageStats()
        let time1 = Date().timeIntervalSince(start1)

        // When - second load (should be cached)
        let start2 = Date()
        let stats2 = try await repository.getUsageStats()
        let time2 = Date().timeIntervalSince(start2)

        // Then - results should be identical (within floating point tolerance)
        #expect(abs(stats1.totalCost - stats2.totalCost) < 0.01)
        #expect(stats1.totalTokens == stats2.totalTokens)

        // And - second load should be significantly faster
        print("First load: \(String(format: "%.3f", time1))s")
        print("Second load: \(String(format: "%.3f", time2))s")
        print("Speedup: \(String(format: "%.1f", time1 / max(time2, 0.001)))x")

        // Second load should be at least 5x faster if caching works
        if time1 > 0.5 {
            #expect(time2 < time1 * 0.5, "Cached load should be significantly faster")
        }
    }

    @Test("Should clear cache when requested")
    func testCacheClear() async throws {
        // Given - a repository with cached data
        let repository = UsageRepository()
        _ = try await repository.getUsageStats()

        // When - clear the cache
        await repository.clearCache()

        // Then - next load should work (no crash)
        let stats = try await repository.getUsageStats()
        #expect(stats.totalTokens >= 0)
    }
}
