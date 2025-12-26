//
//  ChartDataSyncTests.swift
//  Tests for chart data synchronization with today's cost
//

import Testing
import Foundation
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage

// Custom mock for this test file
final class ChartSyncMockUsageDataService: UsageDataService {
    var mockStats: UsageStats?
    var mockEntries: [UsageEntry] = []
    let testDate: Date
    
    init(testDate: Date) {
        self.testDate = testDate
    }
    
    func loadStats() async throws -> UsageStats {
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 1)
        }
        return stats
    }
    
    func loadEntries() async throws -> [UsageEntry] {
        return mockEntries
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 1)
        }
        return (mockEntries, stats)
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        return try await loadEntriesAndStats()
    }

    func getDateRange() -> (start: Date, end: Date) {
        (testDate.addingTimeInterval(-30 * 24 * 60 * 60), testDate)
    }
}

@Suite("Chart Data Sync Tests")
struct ChartDataSyncTests {
    
    @MainActor
    @Test("Chart data syncs with today's cost")
    func chartDataSyncsWithTodaysCost() async throws {
        // Given: Use fixed date for deterministic testing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let testDate = formatter.date(from: "2024-01-15 12:00:00")!
        let testDateProvider = TestDateProvider(fixedDate: testDate)
        
        // Create test data model with mock service
        let mockService = ChartSyncMockUsageDataService(testDate: testDate)
        let container = TestContainer(usageDataService: mockService)
        let dataModel = UsageDataModel(container: container, dateProvider: testDateProvider)
        
        // Create mock stats with today's data
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        let mockStats = UsageStats(
            totalCost: 200.0,
            totalTokens: 100000,
            totalInputTokens: 50000,
            totalOutputTokens: 50000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 128.49,  // Matching the value from the screenshot
                    totalTokens: 60000,
                    modelsUsed: ["claude-3.5-sonnet"]
                )
            ],
            byProject: []
        )
        
        mockService.mockStats = mockStats
        
        // Create mock entries for today with matching cost
        mockService.mockEntries = [
            UsageEntry(
                id: "1",
                timestamp: testDate,
                cost: 128.49,
                model: "claude-3.5-sonnet",
                inputTokens: 30000,
                outputTokens: 30000,
                sessionId: "session1"
            )
        ]
        
        // When: Load data
        await dataModel.loadData()
        
        // Allow chart data to sync
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then: Verify today's cost matches
        #expect(dataModel.todaysCost == "$128.49")
        
        // Verify chart total matches today's cost
        let chartTotal = dataModel.chartDataService.todayHourlyCosts.reduce(0, +)
        let todaysCostValue = dataModel.todaysCostValue
        
        print("Today's cost: $\(String(format: "%.2f", todaysCostValue))")
        print("Chart total: $\(String(format: "%.2f", chartTotal))")
        print("Chart hourly costs: \(dataModel.chartDataService.todayHourlyCosts)")
        
        // Allow for small floating point differences
        #expect(abs(chartTotal - todaysCostValue) < 0.01)
    }
    
    @MainActor
    @Test("Chart updates on refresh")
    func chartUpdatesOnRefresh() async throws {
        // Given: Use fixed date for deterministic testing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let testDate = formatter.date(from: "2024-01-15 12:00:00")!
        
        // Initial data with mock service
        let mockService = ChartSyncMockUsageDataService(testDate: testDate)
        let container = TestContainer(usageDataService: mockService)
        let dataModel = UsageDataModel(container: container, dateProvider: TestDateProvider(fixedDate: testDate))
        
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        // Initial stats
        let initialStats = UsageStats(
            totalCost: 100.0,
            totalTokens: 50000,
            totalInputTokens: 25000,
            totalOutputTokens: 25000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 50.0,
                    totalTokens: 25000,
                    modelsUsed: ["claude-3.5-sonnet"]
                )
            ],
            byProject: []
        )
        
        mockService.mockStats = initialStats
        
        // Create initial mock entries
        mockService.mockEntries = [
            UsageEntry(
                id: "1",
                timestamp: testDate,
                cost: 50.0,
                model: "claude-3.5-sonnet",
                inputTokens: 12500,
                outputTokens: 12500,
                sessionId: "session1"
            )
        ]
        
        await dataModel.loadData()
        
        // Verify initial state
        let initialChartTotal = dataModel.chartDataService.todayHourlyCosts.reduce(0, +)
        #expect(abs(initialChartTotal - 50.0) < 0.01)
        
        // When: Update with new data
        let updatedStats = UsageStats(
            totalCost: 200.0,
            totalTokens: 100000,
            totalInputTokens: 50000,
            totalOutputTokens: 50000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 2,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 128.49,
                    totalTokens: 60000,
                    modelsUsed: ["claude-3.5-sonnet"]
                )
            ],
            byProject: []
        )
        
        mockService.mockStats = updatedStats
        
        // Update mock entries with new data  
        mockService.mockEntries = [
            UsageEntry(
                id: "1",
                timestamp: testDate,
                cost: 128.49,
                model: "claude-3.5-sonnet",
                inputTokens: 30000,
                outputTokens: 30000,
                sessionId: "session1"
            )
        ]
        await dataModel.handleAppBecameActive()
        
        // Allow time for async operations
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Chart should update
        let updatedChartTotal = dataModel.chartDataService.todayHourlyCosts.reduce(0, +)
        #expect(abs(updatedChartTotal - 128.49) < 0.01)
    }
    
    @MainActor  
    @Test("Chart data callback triggers on data load")
    func chartDataCallbackTriggersOnDataLoad() async throws {
        // Given: Use fixed date and setup with callback tracking
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let testDate = formatter.date(from: "2024-01-15 12:00:00")!
        let testDateProvider = TestDateProvider(fixedDate: testDate)
        
        let mockService = ChartSyncMockUsageDataService(testDate: testDate)
        let container = TestContainer(usageDataService: mockService)
        let viewModel = UsageViewModel(container: container, dateProvider: testDateProvider)
        
        var callbackTriggered = false
        viewModel.onDataLoaded = {
            callbackTriggered = true
        }
        
        // Set up minimal mock data for successful load
        mockService.mockStats = UsageStats(
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
        mockService.mockEntries = []
        
        // When: Load data
        await viewModel.loadData()
        
        // Then: Callback should be triggered
        #expect(callbackTriggered)
    }
    
    @MainActor
    @Test("Today's cost always matches chart total")
    func todaysCostAlwaysMatchesChartTotal() async throws {
        // Given: Use fixed date for deterministic testing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let testDate = formatter.date(from: "2024-01-15 12:00:00")!
        
        // Create test data with various entries
        let mockService = ChartSyncMockUsageDataService(testDate: testDate)
        let container = TestContainer(usageDataService: mockService)
        let dataModel = UsageDataModel(container: container, dateProvider: TestDateProvider(fixedDate: testDate))
        
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        // Create entries at different hours with different costs
        let calendar = Calendar.current
        var testEntries: [UsageEntry] = []
        
        // Add entries at different hours
        for hour in [2, 8, 14, 20] {
            var components = calendar.dateComponents([.year, .month, .day], from: testDate)
            components.hour = hour
            components.minute = 30
            if let entryDate = calendar.date(from: components) {
                testEntries.append(UsageEntry(
                    timestamp: entryDate,
                    cost: Double(hour) * 5.0, // Different cost per hour
                    model: "claude-3.5-sonnet",
                    inputTokens: 1000,
                    outputTokens: 500,
                    sessionId: "session-\(hour)"
                ))
            }
        }
        
        mockService.mockEntries = testEntries
        
        // Calculate expected total
        let expectedTotal = testEntries.reduce(0.0) { $0 + $1.cost }
        
        // Create stats that might have different value (to test we use entries, not stats)
        mockService.mockStats = UsageStats(
            totalCost: 1000.0, // Different from actual
            totalTokens: 100000,
            totalInputTokens: 50000,
            totalOutputTokens: 50000,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 1,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: 999.99, // Intentionally different to test we use entries
                    totalTokens: 60000,
                    modelsUsed: ["claude-3.5-sonnet"]
                )
            ],
            byProject: []
        )
        
        // When: Load data
        await dataModel.loadData()
        
        // Allow chart to sync
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Today's cost should match chart total exactly
        let todaysCostValue = dataModel.todaysCostValue
        let chartTotal = dataModel.chartDataService.todayHourlyCosts.reduce(0, +)
        
        print("Expected total: $\(String(format: "%.2f", expectedTotal))")
        print("Today's cost: $\(String(format: "%.2f", todaysCostValue))")
        print("Chart total: $\(String(format: "%.2f", chartTotal))")
        
        // Both should match the actual entries total, not the stats
        #expect(abs(todaysCostValue - expectedTotal) < 0.01)
        #expect(abs(chartTotal - expectedTotal) < 0.01)
        #expect(abs(todaysCostValue - chartTotal) < 0.01)
    }
}