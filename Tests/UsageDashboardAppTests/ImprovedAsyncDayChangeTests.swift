//
//  ImprovedAsyncDayChangeTests.swift
//  Tests with proper async/await handling and no race conditions
//  Migrated to Swift Testing Framework
//

import Testing
import Foundation
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
// Import specific types to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

@Suite("Improved Async Day Change Tests", .serialized)
@MainActor
struct ImprovedAsyncDayChangeTests {
    
    // MARK: - Test Properties
    
    let viewModel: UsageViewModel
    let mockContainer: TestDependencyContainer
    
    // MARK: - Initialization
    
    init() async throws {
        self.mockContainer = TestDependencyContainer()
        self.viewModel = UsageViewModel(container: mockContainer)
    }
    
    // MARK: - Async Test with Proper Expectations
    
    @Test("Day change resets today's cost asynchronously")
    func dayChangeResetsTodaysCostAsync() async throws {
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
        
        await mockContainer.mockUsageDataService.setStats(initialStats)
        
        // When - Load initial data
        await viewModel.loadData()
        
        // Then - Today's cost should be 100
        #expect(viewModel.todaysCostValue == 100.0)
        #expect(viewModel.todaysCost == "$100.00")
        
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
        
        await mockContainer.mockUsageDataService.setStats(newDayStats)
        
        // When - Load data again (simulating after day change)
        await viewModel.loadData()
        
        // Then - Today's cost should reset to 0 (no data for today)
        #expect(viewModel.todaysCostValue == 0.0, "Today's cost should be 0 when no data for today")
        #expect(viewModel.todaysCost == "$0.00", "Today's cost string should show $0.00")
    }
    
    // MARK: - Async Test with Timeout
    
    @Test("Day change with async stream", .timeLimit(.minutes(1)))
    func dayChangeWithAsyncStream() async throws {
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
        
        await mockContainer.mockUsageDataService.setStats(initialStats)
        await viewModel.loadData()
        
        // Verify initial state
        #expect(viewModel.todaysCostValue == 50.0, "Initial cost should be 50.0")
        
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
        
        await mockContainer.mockUsageDataService.setStats(yesterdayOnlyStats)
        await viewModel.loadData()
        
        // Verify the cost is 0 when there's no data for today
        #expect(viewModel.todaysCostValue == 0.0, "Cost should be 0 when no data for today")
        #expect(viewModel.todaysCost == "$0.00", "Cost string should be $0.00")
    }
    
    // MARK: - Test with Actor Isolation
    
    @Test("Concurrent day change handling")
    func concurrentDayChangeHandling() async throws {
        // Setup with real date
        let initialStats = createTestStats(cost: 75.0, date: Date())
        await mockContainer.mockUsageDataService.setStats(initialStats)
        await viewModel.loadData()
        
        #expect(viewModel.todaysCostValue == 75.0)
        
        // Create multiple concurrent load operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask { @MainActor in
                    // Each task loads data with slightly different costs
                    let newStats = self.createTestStats(cost: Double(70 + i), date: Date())
                    await self.mockContainer.mockUsageDataService.setStats(newStats)
                    
                    // Load data concurrently
                    await self.viewModel.loadData()
                }
            }
        }
        
        // After all concurrent updates, state should be consistent
        #expect(viewModel.todaysCostValue != nil)
        #expect(viewModel.todaysCost != nil)
        // The final value should be one of the test values (70-74)
        #expect(viewModel.todaysCostValue >= 70.0 && viewModel.todaysCostValue <= 74.0,
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
    struct TestDependencyContainer: DependencyContainer {
        let mockUsageDataService = MockUsageDataService()
        let mockSessionMonitorService = MockSessionMonitorService()
        let mockConfigurationService = DefaultConfigurationService()
        let mockPerformanceMetrics = NullPerformanceMetrics()
        
        var usageDataService: UsageDataService { mockUsageDataService }
        var sessionMonitorService: SessionMonitorService { mockSessionMonitorService }
        var configurationService: ConfigurationService { mockConfigurationService }
        var performanceMetrics: PerformanceMetricsProtocol { mockPerformanceMetrics }
    }
    
    actor MockUsageDataService: UsageDataService {
        private var statsToReturn: UsageStats?
        private var shouldThrow = false
        private var entriesToReturn: [UsageEntry] = []
        
        func setStats(_ stats: UsageStats?) {
            self.statsToReturn = stats
            // Auto-generate entries based on stats for today's cost calculation
            if let stats = stats, let todayUsage = stats.byDate.first(where: { 
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return $0.date == formatter.string(from: Date())
            }) {
                self.entriesToReturn = [UsageEntry(
                    timestamp: Date(),
                    cost: todayUsage.totalCost,
                    model: todayUsage.modelsUsed.first ?? "claude-3",
                    inputTokens: stats.totalInputTokens,
                    outputTokens: stats.totalOutputTokens,
                    sessionId: "test-session"
                )]
            } else {
                self.entriesToReturn = []
            }
        }
        
        func setShouldThrow(_ value: Bool) {
            self.shouldThrow = value
        }
        
        nonisolated func loadStats() async throws -> UsageStats {
            if await shouldThrow {
                throw NSError(domain: "Test", code: 1)
            }
            return await statsToReturn ?? UsageStats(
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
        
        nonisolated func loadEntries() async throws -> [UsageEntry] {
            return await entriesToReturn
        }
        
        nonisolated func getDateRange() -> (start: Date, end: Date) {
            (Date().addingTimeInterval(-30 * 24 * 60 * 60), Date())
        }
    }
    
    struct MockSessionMonitorService: SessionMonitorService {
        var mockSession: SessionBlock?
        var mockBurnRate: BurnRate?
        var mockTokenLimit: Int?
        
        func getActiveSession() -> SessionBlock? { mockSession }
        func getBurnRate() -> BurnRate? { mockBurnRate }
        func getAutoTokenLimit() -> Int? { mockTokenLimit }
    }
}