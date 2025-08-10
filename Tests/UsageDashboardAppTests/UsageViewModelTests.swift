//
//  UsageViewModelTests.swift
//  Migrated to Swift Testing Framework
//

import Testing
import Foundation
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
// Import specific types to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

// MARK: - Main Test Suite

@Suite("UsageViewModel Tests", .serialized)
@MainActor
struct UsageViewModelTests {
    
    // MARK: - Mock Dependencies
    
    final class MockUsageDataService: UsageDataService {
        var mockStats: UsageStats?
        var mockEntries: [UsageEntry] = []
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
        
        func loadEntries() async throws -> [UsageEntry] {
            return mockEntries
        }
        
        func getDateRange() -> (start: Date, end: Date) {
            return (Date.distantPast, Date())
        }
    }
    
    final class MockSessionMonitorService: SessionMonitorService {
        func getActiveSession() -> SessionBlock? { nil }
        func getBurnRate() -> BurnRate? { nil }
        func getAutoTokenLimit() -> Int? { nil }
    }
    
    final class MockConfigurationService: ConfigurationService {
        var configuration = AppConfiguration.default
        func updateConfiguration(_ config: AppConfiguration) {
            self.configuration = config
        }
    }
    
    final class MockDependencyContainer: DependencyContainer {
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
    
    // MARK: - Test Properties
    
    let viewModel: UsageViewModel
    let mockUsageService: MockUsageDataService
    let mockSessionService: MockSessionMonitorService
    let mockConfigService: MockConfigurationService
    let mockContainer: MockDependencyContainer
    let testDate: Date
    let testDateProvider: TestDateProvider
    
    // MARK: - Initialization
    
    init() async throws {
        // Use a fixed date for deterministic testing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.testDate = formatter.date(from: "2025-01-08 12:00:00")!
        self.testDateProvider = TestDateProvider(fixedDate: testDate)
        
        self.mockUsageService = MockUsageDataService()
        self.mockSessionService = MockSessionMonitorService()
        self.mockConfigService = MockConfigurationService()
        self.mockContainer = MockDependencyContainer(
            usageDataService: mockUsageService,
            sessionMonitorService: mockSessionService,
            configurationService: mockConfigService
        )
        
        self.viewModel = UsageViewModel(container: mockContainer, dateProvider: testDateProvider)
    }
    
    // MARK: - Today's Cost Tests
    
    @Test("Today's cost with no data shows $0.00")
    func testTodaysCostWithNoData() async {
        // Given: No stats available
        mockUsageService.mockStats = nil
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should be $0.00
        #expect(viewModel.todaysCost == "$0.00")
        #expect(viewModel.todaysCostValue == 0.0)
    }
    
    @Test("Today's cost with empty stats shows $0.00")
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
        #expect(viewModel.todaysCost == "$0.00")
        #expect(viewModel.todaysCostValue == 0.0)
    }
    
