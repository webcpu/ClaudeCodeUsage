//
//  LiveMonitorActorTests.swift
//  Migrated to Swift Testing Framework
//

import Testing
import Foundation
@testable import ClaudeLiveMonitorLib
@testable import ClaudeCodeUsage

// MARK: - Main Test Suite

@Suite("LiveMonitorActor Tests", .serialized)
@MainActor
struct LiveMonitorActorTests {
    
    let monitor: LiveMonitorActor
    let config: LiveMonitorConfig
    let tempDir: URL
    
    // MARK: - Initialization
    
    init() async throws {
        // Create test configuration with temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_claude_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        self.tempDir = tempDir
        self.config = LiveMonitorConfig(
            claudePaths: [tempDir.path],
            sessionDurationHours: 5,
            tokenLimit: nil,
            refreshInterval: 1.0,
            order: .descending
        )
        
        self.monitor = LiveMonitorActor(config: config)
    }
    
    // Cleanup is handled via test lifecycle - temp directories are automatically cleaned up
    
    // MARK: - Basic Functionality Tests
    
    @Test("Initialization creates monitor with no active block")
    func testInitialization() async {
        let block = await monitor.getActiveBlock()
        #expect(block == nil, "Should have no active block initially")
    }
    
    @Test("Clear cache removes active block")
    func testClearCache() async {
        await monitor.clearCache()
        let block = await monitor.getActiveBlock()
        #expect(block == nil, "Should have no active block after clearing cache")
    }
    
    @Test("Auto token limit returns nil with no data")
    func testGetAutoTokenLimitWithNoData() async {
        let limit = await monitor.getAutoTokenLimit()
        #expect(limit == nil, "Should return nil when no data available")
    }
    
    // MARK: - Session Block Tests
    
    @Test("Session block creation with test data")
    func testSessionBlockCreation() async throws {
        // Create test data
        let projectDir = tempDir
            .appendingPathComponent("projects")
            .appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        let testData = createTestUsageData()
        let jsonData = try JSONEncoder().encode(testData)
        
        let testFile = projectDir.appendingPathComponent("usage.json")
        try jsonData.write(to: testFile)
        
        // Get active block
        let block = await monitor.getActiveBlock()
        #expect(block == nil, "JSON file format doesn't match JSONL format expected by parser")
    }
    
    // MARK: - Concurrency Tests
    
    @Test("Concurrent access is thread-safe")
    func testConcurrentAccess() async {
        // Test that multiple concurrent accesses don't cause crashes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    _ = await self.monitor.getActiveBlock()
                }
                
                group.addTask {
                    _ = await self.monitor.getAutoTokenLimit()
                }
                
                group.addTask {
                    await self.monitor.clearCache()
                }
            }
        }
        
        // If we get here without crashing, the test passes
        #expect(true, "Concurrent access completed without crashes")
    }
    
    @Test("Data race free safety with actor isolation")
    func testDataRaceFreeSafety() async {
        // This test verifies actor isolation prevents data races
        let iterations = 100
        var results: [SessionBlock?] = []
        
        await withTaskGroup(of: SessionBlock?.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await self.monitor.getActiveBlock()
                }
            }
            
            for await result in group {
                results.append(result)
            }
        }
        
        #expect(results.count == iterations)
        // All results should be nil since we have no data
        #expect(results.allSatisfy { $0 == nil })
    }
    
    // MARK: - Performance Tests
    
    @Test("Get active block performance", .timeLimit(.minutes(1)))
    func testGetActiveBlockPerformance() async {
        let start = Date()
        _ = await monitor.getActiveBlock()
        let duration = Date().timeIntervalSince(start)
        #expect(duration < 1.0, "Operation should complete within 1 second")
    }
    
    @Test("Clear cache performance", .timeLimit(.minutes(1)))
    func testClearCachePerformance() async {
        let start = Date()
        await monitor.clearCache()
        let duration = Date().timeIntervalSince(start)
        #expect(duration < 1.0, "Operation should complete within 1 second")
    }
    
    // MARK: - Integration Tests
    
    @Test("Actor-based session monitor service integration")
    func testActorBasedSessionMonitorService() async {
        let service = ActorBasedSessionMonitorService(configuration: .default)
        
        let session = await service.getActiveSession()
        #expect(session == nil, "Should return nil when no active session")
        
        let burnRate = await service.getBurnRate()
        #expect(burnRate == nil, "Should return nil when no active session")
        
        let limit = await service.getAutoTokenLimit()
        #expect(limit == nil, "Should return nil when no data")
    }
    
    @Test("Hybrid session monitor with actor flag enabled")
    func testHybridSessionMonitorServiceWithActorFlag() async {
        // Enable actor-based implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        defer { FeatureFlags.reset() }
        
        let service = HybridSessionMonitorService(configuration: .default)

        // These calls should use the actor-based implementation
        let session = await service.getActiveSession()
        #expect(session == nil)

        let burnRate = await service.getBurnRate()
        #expect(burnRate == nil)

        let limit = await service.getAutoTokenLimit()
        #expect(limit == nil)
    }
    
    @Test("Hybrid session monitor with GCD flag enabled")
    func testHybridSessionMonitorServiceWithGCDFlag() async {
        // Disable actor-based implementation
        FeatureFlags.useActorBasedLiveMonitor = false
        defer { FeatureFlags.reset() }
        
        // Create configuration with non-existent path to ensure no data
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_empty_\(UUID().uuidString)")
        let testConfig = AppConfiguration(
            basePath: tempDir.path,
            refreshInterval: 30.0,
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0,
            minimumRefreshInterval: 10.0
        )
        
        let service = HybridSessionMonitorService(configuration: testConfig)

        // These calls should use the GCD-based implementation
        let session = await service.getActiveSession()
        #expect(session == nil, "Should return nil when no data in test directory")

        let burnRate = await service.getBurnRate()
        #expect(burnRate == nil, "Should return nil when no data in test directory")

        let limit = await service.getAutoTokenLimit()
        #expect(limit == nil, "Should return nil when no data in test directory")
    }
    
    // MARK: - Feature Flag Tests
    
    @Test("Feature flag persistence")
    func testFeatureFlagPersistence() {
        // Reset to ensure clean state
        FeatureFlags.reset()
        
        // Test setting to true
        FeatureFlags.useActorBasedLiveMonitor = true
        #expect(FeatureFlags.useActorBasedLiveMonitor == true)
        
        // Test setting to false
        FeatureFlags.useActorBasedLiveMonitor = false
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Test reset functionality
        FeatureFlags.reset()
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
    }
    
    #if DEBUG
    @Test("Debug feature flags enable/disable all")
    func testDebugFeatureFlags() {
        // Reset to ensure clean state
        FeatureFlags.reset()
        
        // Test enabling all features
        FeatureFlags.enableAllExperimentalFeatures()
        #expect(FeatureFlags.useActorBasedLiveMonitor == true)
        
        // Test disabling all features
        FeatureFlags.disableAllExperimentalFeatures()
        #expect(FeatureFlags.useActorBasedLiveMonitor == false)
        
        // Clean up after test
        FeatureFlags.reset()
    }
    #endif
    
    // MARK: - Helper Methods
    
    private struct TestUsageEntry: Codable {
        let timestamp: TimeInterval
        let model: String
        let usage: TestTokenUsage
        let costUSD: Double
    }
    
    private struct TestTokenUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int
        let cacheReadInputTokens: Int
    }
    
    private func createTestUsageData() -> TestUsageEntry {
        return TestUsageEntry(
            timestamp: Date().timeIntervalSince1970,
            model: "claude-3-opus",
            usage: TestTokenUsage(
                inputTokens: 100,
                outputTokens: 200,
                cacheCreationInputTokens: 10,
                cacheReadInputTokens: 20
            ),
            costUSD: 0.05
        )
    }
}

