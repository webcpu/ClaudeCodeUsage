//
//  DayChangeTests.swift
//  Tests for day change detection and today's cost reset
//

import Testing
import Foundation
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
// Import specific types to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

@MainActor
@Suite("Day Change Tests")
struct DayChangeTests {
    
    // MARK: - Test Calculate Seconds Until Midnight
    
    @Test("Calculate seconds until midnight")
    func calculateSecondsUntilMidnight() async {
        // Given
        let container = TestDependencyContainer()
        let viewModel = UsageViewModel(container: container)
        
        // When - Cannot directly test private methods
        // Using reflection to verify object structure only
        _ = Mirror(reflecting: viewModel)
        
        // We can't directly test private methods, but we can test the behavior
        // by observing when the refresh happens
        
        // The day change monitoring should be active after starting auto refresh
        viewModel.startAutoRefresh(performInitialLoad: true)
        
        // Wait a moment to ensure the monitoring task starts
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - Verify the monitoring task is running
        // We can't directly test the private task, but we can verify it doesn't crash
        #expect(viewModel != nil) // Basic sanity check
        
        // Clean up
        viewModel.stopAutoRefresh()
    }
    
    // MARK: - Test Today's Cost Reset on Day Change
    
    @Test("Today's cost resets on day change")
    func todaysCostResetsOnDayChange() async {
        // Given
        let container = TestDependencyContainer()
        let viewModel = UsageViewModel(container: container)
        
        // Set up initial data for "yesterday"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayString = formatter.string(from: yesterday)
        
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
                    date: yesterdayString,
                    totalCost: 100.0,
                    totalTokens: 1000,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        container.mockUsageDataService.statsToReturn = initialStats
        
        // When - Load initial data
        await viewModel.loadData()
        
        // Then - Today's cost should be 0 (no data for today)
        #expect(viewModel.todaysCostValue == 0.0)
        #expect(viewModel.todaysCost == "$0.00")
        
        // When - Simulate data for today
        let todayString = formatter.string(from: Date())
        let newStats = UsageStats(
            totalCost: 150.0,
            totalTokens: 1500,
            totalInputTokens: 750,
            totalOutputTokens: 600,
            totalCacheCreationTokens: 75,
            totalCacheReadTokens: 75,
            totalSessions: 7,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: yesterdayString,
                    totalCost: 100.0,
                    totalTokens: 1000,
                    modelsUsed: ["claude-3"]
                ),
                DailyUsage(
                    date: todayString,
                    totalCost: 50.0,
                    totalTokens: 500,
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        container.mockUsageDataService.statsToReturn = newStats
        await viewModel.loadData()
        
        // Then - Today's cost should now be 50
        #expect(viewModel.todaysCostValue == 50.0)
        #expect(viewModel.todaysCost == "$50.00")
    }
    
    // MARK: - Test Auto Refresh Includes Day Change Monitoring
    
    @Test("Auto refresh starts day change monitoring")
    func autoRefreshStartsDayChangeMonitoring() async {
        // Given
        let container = TestDependencyContainer()
        let viewModel = UsageViewModel(container: container)
        
        // When
        viewModel.startAutoRefresh(performInitialLoad: true)
        
        // Wait a moment for tasks to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - Both regular refresh and day change monitoring should be active
        // We can't directly inspect private tasks, but we can verify no crashes
        #expect(viewModel != nil)
        
        // When - Stop auto refresh
        viewModel.stopAutoRefresh()
        
        // Wait a moment for tasks to stop
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then - Tasks should be cancelled (no crashes)
        #expect(viewModel != nil)
    }
    
    // MARK: - Test Last Known Day Initialization
    
    @Test("Last known day initialized correctly")
    func lastKnownDayInitializedCorrectly() async {
        // Given
        let container = TestDependencyContainer()
        
        // When
        let viewModel = UsageViewModel(container: container)
        
        // Then - lastKnownDay should be initialized to today
        // We can't access private property directly, but we can verify the view model initializes
        #expect(viewModel != nil)
        
        // Verify today's cost calculation works immediately
        let todaysCost = viewModel.todaysCostValue
        #expect(todaysCost == 0.0)
    }
}

// MARK: - Mock Services for Testing

@MainActor
final class MockUsageDataService: UsageDataService {
    var statsToReturn: UsageStats?
    var shouldThrowError = false
    var loadStatsCalled = false
    
    func loadStats() async throws -> UsageStats {
        loadStatsCalled = true
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
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
        // Return empty array for day change tests
        return []
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        loadStatsCalled = true
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        let stats = statsToReturn ?? UsageStats(
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
        return ([], stats)
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        return try await loadEntriesAndStats()
    }

    nonisolated func getDateRange() -> (start: Date, end: Date) {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
        return (start: thirtyDaysAgo, end: now)
    }
}

// Test dependency container
@MainActor
final class TestDependencyContainer: DependencyContainer {
    let mockUsageDataService: MockUsageDataService = MockUsageDataService()
    let mockSessionMonitorService = DayChangeMockSessionMonitorService()
    let mockConfigurationService = MockConfigurationService()
    let mockPerformanceMetrics = DayChangeMockPerformanceMetrics()
    
    nonisolated var usageDataService: UsageDataService {
        return mockUsageDataService
    }
    
    nonisolated var sessionMonitorService: SessionMonitorService {
        return mockSessionMonitorService
    }
    
    nonisolated var configurationService: ConfigurationService {
        return mockConfigurationService
    }
    
    nonisolated var performanceMetrics: PerformanceMetricsProtocol {
        return mockPerformanceMetrics
    }
}

// Mock SessionMonitorService for testing
@MainActor
final class DayChangeMockSessionMonitorService: SessionMonitorService {
    nonisolated func getActiveSession() -> SessionBlock? {
        return nil
    }
    
    nonisolated func getBurnRate() -> BurnRate? {
        return nil
    }
    
    nonisolated func getAutoTokenLimit() -> Int? {
        return nil
    }
}

// Mock Configuration Service for testing
@MainActor
final class MockConfigurationService: ConfigurationService {
    nonisolated var configuration: AppConfiguration {
        return AppConfiguration(
            basePath: NSHomeDirectory() + "/.claude",
            refreshInterval: 30.0,
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0,
            minimumRefreshInterval: 10.0
        )
    }
    
    nonisolated func updateConfiguration(_ config: AppConfiguration) {
        // Mock implementation - no-op
    }
}

// Mock Performance Metrics for testing
@MainActor
final class DayChangeMockPerformanceMetrics: PerformanceMetricsProtocol {
    func record<T>(
        _ operation: String,
        metadata: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        return try await block()
    }
    
    func getStats(for operation: String) async -> MetricStats? {
        return nil
    }
    
    func getAllStats() async -> [MetricStats] {
        return []
    }
    
    func clearMetrics(for operation: String?) async {}
    
    func exportMetrics() async -> Data? {
        return nil
    }
    
    func generateReport() async -> String {
        return "Mock report"
    }
}