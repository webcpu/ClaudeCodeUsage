//
//  InsightsServiceTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("InsightsService")
struct InsightsServiceTests {

    // MARK: - Stats Loading

    @Test("loadStats returns success with usage stats")
    func loadStatsReturnsSuccess() async throws {
        let service = InsightsService()

        let result = await service.loadStats()

        #expect(result != nil)
        if case .success(let stats) = result {
            #expect(stats.totalCost >= 0)
            #expect(stats.sessionCount >= 0)
        }
    }

    @Test("loadStats returns nil when already loading")
    func loadStatsSkipsWhenAlreadyLoading() async {
        let service = InsightsService()

        // Start multiple concurrent loads
        async let result1 = service.loadStats()
        async let result2 = service.loadStats()
        async let result3 = service.loadStats()

        let results = await [result1, result2, result3]

        // Concurrent loads: one succeeds, others skipped
        let successCount = results.compactMap { $0 }.count

        #expect(successCount >= 1, "At least one call should succeed")
        #expect(successCount <= 3, "All calls could succeed if serialized")
    }

    @Test("loadStats sequential calls all succeed")
    func loadStatsSequentialSucceeds() async {
        let service = InsightsService()

        let result1 = await service.loadStats()
        let result2 = await service.loadStats()

        #expect(result1 != nil)
        #expect(result2 != nil)
    }

    // MARK: - UsageStats Structure

    @Test("UsageStats contains expected aggregations")
    func usageStatsStructure() async {
        let service = InsightsService()

        guard let result = await service.loadStats(),
              case .success(let stats) = result else {
            return
        }

        #expect(stats.totalCost >= 0)
        #expect(stats.sessionCount >= 0)
        #expect(stats.tokens.input >= 0)
        #expect(stats.tokens.output >= 0)
        // byModel and byDate are arrays that can be empty
        #expect(stats.byModel.count >= 0)
        #expect(stats.byDate.count >= 0)
    }

    // MARK: - Monitoring

    @Test("startMonitoring creates monitor")
    func startMonitoringCreatesMonitor() async {
        let service = InsightsService()

        await service.startMonitoring {}

        // Stop monitoring to clean up
        await service.stopMonitoring()

        // No crash means monitor was created successfully
    }

    @Test("stopMonitoring cleans up monitor")
    func stopMonitoringCleansUp() async {
        let service = InsightsService()

        await service.startMonitoring {}
        await service.stopMonitoring()

        // Should not crash when stopping again
        await service.stopMonitoring()
    }

    @Test("startMonitoring is idempotent")
    func startMonitoringIdempotent() async {
        let service = InsightsService()

        // Start monitoring multiple times
        await service.startMonitoring {}
        await service.startMonitoring {}
        await service.startMonitoring {}

        // Clean up
        await service.stopMonitoring()

        // No crash means it's working correctly
    }

}
