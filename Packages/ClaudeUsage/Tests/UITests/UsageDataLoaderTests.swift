//
//  UsageDataLoaderTests.swift
//  ClaudeUsageTests
//

import Testing
import Foundation
@testable import ClaudeUsage

// MARK: - Pure Functions

private func sumEntryCosts(_ entries: [UsageEntry]) -> Double {
    entries.reduce(0.0) { $0 + $1.costUSD }
}

private func isWithinTolerance(_ actual: Double, expected: Double, tolerance: Double = 0.01) -> Bool {
    abs(actual - expected) < tolerance
}

private func measureDuration(_ operation: () async throws -> Void) async rethrows -> TimeInterval {
    let start = Date()
    try await operation()
    return Date().timeIntervalSince(start)
}

// MARK: - Test Suite

@Suite("UsageDataLoader")
struct UsageDataLoaderTests {

    // MARK: - Factory

    private func createLoader() -> UsageDataLoader {
        let basePath = NSHomeDirectory() + "/.claude"
        let repository = UsageRepository(basePath: basePath)
        let sessionRepository = SessionRepository(basePath: basePath)
        return UsageDataLoader(repository: repository, sessionDataSource: sessionRepository)
    }

    // MARK: - Phase 1: Today Loading

    @Test("Phase 1 returns valid result structure")
    func phase1ReturnsValidStructure() async throws {
        let result = try await createLoader().loadToday()

        try assertTodayResultIsValid(result)
        try assertAggregationMatchesEntries(result)
    }

    @Test("Phase 1 completes within 3 seconds", .timeLimit(.minutes(1)))
    func phase1CompletesQuickly() async throws {
        let loader = createLoader()

        let duration = try await measureDuration {
            _ = try await loader.loadToday()
        }

        #expect(duration < 3.0, "Phase 1 is user-facing critical path")
    }

    // MARK: - Phase 2: History Loading

    @Test("Phase 2 returns valid result structure")
    func phase2ReturnsValidStructure() async throws {
        let result = try await createLoader().loadHistory()

        try assertHistoryResultIsValid(result)
    }

    @Test("Phase 2 completes within 10 seconds", .timeLimit(.minutes(1)))
    func phase2CompletesWithinBounds() async throws {
        let loader = createLoader()

        let duration = try await measureDuration {
            _ = try await loader.loadHistory()
        }

        #expect(duration < 10.0, "Phase 2 runs in background but should be bounded")
    }

    // MARK: - Combined Loading

    @Test("loadAll combines phases correctly")
    func loadAllCombinesPhases() async throws {
        let result = try await createLoader().loadAll()

        try assertTodayNeverExceedsTotal(result)
    }

    // MARK: - Warm Cache Performance

    @Test("warm cache refresh is fast")
    func warmCacheRefreshIsFast() async throws {
        let loader = createLoader()

        _ = try await loader.loadToday()

        let warmDuration = try await measureDuration {
            _ = try await loader.loadToday()
        }

        #expect(warmDuration < 1.0, "Cached refresh should be under 1 second")
    }
}

// MARK: - Assertion Helpers

extension UsageDataLoaderTests {

    private func assertTodayResultIsValid(_ result: TodayLoadResult) throws {
        #expect(result.todayEntries.count >= 0)
        #expect(result.todayStats.totalCost >= 0)
        #expect(result.todayStats.totalTokens >= 0)
    }

    private func assertAggregationMatchesEntries(_ result: TodayLoadResult) throws {
        let entryCostSum = sumEntryCosts(result.todayEntries)
        #expect(
            isWithinTolerance(result.todayStats.totalCost, expected: entryCostSum),
            "Aggregated cost should match sum of entry costs"
        )
    }

    private func assertHistoryResultIsValid(_ result: FullLoadResult) throws {
        #expect(result.fullStats.totalCost >= 0)
        #expect(result.fullStats.byDate.count >= 0)
    }

    private func assertTodayNeverExceedsTotal(_ result: UsageLoadResult) throws {
        #expect(
            result.todayStats.totalCost <= result.fullStats.totalCost + 0.01,
            "Today's cost should never exceed total historical cost"
        )
        #expect(
            result.todayStats.totalTokens <= result.fullStats.totalTokens,
            "Today's tokens should never exceed total"
        )
    }
}
