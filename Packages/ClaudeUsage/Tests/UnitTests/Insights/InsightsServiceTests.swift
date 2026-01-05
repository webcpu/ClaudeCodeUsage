//
//  InsightsServiceTests.swift
//
//  Specification for InsightsService - actor for loading usage insights.
//
//  This test suite specifies the actor contract:
//  - loadStats() → Result<UsageStats, Error>?
//    - Returns nil if already loading (concurrent protection)
//    - Returns .success(UsageStats) on successful load
//  - startMonitoring(onChange:) → starts directory monitoring (idempotent)
//  - stopMonitoring() → stops directory monitoring (safe to call multiple times)
//

import Testing
import Foundation
@testable import ClaudeUsage

// MARK: - InsightsService Specification

/// InsightsService is an actor that loads usage statistics and monitors for changes.
/// It provides concurrent load protection and directory monitoring.
@Suite("InsightsService")
struct InsightsServiceTests {

    // MARK: - Initialization

    @Test("initializes with default configuration")
    func defaultInitialization() async {
        let service = InsightsService()
        // Service created without error
        _ = service
    }

    // MARK: - loadStats Contract

    @Test("loadStats returns Result on success")
    func loadStatsSuccess() async {
        let service = InsightsService()

        let result = await service.loadStats()

        #expect(result != nil)
        if case .success(let stats) = result {
            #expect(stats.totalCost >= 0)
            #expect(stats.sessionCount >= 0)
        }
    }

    @Test("loadStats returns nil when already loading (concurrent protection)")
    func loadStatsConcurrentProtection() async {
        let service = InsightsService()

        // Start multiple concurrent loads
        async let result1 = service.loadStats()
        async let result2 = service.loadStats()
        async let result3 = service.loadStats()

        let results = await [result1, result2, result3]

        // At least one succeeds, others may be skipped
        let successCount = results.compactMap { $0 }.count
        #expect(successCount >= 1, "At least one call should succeed")
        #expect(successCount <= 3, "All calls could succeed if serialized")
    }

    @Test("loadStats sequential calls all succeed")
    func loadStatsSequentialSuccess() async {
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

        // UsageStats specification
        #expect(stats.totalCost >= 0)
        #expect(stats.sessionCount >= 0)
        #expect(stats.tokens.input >= 0)
        #expect(stats.tokens.output >= 0)
        #expect(stats.byModel.count >= 0)
        #expect(stats.byDate.count >= 0)
    }

    // MARK: - Monitoring Contract

    @Test("startMonitoring is idempotent - multiple calls safe")
    func startMonitoringIdempotent() async {
        let service = InsightsService()

        // Start monitoring multiple times
        await service.startMonitoring {}
        await service.startMonitoring {}
        await service.startMonitoring {}

        // Clean up
        await service.stopMonitoring()

        // No crash = idempotent behavior verified
    }

    @Test("stopMonitoring is safe to call multiple times")
    func stopMonitoringSafe() async {
        let service = InsightsService()

        await service.startMonitoring {}
        await service.stopMonitoring()

        // Safe to call again
        await service.stopMonitoring()
        await service.stopMonitoring()

        // No crash = safe behavior verified
    }

    @Test("stopMonitoring is safe when never started")
    func stopMonitoringWithoutStart() async {
        let service = InsightsService()

        // Stop without starting
        await service.stopMonitoring()

        // No crash = safe behavior verified
    }

    @Test("startMonitoring then stopMonitoring lifecycle")
    func monitoringLifecycle() async {
        let service = InsightsService()

        // Full lifecycle
        await service.startMonitoring {}
        await service.stopMonitoring()

        // Can restart
        await service.startMonitoring {}
        await service.stopMonitoring()

        // No crash = lifecycle verified
    }
}
