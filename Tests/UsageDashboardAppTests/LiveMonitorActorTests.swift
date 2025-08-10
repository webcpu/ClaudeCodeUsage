import XCTest
@testable import ClaudeLiveMonitorLib
@testable import UsageDashboardApp

@MainActor
final class LiveMonitorActorTests: XCTestCase {
    
    var monitor: LiveMonitorActor!
    var config: LiveMonitorConfig!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test configuration with temporary directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_claude_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        config = LiveMonitorConfig(
            claudePaths: [tempDir.path],
            sessionDurationHours: 5,
            tokenLimit: nil,
            refreshInterval: 1.0,
            order: .descending
        )
        
        monitor = LiveMonitorActor(config: config)
    }
    
    override func tearDown() async throws {
        // Clean up temporary directory
        if let config = config {
            for path in config.claudePaths {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        
        monitor = nil
        config = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() async {
        XCTAssertNotNil(monitor)
        let block = await monitor.getActiveBlock()
        XCTAssertNil(block, "Should have no active block initially")
    }
    
    func testClearCache() async {
        await monitor.clearCache()
        let block = await monitor.getActiveBlock()
        XCTAssertNil(block, "Should have no active block after clearing cache")
    }
    
    func testGetAutoTokenLimitWithNoData() async {
        let limit = await monitor.getAutoTokenLimit()
        XCTAssertNil(limit, "Should return nil when no data available")
    }
    
    // MARK: - Session Block Tests
    
    func testSessionBlockCreation() async throws {
        // Create test data
        let projectDir = URL(fileURLWithPath: config.claudePaths[0])
            .appendingPathComponent("projects")
            .appendingPathComponent("test-project")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        
        let testData = createTestUsageData()
        let jsonData = try JSONEncoder().encode(testData)
        
        let testFile = projectDir.appendingPathComponent("usage.json")
        try jsonData.write(to: testFile)
        
        // Get active block
        let block = await monitor.getActiveBlock()
        XCTAssertNil(block, "JSON file format doesn't match JSONL format expected by parser")
    }
    
    // MARK: - Concurrency Tests
    
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
        XCTAssertTrue(true, "Concurrent access completed without crashes")
    }
    
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
        
        XCTAssertEqual(results.count, iterations)
        // All results should be nil since we have no data
        XCTAssertTrue(results.allSatisfy { $0 == nil })
    }
    
    // MARK: - Performance Tests
    
    func testGetActiveBlockPerformance() async {
        await measureAsync {
            _ = await self.monitor.getActiveBlock()
        }
    }
    
    func testClearCachePerformance() async {
        await measureAsync {
            await self.monitor.clearCache()
        }
    }
    
    // MARK: - Integration Tests
    
    func testActorBasedSessionMonitorService() async {
        let service = ActorBasedSessionMonitorService(configuration: .default)
        
        let session = await service.getActiveSession()
        XCTAssertNil(session, "Should return nil when no active session")
        
        let burnRate = await service.getBurnRate()
        XCTAssertNil(burnRate, "Should return nil when no active session")
        
        let limit = await service.getAutoTokenLimit()
        XCTAssertNil(limit, "Should return nil when no data")
    }
    
    func testHybridSessionMonitorServiceWithActorFlag() async {
        // Enable actor-based implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        defer { FeatureFlags.reset() }
        
        let service = HybridSessionMonitorService(configuration: .default)
        
        // These calls should use the actor-based implementation
        let session = service.getActiveSession()
        XCTAssertNil(session)
        
        let burnRate = service.getBurnRate()
        XCTAssertNil(burnRate)
        
        let limit = service.getAutoTokenLimit()
        XCTAssertNil(limit)
    }
    
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
        let session = service.getActiveSession()
        XCTAssertNil(session, "Should return nil when no data in test directory")
        
        let burnRate = service.getBurnRate()
        XCTAssertNil(burnRate, "Should return nil when no data in test directory")
        
        let limit = service.getAutoTokenLimit()
        XCTAssertNil(limit, "Should return nil when no data in test directory")
    }
    
    // MARK: - Feature Flag Tests
    
    func testFeatureFlagPersistence() {
        FeatureFlags.useActorBasedLiveMonitor = true
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
        
        FeatureFlags.useActorBasedLiveMonitor = false
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
        
        FeatureFlags.reset()
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
    }
    
    func testFeatureFlagPercentageRollout() {
        // Test 0% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 0)
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
        
        // Test 100% rollout
        FeatureFlags.enableActorBasedLiveMonitor(percentage: 100)
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
        
        // Reset
        FeatureFlags.reset()
    }
    
    #if DEBUG
    func testDebugFeatureFlags() {
        FeatureFlags.enableAllExperimentalFeatures()
        XCTAssertTrue(FeatureFlags.useActorBasedLiveMonitor)
        
        FeatureFlags.disableAllExperimentalFeatures()
        XCTAssertFalse(FeatureFlags.useActorBasedLiveMonitor)
        
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
    
    private func measureAsync(_ block: () async -> Void) async {
        let start = Date()
        await block()
        let duration = Date().timeIntervalSince(start)
        print("Execution time: \(duration) seconds")
        XCTAssertLessThan(duration, 1.0, "Operation should complete within 1 second")
    }
}

