//
//  UsageDataLoaderTests.swift
//  ClaudeUsageTests
//

import Testing
import Foundation
@testable import ClaudeUsage
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("UsageDataLoader")
struct UsageDataLoaderTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    private func createLoader() -> UsageDataLoader {
        let repository = UsageRepository(basePath: basePath)
        let sessionService = DefaultSessionMonitorService(configuration: .default)
        return UsageDataLoader(repository: repository, sessionMonitorService: sessionService)
    }

    // MARK: - Phase 1: Today Loading

    @Test("Phase 1 returns valid result structure")
    func phase1ReturnsValidStructure() async throws {
        let loader = createLoader()
        let result = try await loader.loadToday()

        #expect(result.todayEntries.count >= 0)
        #expect(result.todayStats.totalCost >= 0)
        #expect(result.todayStats.totalTokens >= 0)

        // Verify aggregation matches entries
        let entryCostSum = result.todayEntries.reduce(0.0) { $0 + $1.costUSD }
        #expect(abs(result.todayStats.totalCost - entryCostSum) < 0.01)
    }

    @Test("Phase 1 completes within 3 seconds", .timeLimit(.minutes(1)))
    func phase1CompletesQuickly() async throws {
        let loader = createLoader()

        let start = Date()
        _ = try await loader.loadToday()
        let duration = Date().timeIntervalSince(start)

        #expect(duration < 3.0, "Phase 1 is user-facing critical path")
    }

    // MARK: - Phase 2: History Loading

    @Test("Phase 2 returns valid result structure")
    func phase2ReturnsValidStructure() async throws {
        let loader = createLoader()
        let result = try await loader.loadHistory()

        #expect(result.fullStats.totalCost >= 0)
        #expect(result.fullStats.byDate.count >= 0)
    }

    @Test("Phase 2 completes within 10 seconds", .timeLimit(.minutes(1)))
    func phase2CompletesWithinBounds() async throws {
        let loader = createLoader()

        let start = Date()
        _ = try await loader.loadHistory()
        let duration = Date().timeIntervalSince(start)

        #expect(duration < 10.0, "Phase 2 runs in background but should be bounded")
    }

    // MARK: - Combined Loading

    @Test("loadAll combines phases correctly")
    func loadAllCombinesPhases() async throws {
        let loader = createLoader()
        let result = try await loader.loadAll()

        // Today's cost should never exceed total historical cost
        #expect(result.todayStats.totalCost <= result.fullStats.totalCost + 0.01)

        // Today's tokens should never exceed total
        #expect(result.todayStats.totalTokens <= result.fullStats.totalTokens)
    }

    // MARK: - Warm Cache Performance

    @Test("warm cache refresh is fast")
    func warmCacheRefreshIsFast() async throws {
        let loader = createLoader()

        // Cold load
        _ = try await loader.loadToday()

        // Warm load should be faster
        let start = Date()
        _ = try await loader.loadToday()
        let warmDuration = Date().timeIntervalSince(start)

        #expect(warmDuration < 1.0, "Cached refresh should be under 1 second")
    }
}
