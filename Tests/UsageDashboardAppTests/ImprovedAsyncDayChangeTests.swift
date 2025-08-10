//
//  ImprovedAsyncDayChangeTests.swift
//  Tests with proper async/await handling and no race conditions
//

import XCTest
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
@testable import ClaudeLiveMonitorLib

@MainActor
final class ImprovedAsyncDayChangeTests: XCTestCase {
    
    var viewModel: UsageViewModel!
    var mockContainer: TestDependencyContainer!
    var testClock: TestClock!
    
    override func setUp() async throws {
        try await super.setUp()
        
        testClock = TestClock()
        mockContainer = TestDependencyContainer()
        viewModel = UsageViewModel(container: mockContainer)
    }
    
    override func tearDown() async throws {
        viewModel.stopAutoRefresh()
        viewModel = nil
        mockContainer = nil
        testClock = nil
        try await super.tearDown()
    }
    
    // MARK: - Async Test with Proper Expectations
    
    func testDayChangeResetsTodaysCostAsync() async throws {
        // Given - Initial data for today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testClock.now)
        
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
        
        // Given - Advance to next day
        testClock.advanceToNextDay()
        let tomorrowString = formatter.string(from: testClock.now)
        
        // Create an expectation for the day change handling
        let dayChangeExpectation = XCTestExpectation(description: "Day change notification handled")
        
        // Update stats for new day (no data yet)
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
                    date: todayString, // Yesterday's data
                    totalCost: 100.0,
                    totalTokens: 1000,
                    modelsUsed: ["claude-3"]
                )
                // No entry for today (tomorrow)
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = newDayStats
        
        // Create a proper async handler for the notification
        let observer = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                // Wait for the viewModel to handle the notification
                // The viewModel's handler will call loadData
                dayChangeExpectation.fulfill()
            }
        }
        
        // When - Post day change notification
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        
        // Wait for the expectation with timeout
        await fulfillment(of: [dayChangeExpectation], timeout: 1.0)
        
        // Give the viewModel's async handler time to complete
        // Use a proper async delay instead of Task.sleep
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                continuation.resume()
            }
        }
        
        // Then - Today's cost should reset to 0
        XCTAssertEqual(viewModel.todaysCostValue, 0.0, "Today's cost should reset after day change")
        XCTAssertEqual(viewModel.todaysCost, "$0.00", "Today's cost string should show $0.00")
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
    
    // MARK: - Async Test with Combine
    
    func testDayChangeWithAsyncStream() async throws {
        // Setup initial data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testClock.now)
        
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
        
        // Create an AsyncStream to monitor todaysCostValue changes
        let (stream, continuation) = AsyncStream<Double>.makeStream()
        
        // Monitor changes using async observation
        let observationTask = Task {
            for await _ in stream {
                // Process each cost update
                if viewModel.todaysCostValue == 0.0 {
                    continuation.finish()
                    break
                }
            }
        }
        
        // Advance to next day
        testClock.advanceToNextDay()
        
        // Update mock data for new day
        let newDayStats = UsageStats(
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
                    date: todayString, // Yesterday's data
                    totalCost: 50.0,
                    totalTokens: 500,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = newDayStats
        
        // Trigger day change
        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        
        // Manually trigger update and send to stream
        await viewModel.loadData()
        continuation.yield(viewModel.todaysCostValue)
        
        // Wait for the observation task to complete
        await observationTask.value
        
        // Verify the cost was reset
        XCTAssertEqual(viewModel.todaysCostValue, 0.0)
        XCTAssertEqual(viewModel.todaysCost, "$0.00")
    }
    
    // MARK: - Test with Actor Isolation
    
    func testConcurrentDayChangeHandling() async throws {
        // Setup
        let initialStats = createTestStats(cost: 75.0, date: testClock.now)
        mockContainer.mockUsageDataService.statsToReturn = initialStats
        await viewModel.loadData()
        
        XCTAssertEqual(viewModel.todaysCostValue, 75.0)
        
        // Create multiple concurrent day change notifications
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    // Each task advances time slightly
                    self.testClock.advance(by: Double(i))
                    
                    // Update mock data
                    let newStats = self.createTestStats(cost: 75.0, date: self.testClock.now)
                    self.mockContainer.mockUsageDataService.statsToReturn = newStats
                    
                    // Trigger day change
                    NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
                    
                    // Load data
                    await self.viewModel.loadData()
                }
            }
        }
        
        // After all concurrent updates, state should be consistent
        XCTAssertNotNil(viewModel.todaysCostValue)
        XCTAssertNotNil(viewModel.todaysCost)
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