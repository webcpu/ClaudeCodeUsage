//
//  UsageViewModelTests.swift
//  Tests for UsageViewModel
//

import XCTest
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
import ClaudeLiveMonitorLib

@MainActor
final class UsageViewModelTests: XCTestCase {
    
    // MARK: - Mock Dependencies
    
    class MockUsageDataService: UsageDataService {
        var mockStats: UsageStats?
        var loadStatsCalled = false
        var loadStatsCallCount = 0
        var loadStatsTime: TimeInterval = 0
        
        func loadStats() async throws -> UsageStats {
            loadStatsCalled = true
            loadStatsCallCount += 1
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate some processing time
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            
            guard let stats = mockStats else {
                throw NSError(domain: "TestError", code: 1, userInfo: nil)
            }
            
            loadStatsTime = CFAbsoluteTimeGetCurrent() - startTime
            return stats
        }
        
        func getDateRange() -> (start: Date, end: Date) {
            return (Date.distantPast, Date())
        }
    }
    
    class MockSessionMonitorService: SessionMonitorService {
        func getActiveSession() -> SessionBlock? { nil }
        func getBurnRate() -> BurnRate? { nil }
        func getAutoTokenLimit() -> Int? { nil }
    }
    
    class MockConfigurationService: ConfigurationService {
        var configuration = AppConfiguration.default
        func updateConfiguration(_ config: AppConfiguration) {
            self.configuration = config
        }
    }
    
    class MockDependencyContainer: DependencyContainer {
        var usageDataService: UsageDataService
        var sessionMonitorService: SessionMonitorService
        var configurationService: ConfigurationService
        var performanceMetrics: PerformanceMetricsProtocol
        
        init(usageDataService: UsageDataService,
             sessionMonitorService: SessionMonitorService,
             configurationService: ConfigurationService,
             performanceMetrics: PerformanceMetricsProtocol? = nil) {
            self.usageDataService = usageDataService
            self.sessionMonitorService = sessionMonitorService
            self.configurationService = configurationService
            self.performanceMetrics = performanceMetrics ?? NullPerformanceMetrics()
        }
    }
    
    // MARK: - Test Setup
    
    var viewModel: UsageViewModel!
    var mockUsageService: MockUsageDataService!
    var mockSessionService: MockSessionMonitorService!
    var mockConfigService: MockConfigurationService!
    var mockContainer: MockDependencyContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockUsageService = MockUsageDataService()
        mockSessionService = MockSessionMonitorService()
        mockConfigService = MockConfigurationService()
        mockContainer = MockDependencyContainer(
            usageDataService: mockUsageService,
            sessionMonitorService: mockSessionService,
            configurationService: mockConfigService
        )
        
        viewModel = UsageViewModel(container: mockContainer)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockUsageService = nil
        mockSessionService = nil
        mockConfigService = nil
        mockContainer = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Today's Cost Tests
    
    func testTodaysCostWithNoData() async {
        // Given: No stats available
        mockUsageService.mockStats = nil
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should be $0.00
        XCTAssertEqual(viewModel.todaysCost, "$0.00")
        XCTAssertEqual(viewModel.todaysCostValue, 0.0)
    }
    
    func testTodaysCostWithEmptyStats() async {
        // Given: Empty stats
        mockUsageService.mockStats = UsageStats(
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
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should be $0.00
        XCTAssertEqual(viewModel.todaysCost, "$0.00")
        XCTAssertEqual(viewModel.todaysCostValue, 0.0)
    }
    
    func testTodaysCostWithTodayData() async {
        // Given: Stats with today's data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let todayUsage = DailyUsage(
            date: todayString,
            totalCost: 42.50,
            totalTokens: 100000,
            modelsUsed: ["claude-3-opus"]
        )
        
        mockUsageService.mockStats = UsageStats(
            totalCost: 100.00,
            totalTokens: 200000,
            totalInputTokens: 50000,
            totalOutputTokens: 150000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 5,
            byModel: [],
            byDate: [todayUsage],
            byProject: []
        )
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should reflect the data
        XCTAssertEqual(viewModel.todaysCost, "$42.50")
        XCTAssertEqual(viewModel.todaysCostValue, 42.50)
    }
    
    func testTodaysCostWithoutTodayData() async {
        // Given: Stats without today's data
        let yesterdayUsage = DailyUsage(
            date: "2025-01-07",
            totalCost: 30.00,
            totalTokens: 75000,
            modelsUsed: ["claude-3-opus"]
        )
        
        mockUsageService.mockStats = UsageStats(
            totalCost: 30.00,
            totalTokens: 75000,
            totalInputTokens: 25000,
            totalOutputTokens: 50000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 3,
            byModel: [],
            byDate: [yesterdayUsage],
            byProject: []
        )
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should be $0.00
        XCTAssertEqual(viewModel.todaysCost, "$0.00")
        XCTAssertEqual(viewModel.todaysCostValue, 0.0)
    }
    
    // MARK: - Performance Tests
    
