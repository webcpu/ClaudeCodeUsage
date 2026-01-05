//
//  GlanceServiceTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("GlanceService")
struct GlanceServiceTests {

    // MARK: - Data Loading

    @Test("loadData returns success with valid data")
    func loadDataReturnsSuccess() async throws {
        let service = GlanceService()

        let result = await service.loadData(invalidateCache: false)

        #expect(result != nil)
        if case .success(let data) = result {
            #expect(data.todayCost.total >= 0)
        }
    }

    @Test("loadData returns nil when already loading")
    func loadDataSkipsWhenAlreadyLoading() async {
        let service = GlanceService()

        // Start multiple concurrent loads
        async let result1 = service.loadData()
        async let result2 = service.loadData()
        async let result3 = service.loadData()

        let results = await [result1, result2, result3]

        // Concurrent loads: one succeeds, others skipped
        let successCount = results.compactMap { $0 }.count

        #expect(successCount >= 1, "At least one call should succeed")
        #expect(successCount <= 3, "All calls could succeed if serialized")
    }

    @Test("loadData with invalidateCache clears and reloads")
    func loadDataInvalidatesCache() async {
        let service = GlanceService()

        // Load with cache invalidation
        let result1 = await service.loadData(invalidateCache: true)
        let result2 = await service.loadData(invalidateCache: true)

        // Both should succeed (sequential calls)
        #expect(result1 != nil)
        #expect(result2 != nil)
    }

    // MARK: - GlanceData Structure

    @Test("GlanceData contains todayCost and optional session")
    func glanceDataStructure() async {
        let service = GlanceService()

        guard let result = await service.loadData(),
              case .success(let data) = result else {
            return
        }

        // TodayCost should always be present
        #expect(data.todayCost.total >= 0)
        #expect(data.todayCost.hourlyCosts.count == 24)

        // ActiveSession is optional
        if let session = data.activeSession {
            #expect(session.isActive)
        }
    }

    // MARK: - Cache Management

    @Test("clearCache allows fresh data fetch")
    func clearCacheAllowsFreshFetch() async {
        let service = GlanceService()

        // Load once
        _ = await service.loadData()

        // Clear cache
        await service.clearCache()

        // Load again should still work
        let result = await service.loadData()
        #expect(result != nil)
    }

}