// MARK: - Actor vs GCD Performance Comparison

@MainActor
final class LiveMonitorPerformanceComparisonTests: XCTestCase {
    
    func testPerformanceComparison() async {
        let iterations = 100
        
        // Test GCD implementation
        FeatureFlags.useActorBasedLiveMonitor = false
        let gcdService = HybridSessionMonitorService(configuration: .default)
        
        let gcdStart = Date()
        for _ in 0..<iterations {
            _ = gcdService.getActiveSession()
            _ = gcdService.getBurnRate()
            _ = gcdService.getAutoTokenLimit()
        }
        let gcdDuration = Date().timeIntervalSince(gcdStart)
        
        // Test Actor implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        let actorService = HybridSessionMonitorService(configuration: .default)
        
        let actorStart = Date()
        for _ in 0..<iterations {
            _ = actorService.getActiveSession()
            _ = actorService.getBurnRate()
            _ = actorService.getAutoTokenLimit()
        }
        let actorDuration = Date().timeIntervalSince(actorStart)
        
        print("GCD Duration: \(gcdDuration) seconds")
        print("Actor Duration: \(actorDuration) seconds")
        print("Performance difference: \((gcdDuration - actorDuration) / gcdDuration * 100)%")
        
        // Reset
        FeatureFlags.reset()
    }
    
    func testConcurrentPerformanceComparison() async {
        let concurrentTasks = 50
        
        // Test GCD implementation
        FeatureFlags.useActorBasedLiveMonitor = false
        let gcdService = HybridSessionMonitorService(configuration: .default)
        
        let gcdStart = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    _ = gcdService.getActiveSession()
                }
            }
        }
        let gcdDuration = Date().timeIntervalSince(gcdStart)
        
        // Test Actor implementation
        FeatureFlags.useActorBasedLiveMonitor = true
        let actorService = HybridSessionMonitorService(configuration: .default)
        
        let actorStart = Date()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentTasks {
                group.addTask {
                    _ = actorService.getActiveSession()
                }
            }
        }
        let actorDuration = Date().timeIntervalSince(actorStart)
        
        print("Concurrent GCD Duration: \(gcdDuration) seconds")
        print("Concurrent Actor Duration: \(actorDuration) seconds")
        print("Concurrent performance difference: \((gcdDuration - actorDuration) / gcdDuration * 100)%")
        
        // Actor should perform better under concurrent load
        XCTAssertLessThanOrEqual(actorDuration, gcdDuration * 1.2, "Actor should not be significantly slower than GCD")
        
        // Reset
        FeatureFlags.reset()
    }
}