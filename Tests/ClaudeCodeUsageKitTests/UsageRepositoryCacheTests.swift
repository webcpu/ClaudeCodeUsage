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

    @Test("Should detect modified files even after day rollover")
    func testModifiedFileDetectionAfterDayRollover() async throws {
        // This test verifies the fix for: "today's cost becomes $0 after day rollover"
        // Bug scenario:
        // 1. Day 1: File cached with modDate = Day 1
        // 2. Day 2: File modified but cache still returns stale Day 1 metadata
        // 3. filterFilesModifiedToday filters out the file → $0 cost

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UsageRepoTest-\(UUID().uuidString)")
        let projectsDir = tempDir.appendingPathComponent("projects")
        let projectDir = projectsDir.appendingPathComponent("test-project")

        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let repository = UsageRepository(basePath: tempDir.path)
        let sessionFile = projectDir.appendingPathComponent("test-session.jsonl")

        // Create initial entry (simulates Day 1 usage)
        let entry1 = createUsageEntry(cost: 5.0, timestamp: ISO8601DateFormatter().string(from: Date()))
        try entry1.write(to: sessionFile, atomically: true, encoding: .utf8)

        // First load - populates cache
        let stats1 = try await repository.getUsageStats()
        #expect(abs(stats1.totalCost - 5.0) < 0.01, "First load should see $5.00")

        // Simulate file modification (Day 2 - file completely replaced with new entry)
        // This simulates the real bug: cached file is modified, repository must detect it
        try await Task.sleep(for: .milliseconds(100))  // Ensure modification time changes
        let entry2 = createUsageEntry(cost: 20.0, timestamp: ISO8601DateFormatter().string(from: Date()))
        try entry2.write(to: sessionFile, atomically: true, encoding: .utf8)

        // Second load - should detect file modification and re-read the NEW content
        let stats2 = try await repository.getUsageStats()
        #expect(abs(stats2.totalCost - 20.0) < 0.01, "Should see new entry ($20.00) after file modification")
    }

    private func createUsageEntry(cost: Double, timestamp: String) -> String {
        """
        {"timestamp":"\(timestamp)","sessionId":"test-session","requestId":"req-\(UUID().uuidString)","message":{"id":"msg-\(UUID().uuidString)","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":1000,"output_tokens":500}},"costUSD":\(cost)}
        """
    }
}
