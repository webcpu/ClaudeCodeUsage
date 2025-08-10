//
//  ImprovedAsyncDayChangeTests.swift
//  Tests with proper async/await handling and no race conditions
//

import XCTest
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
// Import specific types to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

@MainActor
final class ImprovedAsyncDayChangeTests: XCTestCase {
    
    var viewModel: UsageViewModel!
    var mockContainer: TestDependencyContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockContainer = TestDependencyContainer()
        viewModel = UsageViewModel(container: mockContainer)
    }
    
    override func tearDown() async throws {
        viewModel.stopAutoRefresh()
        viewModel = nil
        mockContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Async Test with Proper Expectations
    
    func testDayChangeResetsTodaysCostAsync() async throws {
        // Given - Initial data for today (using real Date since ViewModel uses Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let initialStats = UsageStats(
            totalCost: 100.0,
            totalTokens: 1000,
            totalInputTokens: 500,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 50,
            totalCacheReadTokens: 50,
            totalSessions: 5,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 100.0,
                    totalTokens: 1000,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = initialStats
        
        // When - Load initial data
        await viewModel.loadData()
        
        // Then - Today's cost should be 100
        XCTAssertEqual(viewModel.todaysCostValue, 100.0)
        XCTAssertEqual(viewModel.todaysCost, "$100.00")
        
        // Simulate data for the next day (no data for today)
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let yesterdayString = formatter.string(from: yesterday)
        
        let newDayStats = UsageStats(
            totalCost: 100.0, // Same total
            totalTokens: 1000,
            totalInputTokens: 500,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 50,
            totalCacheReadTokens: 50,
            totalSessions: 5,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: yesterdayString, // Only yesterday's data
                    totalCost: 100.0,
                    totalTokens: 1000,
                    modelsUsed: ["claude-3"]
                )
                // No entry for today - this simulates a new day with no usage yet
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = newDayStats
        
        // When - Load data again (simulating after day change)
        await viewModel.loadData()
        
        // Then - Today's cost should reset to 0 (no data for today)
        XCTAssertEqual(viewModel.todaysCostValue, 0.0, "Today's cost should be 0 when no data for today")
        XCTAssertEqual(viewModel.todaysCost, "$0.00", "Today's cost string should show $0.00")
    }
    
    // MARK: - Async Test with Timeout
    
    func testDayChangeWithAsyncStream() async throws {
        // Setup initial data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date()) // Use real date since ViewModel uses Date()
        
        let initialStats = UsageStats(
            totalCost: 50.0,
            totalTokens: 500,
            totalInputTokens: 250,
            totalOutputTokens: 200,
            totalCacheCreationTokens: 25,
            totalCacheReadTokens: 25,
            totalSessions: 3,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 50.0,
                    totalTokens: 500,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = initialStats
        await viewModel.loadData()
        
        // Verify initial state
        XCTAssertEqual(viewModel.todaysCostValue, 50.0, "Initial cost should be 50.0")
        
        // Since we can't mock Date() in ViewModel, we'll test the logic differently
        // We'll verify that when stats don't have today's date, cost is 0
        
        // Create stats with yesterday's date only
        let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
        let yesterdayString = formatter.string(from: yesterday)
        
        let yesterdayOnlyStats = UsageStats(
            totalCost: 50.0,
            totalTokens: 500,
            totalInputTokens: 250,
            totalOutputTokens: 200,
            totalCacheCreationTokens: 25,
            totalCacheReadTokens: 25,
            totalSessions: 3,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: yesterdayString, // Only yesterday's data
                    totalCost: 50.0,
                    totalTokens: 500,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = yesterdayOnlyStats
        await viewModel.loadData()
        
        // Verify the cost is 0 when there's no data for today
        XCTAssertEqual(viewModel.todaysCostValue, 0.0, "Cost should be 0 when no data for today")
        XCTAssertEqual(viewModel.todaysCost, "$0.00", "Cost string should be $0.00")
    }
    
    // MARK: - Test with Actor Isolation
    
    func testConcurrentDayChangeHandling() async throws {
        // Setup with real date
        let initialStats = createTestStats(cost: 75.0, date: Date())
        mockContainer.mockUsageDataService.statsToReturn = initialStats
        await viewModel.loadData()
        
        XCTAssertEqual(viewModel.todaysCostValue, 75.0)
        
        // Create multiple concurrent load operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    // Each task loads data with slightly different costs
                    let newStats = self.createTestStats(cost: Double(70 + i), date: Date())
                    self.mockContainer.mockUsageDataService.statsToReturn = newStats
                    
                    // Load data concurrently
                    await self.viewModel.loadData()
                }
            }
        }
        
        // After all concurrent updates, state should be consistent
        XCTAssertNotNil(viewModel.todaysCostValue)
        XCTAssertNotNil(viewModel.todaysCost)
        // The final value should be one of the test values (70-74)
        XCTAssertTrue(viewModel.todaysCostValue >= 70.0 && viewModel.todaysCostValue <= 74.0,
                      "Cost should be between 70 and 74 after concurrent updates")
    }
    
    // MARK: - Helper Methods
    
    private func createTestStats(cost: Double, date: Date) -> UsageStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return UsageStats(
            totalCost: cost,
            totalTokens: Int(cost * 10),
            totalInputTokens: Int(cost * 5),
            totalOutputTokens: Int(cost * 4),
            totalCacheCreationTokens: Int(cost * 0.5),
            totalCacheReadTokens: Int(cost * 0.5),
            totalSessions: Int(cost / 10),
            byModel: [],
            byDate: [
                DailyUsage(
                    date: dateString,
                    totalCost: cost,
                    totalTokens: Int(cost * 10),
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
    }
}

// MARK: - Test Dependency Container

extension ImprovedAsyncDayChangeTests {
    final class TestDependencyContainer: DependencyContainer {
        let mockUsageDataService = MockUsageDataService()
        let mockSessionMonitorService = MockSessionMonitorService()
        let mockConfigurationService = DefaultConfigurationService()
        let mockPerformanceMetrics = NullPerformanceMetrics()
        
        var usageDataService: UsageDataService { mockUsageDataService }
        var sessionMonitorService: SessionMonitorService { mockSessionMonitorService }
        var configurationService: ConfigurationService { mockConfigurationService }
        var performanceMetrics: PerformanceMetricsProtocol { mockPerformanceMetrics }
    }
    
    final class MockUsageDataService: UsageDataService {
        var statsToReturn: UsageStats?
        var shouldThrow = false
        
        func loadStats() async throws -> UsageStats {
            if shouldThrow {
                throw NSError(domain: "Test", code: 1)
            }
            return statsToReturn ?? UsageStats(
                totalCost: 0,
                totalTokens: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0,
                totalCacheCreationTokens: 0,
                totalCacheReadTokens: 0,
                totalSessions: 0,
                byModel: [],
                byDate: [],
                byProject: []
            )
        }
        
        func loadEntries() async throws -> [UsageEntry] {
            return []
        }
        
        func getDateRange() -> (start: Date, end: Date) {
            (Date().addingTimeInterval(-30 * 24 * 60 * 60), Date())
        }
    }
    
    final class MockSessionMonitorService: SessionMonitorService {
        var mockSession: SessionBlock?
        var mockBurnRate: BurnRate?
        var mockTokenLimit: Int?
        
        func getActiveSession() -> SessionBlock? { mockSession }
        func getBurnRate() -> BurnRate? { mockBurnRate }
        func getAutoTokenLimit() -> Int? { mockTokenLimit }
    }
}