    func testTodaysCostComputationPerformance() async throws {
        // Given: Large dataset
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        var dailyUsages: [DailyUsage] = []
        
        // Add 365 days of data
        for i in 0..<365 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let dateString = formatter.string(from: date)
            let usage = DailyUsage(
                date: dateString,
                totalCost: Double.random(in: 10...100),
                totalTokens: Int.random(in: 10000...100000),
                modelsUsed: ["claude-3-opus", "claude-3-sonnet"]
            )
            dailyUsages.append(usage)
        }
        
        // Ensure today's data is included
        dailyUsages[0] = DailyUsage(
            date: todayString,
            totalCost: 75.25,
            totalTokens: 150000,
            modelsUsed: ["claude-3-opus"]
        )
        
        mockUsageService.mockStats = UsageStats(
            totalCost: dailyUsages.reduce(0) { $0 + $1.totalCost },
            totalTokens: dailyUsages.reduce(0) { $0 + $1.totalTokens },
            totalInputTokens: 1000000,
            totalOutputTokens: 2000000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 365,
            byModel: [],
            byDate: dailyUsages,
            byProject: []
        )
        
        // When: Measure today's cost computation
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadData()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let totalTime = endTime - startTime
        
        // Then: Should compute quickly
        XCTAssertEqual(viewModel.todaysCost, "$75.25")
        XCTAssertEqual(viewModel.todaysCostValue, 75.25)
        XCTAssertLessThan(totalTime, 0.1, "Today's cost computation should complete within 100ms")
        
        print("Performance: Total load time: \(totalTime * 1000)ms")
        print("Performance: Stats loading time: \(mockUsageService.loadStatsTime * 1000)ms")
    }
    
    func testTodaysCostComputationDirectPerformance() {
        // Given: Large dataset directly on the view model
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        var dailyUsages: [DailyUsage] = []
        for i in 0..<1000 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            let dateString = formatter.string(from: date)
            let usage = DailyUsage(
                date: dateString,
                totalCost: Double.random(in: 10...100),
                totalTokens: Int.random(in: 10000...100000),
                modelsUsed: ["claude-3-opus"]
            )
            dailyUsages.append(usage)
        }
        
        dailyUsages[0] = DailyUsage(
            date: todayString,
            totalCost: 99.99,
            totalTokens: 200000,
            modelsUsed: ["claude-3-opus"]
        )
        
        let stats = UsageStats(
            totalCost: 50000,
            totalTokens: 10000000,
            totalInputTokens: 3000000,
            totalOutputTokens: 7000000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1000,
            byModel: [],
            byDate: dailyUsages,
            byProject: []
        )
        
        // Force set the state for direct testing
        viewModel.state = .loaded(stats)
        
        // When: Measure direct computation
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = viewModel.todaysCostValue
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let computeTime = (endTime - startTime) * 1000 // Convert to milliseconds
        
        // Then: Should compute very quickly
        XCTAssertEqual(result, 99.99)
        XCTAssertLessThan(computeTime, 10, "Direct today's cost lookup should complete within 10ms")
        
        print("Performance: Direct computation time: \(computeTime)ms for \(dailyUsages.count) daily entries")
    }
    
    // MARK: - Edge Cases
    
    func testTodaysCostWithMultipleTodayEntries() async {
        // Given: Multiple entries for today (shouldn't happen but test anyway)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let todayUsage1 = DailyUsage(
            date: todayString,
            totalCost: 25.00,
            totalTokens: 50000,
            modelsUsed: ["claude-3-opus"]
        )
        
        let todayUsage2 = DailyUsage(
            date: todayString,
            totalCost: 35.00,
            totalTokens: 70000,
            modelsUsed: ["claude-3-sonnet"]
        )
        
        mockUsageService.mockStats = UsageStats(
            totalCost: 60.00,
            totalTokens: 120000,
            totalInputTokens: 40000,
            totalOutputTokens: 80000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 2,
            byModel: [],
            byDate: [todayUsage1, todayUsage2],
            byProject: []
        )
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Should use the first matching entry
        XCTAssertEqual(viewModel.todaysCost, "$25.00")
        XCTAssertEqual(viewModel.todaysCostValue, 25.00)
    }
    
    func testTodaysCostProgressCalculation() async {
        // Given: Stats with today's data and threshold
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let todayUsage = DailyUsage(
            date: todayString,
            totalCost: 15.00,
            totalTokens: 30000,
            modelsUsed: ["claude-3-opus"]
        )
        
        mockUsageService.mockStats = UsageStats(
            totalCost: 15.00,
            totalTokens: 30000,
            totalInputTokens: 10000,
            totalOutputTokens: 20000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1,
            byModel: [],
            byDate: [todayUsage],
            byProject: []
        )
        
        mockConfigService.configuration = AppConfiguration(
            basePath: NSHomeDirectory() + "/.claude",
            refreshInterval: 30.0,
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0, // $10 threshold
            minimumRefreshInterval: 5.0
        )
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Progress should be calculated correctly
        XCTAssertEqual(viewModel.todaysCostValue, 15.00)
        XCTAssertEqual(viewModel.todaysCostProgress, 1.5) // 15/10 = 1.5, capped at 1.5
    }
}