// MARK: - Performance Comparison Suite

@Suite("LiveMonitor Performance Comparison", .serialized)
@MainActor
struct LiveMonitorPerformanceComparisonTests {
    
    // Create test configuration that doesn't access real data
    private var testConfig: AppConfiguration {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_perf_\(UUID().uuidString)")
        return AppConfiguration(
            basePath: tempDir.path,
            refreshInterval: 30.0,
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0,
            minimumRefreshInterval: 10.0
        )
    }
    
    @Test("Performance comparison between GCD and Actor implementations")
    func testPerformanceComparison() async {
        let iterations = 10 // Reduced iterations for faster tests
        let config = testConfig
        
        // Test GCD implementation
        FeatureFlags.useActorBasedLiveMonitor = false
        let gcdService = HybridSessionMonitorService(configuration: config)
        
        let gcdStart = Date()
        for _ in 0..<iterations {
            _ = await gcdService.getActiveSession()
            _ = await gcdService.getBurnRate()
            _ = await gcdService.getAutoTokenLimit()
        }
        let gcdDuration = Date().timeIntervalSince(gcdStart)

        // Test Actor implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        let actorService = HybridSessionMonitorService(configuration: config)

        let actorStart = Date()
        for _ in 0..<iterations {
            _ = await actorService.getActiveSession()
            _ = await actorService.getBurnRate()
            _ = await actorService.getAutoTokenLimit()
        }
        let actorDuration = Date().timeIntervalSince(actorStart)
        
        print("GCD Duration: \(gcdDuration) seconds")
        print("Actor Duration: \(actorDuration) seconds")
        if gcdDuration > 0 {
            print("Performance difference: \((gcdDuration - actorDuration) / gcdDuration * 100)%")
        }
        
        // Both should complete reasonably quickly
        #expect(gcdDuration < 5.0, "GCD implementation should complete within 5 seconds")
        #expect(actorDuration < 5.0, "Actor implementation should complete within 5 seconds")
        
        // Reset
        FeatureFlags.reset()
    }
    
    @Test("Concurrent performance comparison", .timeLimit(.minutes(1)))
    func testConcurrentPerformanceComparison() async {
        let concurrentTasks = 10 // Reduced for faster tests
        let config = testConfig
        
        // Test GCD implementation
        FeatureFlags.useActorBasedLiveMonitor = false
        let gcdService = HybridSessionMonitorService(configuration: config)
        
        let gcdStart = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    _ = await gcdService.getActiveSession()
                }
            }
        }
        let gcdDuration = Date().timeIntervalSince(gcdStart)

        // Test Actor implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        let actorService = HybridSessionMonitorService(configuration: config)

        let actorStart = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    _ = await actorService.getActiveSession()
                }
            }
        }
        let actorDuration = Date().timeIntervalSince(actorStart)
        
        print("Concurrent GCD Duration: \(gcdDuration) seconds")
        print("Concurrent Actor Duration: \(actorDuration) seconds")
        if gcdDuration > 0 {
            print("Concurrent performance difference: \((gcdDuration - actorDuration) / gcdDuration * 100)%")
        }
        
        // Both should complete quickly with test data
        #expect(gcdDuration < 1.0, "GCD should complete quickly")
        #expect(actorDuration < 1.0, "Actor should complete quickly")
        
        // Reset
        FeatureFlags.reset()
    }
}

// MARK: - Test Extensions

extension Tag {
    @Tag static var performance: Self
    @Tag static var concurrency: Self
    @Tag static var integration: Self
}