    @Test("Today's cost reflects today's data correctly")
    func testTodaysCostWithTodayData() async {
        // Given: Stats with today's data
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
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
        
        // Also set up mock entries for today
        mockUsageService.mockEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: 42.50,
                model: "claude-3-opus",
                inputTokens: 50000,
                outputTokens: 50000,
                sessionId: "test-session"
            )
        ]
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Today's cost should reflect the data
        #expect(viewModel.todaysCost == "$42.50")
        #expect(viewModel.todaysCostValue == 42.50)
    }
    
    @Test("Today's cost is $0.00 without today's data")
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
        #expect(viewModel.todaysCost == "$0.00")
        #expect(viewModel.todaysCostValue == 0.0)
    }
    
    // MARK: - Performance Tests
    
    @Test("Today's cost computation performs well with large dataset", .tags(.performance))
    func testTodaysCostComputationPerformance() async throws {
        // Given: Large dataset
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        var dailyUsages: [DailyUsage] = []
        
        // Add 365 days of data
        for i in 0..<365 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: testDate)!
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
        
        // Set up mock entries for today
        mockUsageService.mockEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: 75.25,
                model: "claude-3-opus",
                inputTokens: 75000,
                outputTokens: 75000,
                sessionId: "test-session"
            )
        ]
        
        // When: Measure today's cost computation
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadData()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let totalTime = endTime - startTime
        
        // Then: Should compute quickly
        #expect(viewModel.todaysCost == "$75.25")
        #expect(viewModel.todaysCostValue == 75.25)
        #expect(totalTime < 0.1, "Today's cost computation should complete within 100ms")
        
        print("Performance: Total load time: \(totalTime * 1000)ms")
        print("Performance: Stats loading time: \(mockUsageService.loadStatsTime * 1000)ms")
    }
    
    @Test("Direct today's cost computation is fast", .tags(.performance))
    func testTodaysCostComputationDirectPerformance() {
        // Given: Large dataset directly on the view model
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        var dailyUsages: [DailyUsage] = []
        for i in 0..<1000 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: testDate)!
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
        
        // Set today entries to calculate from
        viewModel.todayEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: 99.99,
                model: "claude-3-opus",
                inputTokens: 100000,
                outputTokens: 100000,
                sessionId: "test-session"
            )
        ]
        
        // When: Measure direct computation
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = viewModel.todaysCostValue
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let computeTime = (endTime - startTime) * 1000 // Convert to milliseconds
        
        // Then: Should compute very quickly
        #expect(result == 99.99)
        #expect(computeTime < 10, "Direct today's cost lookup should complete within 10ms")
        
        print("Performance: Direct computation time: \(computeTime)ms for \(dailyUsages.count) daily entries")
    }
    
    // MARK: - Edge Cases
    
    @Test("Multiple today entries uses sum of all entries")
    func testTodaysCostWithMultipleTodayEntries() async {
        // Given: Multiple entries for today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        let todayUsage = DailyUsage(
            date: todayString,
            totalCost: 60.00,
            totalTokens: 120000,
            modelsUsed: ["claude-3-opus", "claude-3-sonnet"]
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
            byDate: [todayUsage],
            byProject: []
        )
        
        // Set up multiple entries for today
        mockUsageService.mockEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: 25.00,
                model: "claude-3-opus",
                inputTokens: 25000,
                outputTokens: 25000,
                sessionId: "session-1"
            ),
            UsageEntry(
                timestamp: testDate.addingTimeInterval(3600),
                cost: 35.00,
                model: "claude-3-sonnet",
                inputTokens: 35000,
                outputTokens: 35000,
                sessionId: "session-2"
            )
        ]
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Should sum all entries for today
        #expect(viewModel.todaysCost == "$60.00")
        #expect(viewModel.todaysCostValue == 60.00)
    }
    
    @Test("Today's cost progress calculation")
    func testTodaysCostProgressCalculation() async {
        // Given: Stats with today's data and threshold
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
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
        
        // Set up mock entries for today
        mockUsageService.mockEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: 15.00,
                model: "claude-3-opus",
                inputTokens: 10000,
                outputTokens: 20000,
                sessionId: "test-session"
            )
        ]
        
        mockConfigService.configuration = AppConfiguration(
            basePath: NSHomeDirectory() + "/.claude",
            refreshInterval: 30.0,
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0, // $10 threshold
            minimumRefreshInterval: 5.0
        )
        
        // Re-create viewModel with updated config
        let updatedContainer = MockDependencyContainer(
            usageDataService: mockUsageService,
            sessionMonitorService: mockSessionService,
            configurationService: mockConfigService
        )
        let updatedViewModel = UsageViewModel(container: updatedContainer, dateProvider: testDateProvider)
        
        // When: Load data
        await updatedViewModel.loadData()
        
        // Then: Progress should be calculated correctly
        #expect(updatedViewModel.todaysCostValue == 15.00)
        #expect(updatedViewModel.todaysCostProgress == 1.5) // 15/10 = 1.5, capped at 1.5
    }
}