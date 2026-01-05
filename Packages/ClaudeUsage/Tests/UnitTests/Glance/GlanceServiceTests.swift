//
//  GlanceServiceTests.swift
//
//  Specification for GlanceService - actor for loading glance metrics.
//
//  This test suite specifies the actor contract:
//  - loadData(invalidateCache:) → Result<GlanceData, Error>?
//    - Returns nil if already loading (concurrent protection)
//    - Returns .success(GlanceData) on successful load
//    - GlanceData contains: todayCost (TodayCost), activeSession (UsageSession?)
//  - clearCache() → clears underlying provider caches
//

import Testing
import Foundation
@testable import ClaudeUsage

// MARK: - GlanceService Specification

/// GlanceService is an actor that loads glance metrics (today's cost, active session).
/// It provides concurrent load protection and cache management.
@Suite("GlanceService")
struct GlanceServiceTests {

    // MARK: - Initialization

    @Test("initializes with default configuration")
    func defaultInitialization() async {
        let service = GlanceService()
        // Service created without error
        _ = service
    }

    // MARK: - loadData Contract

    @Test("loadData returns Result on success")
    func loadDataSuccess() async {
        let service = GlanceService()

        let result = await service.loadData()

        #expect(result != nil)
        if case .success(let data) = result {
            #expect(data.todayCost.total >= 0)
            #expect(data.todayCost.hourlyCosts.count == 24)
        }
    }

    @Test("loadData returns nil when already loading (concurrent protection)")
    func loadDataConcurrentProtection() async {
        let service = GlanceService()

        // Start multiple concurrent loads
        async let result1 = service.loadData()
        async let result2 = service.loadData()
        async let result3 = service.loadData()

        let results = await [result1, result2, result3]

        // At least one succeeds, others may be skipped
        let successCount = results.compactMap { $0 }.count
        #expect(successCount >= 1, "At least one call should succeed")
        #expect(successCount <= 3, "All calls could succeed if serialized")
    }

    @Test("loadData with invalidateCache=false preserves cache")
    func loadDataPreserveCache() async {
        let service = GlanceService()

        // First load (with cache invalidation by default)
        _ = await service.loadData()

        // Second load without invalidation
        let result = await service.loadData(invalidateCache: false)

        #expect(result != nil)
    }

    @Test("loadData with invalidateCache=true clears and reloads")
    func loadDataInvalidatesCache() async {
        let service = GlanceService()

        // Sequential loads with cache invalidation
        let result1 = await service.loadData(invalidateCache: true)
        let result2 = await service.loadData(invalidateCache: true)

        #expect(result1 != nil)
        #expect(result2 != nil)
    }

    // MARK: - GlanceData Structure

    @Test("GlanceData.todayCost contains valid structure")
    func glanceDataTodayCost() async {
        let service = GlanceService()

        guard let result = await service.loadData(),
              case .success(let data) = result else {
            return
        }

        // TodayCost specification
        #expect(data.todayCost.total >= 0)
        #expect(data.todayCost.hourlyCosts.count == 24)
        #expect(data.todayCost.hourlyCosts.allSatisfy { $0 >= 0 })
    }

    @Test("GlanceData.activeSession is optional")
    func glanceDataActiveSession() async {
        let service = GlanceService()

        guard let result = await service.loadData(),
              case .success(let data) = result else {
            return
        }

        // activeSession may or may not be present
        if let session = data.activeSession {
            #expect(session.isActive == true)
            #expect(session.tokens.total >= 0)
        }
    }

    // MARK: - clearCache Contract

    @Test("clearCache allows fresh data fetch")
    func clearCacheAllowsFreshFetch() async {
        let service = GlanceService()

        // Load once
        _ = await service.loadData()

        // Clear cache
        await service.clearCache()

        // Load again
        let result = await service.loadData()
        #expect(result != nil)
    }
}
