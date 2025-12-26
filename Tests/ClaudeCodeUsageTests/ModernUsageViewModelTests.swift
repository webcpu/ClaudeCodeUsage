//
//  ModernUsageViewModelTests.swift
//  Migrated to Swift Testing Framework with modern patterns
//

import Testing
import Foundation
import SwiftUI
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage
// Import specific types from ClaudeLiveMonitorLib to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
import struct ClaudeLiveMonitorLib.TokenCounts
import struct ClaudeLiveMonitorLib.ProjectedUsage

// MARK: - Test Suite

@Suite("UsageViewModel Tests", .serialized)
@MainActor
struct ModernUsageViewModelTests {
    
    // MARK: - Test Properties
    
    fileprivate let mockContainer: TestDependencyContainer
    let viewModel: UsageViewModel
    let testDate: Date
    let testDateProvider: TestDateProvider
    
    // MARK: - Initialization
    
    init() async throws {
        // Use a fixed date for deterministic testing
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.testDate = formatter.date(from: "2024-01-15 12:00:00")!
        self.testDateProvider = TestDateProvider(fixedDate: testDate)
        
        self.mockContainer = TestDependencyContainer()
        self.viewModel = UsageViewModel(container: mockContainer, dateProvider: testDateProvider)
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Initial state should be correct")
    func testInitialState() {
        #expect(viewModel.stats == nil)
        #expect(viewModel.isLoading == true) // ViewModel starts in loading state
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.todaysCost == "$0.00")
        #expect(viewModel.totalCost == "$0.00")
    }
    
    @Test("Loading data updates state correctly")
    func testLoadingData() async throws {
        // Given
        let expectedStats = createMockStats(cost: 100.0)
        mockContainer.mockUsageDataService.statsToReturn = expectedStats
        
        // When
        await viewModel.loadData()
        
        // Then
        #expect(viewModel.stats != nil)
        #expect(viewModel.totalCost == "$100.00")
        #expect(viewModel.errorMessage == nil)
    }
    
    @Test("Error handling displays message")
    func testErrorHandling() async throws {
        // Given
        mockContainer.mockUsageDataService.shouldThrow = true
        
        // When
        await viewModel.loadData()
        
        // Then
        #expect(viewModel.stats == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.errorMessage?.contains("Error") == true)
    }
    
    // MARK: - Parameterized Tests
    
    @Test(
        "Cost formatting",
        arguments: [
            (0.0, "$0.00"),
            (1.0, "$1.00"),
            (10.50, "$10.50"),
            (100.00, "$100.00"),
            (1234.56, "$1,234.56"),
            (10000.00, "$10,000.00")
        ]
    )
    func testCostFormatting(cost: Double, expected: String) async throws {
        // Given
        let stats = createMockStats(cost: cost)
        mockContainer.mockUsageDataService.statsToReturn = stats
        
        // When
        await viewModel.loadData()
        
        // Then
        #expect(viewModel.totalCost == expected)
    }
    
    @Test(
        "Today's cost calculation",
        arguments: [
            (50.0, "$50.00"),
            (0.0, "$0.00"),
            (123.45, "$123.45")
        ]
    )
    func testTodaysCostCalculation(todayCost: Double, expected: String) async throws {
        // Given
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: testDate)
        
        let stats = UsageStats(
            totalCost: 1000.0,
            totalTokens: 10000,
            totalInputTokens: 5000,
            totalOutputTokens: 4000,
            totalCacheCreationTokens: 500,
            totalCacheReadTokens: 500,
            totalSessions: 10,
            byModel: [],
            byDate: [
                DailyUsage(
                    date: todayString,
                    totalCost: todayCost,
                    totalTokens: Int(todayCost * 100),
                    modelsUsed: ["claude-3"]
                )
            ],
            byProject: []
        )
        
        mockContainer.mockUsageDataService.statsToReturn = stats
        
        // Also set up mock entries for today
        mockContainer.mockUsageDataService.mockEntries = [
            UsageEntry(
                timestamp: testDate,
                cost: todayCost,
                model: "claude-3",
                inputTokens: Int(todayCost * 50),
                outputTokens: Int(todayCost * 50),
                sessionId: "test-session"
            )
        ]
        
        // When
        await viewModel.loadData()
        
        // Then
        #expect(viewModel.todaysCost == expected)
    }
    
    // MARK: - Async Tests with Confirmation
    
    @Test("Auto-refresh starts and stops correctly")
    func testAutoRefresh() async throws {
        // Ensure clean state - stop any existing timers
        viewModel.stopAutoRefresh()
        
        // Configure a shorter refresh interval for testing
        let config = AppConfiguration(
            basePath: NSHomeDirectory() + "/.claude",
            refreshInterval: 0.1, // Even shorter interval for faster testing
            sessionDurationHours: 5.0,
            dailyCostThreshold: 10.0,
            minimumRefreshInterval: 0.05
        )
        mockContainer.mockConfigurationService.updateConfiguration(config)
        
        // Use an actor for thread-safe call counting and signaling
        actor CallCounter {
            private var count = 0
            private var continuation: CheckedContinuation<Void, Never>?
            
            func increment() {
                count += 1
                // Signal when we reach the target count
                if count >= 3 {
                    continuation?.resume()
                    continuation = nil
                }
            }
            
            func getCount() -> Int {
                return count
            }
            
            func waitForTargetCount() async {
                await withCheckedContinuation { continuation in
                    if count >= 3 {
                        continuation.resume()
                    } else {
                        self.continuation = continuation
                    }
                }
            }
        }
        
        let callCounter = CallCounter()
        
        mockContainer.mockUsageDataService.onLoadStats = {
            Task {
                await callCounter.increment()
            }
        }
        
        // Start auto-refresh with initial load for testing
        viewModel.startAutoRefresh(performInitialLoad: true)
        
        // Wait for at least 3 calls or timeout after 2 seconds
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await callCounter.waitForTargetCount()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout
            }
            // Wait for first task to complete (either target reached or timeout)
            await group.next()
            group.cancelAll()
        }
        
        // Stop auto-refresh
        viewModel.stopAutoRefresh()
        
        // Allow brief settling time for any in-flight operations
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Verify we got at least the minimum expected calls
        let finalCount = await callCounter.getCount()
        
        #expect(finalCount >= 3, 
                "Expected at least 3 refresh calls, got \(finalCount)")
    }
    
    @Test("Concurrent loads are handled safely")
    func testConcurrentLoads() async throws {
        // Given
        let stats = createMockStats(cost: 50.0)
        mockContainer.mockUsageDataService.statsToReturn = stats
        
        // When - Load data concurrently
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await self.viewModel.loadData()
                }
            }
        }
        
        // Then - State should be consistent
        #expect(viewModel.stats != nil)
        #expect(viewModel.totalCost == "$50.00")
        #expect(viewModel.isLoading == false)
    }
    
    // MARK: - Test with Tags
    
    @Test(.tags(.performance))
    func testLoadingPerformance() async throws {
        // Given
        let largeStats = createLargeMockStats()
        mockContainer.mockUsageDataService.statsToReturn = largeStats
        
        // When/Then - Measure performance
        let start = Date()
        await viewModel.loadData()
        let duration = Date().timeIntervalSince(start)
        
        #expect(duration < 1.0, "Loading should complete within 1 second")
    }
    
    @Test(.tags(.integration))
    func testSessionMonitorIntegration() async throws {
        // Given
        let mockSession = SessionBlock(
            id: UUID().uuidString,
            startTime: testDate,
            endTime: testDate.addingTimeInterval(3600),
            actualEndTime: nil,
            isActive: true,
            isGap: false,
            entries: [],
            tokenCounts: TokenCounts(
                inputTokens: 100,
                outputTokens: 200,
                cacheCreationInputTokens: 0,
                cacheReadInputTokens: 0
            ),
            costUSD: 0.05,
            models: ["claude-3"],
            usageLimitResetTime: nil,
            burnRate: BurnRate(
                tokensPerMinute: 10,
                tokensPerMinuteForIndicator: 10,
                costPerHour: 3.0
            ),
            projectedUsage: ProjectedUsage(
                totalTokens: 600,
                totalCost: 0.10,
                remainingMinutes: 30.0
            )
        )
        
        mockContainer.mockSessionMonitorService.mockSession = mockSession

        // When
        let session = await viewModel.sessionMonitorService.getActiveSession()

        // Then
        #expect(session != nil)
        #expect(session?.costUSD == 0.05)
    }
    
    // MARK: - Disabled Tests
    
    @Test(.disabled("Placeholder for future timing-sensitive tests"))
    func testTimeSensitiveOperation() async throws {
        // This test is disabled as a placeholder
    }
    
    // MARK: - Helper Methods
    
    private func createMockStats(cost: Double) -> UsageStats {
        UsageStats(
            totalCost: cost,
            totalTokens: Int(cost * 100),
            totalInputTokens: Int(cost * 50),
            totalOutputTokens: Int(cost * 40),
            totalCacheCreationTokens: Int(cost * 5),
            totalCacheReadTokens: Int(cost * 5),
            totalSessions: Int(cost / 10),
            byModel: [],
            byDate: [],
            byProject: []
        )
    }
    
    private func createLargeMockStats() -> UsageStats {
        let dates = (0..<365).map { daysAgo in
            let date = testDate.addingTimeInterval(TimeInterval(-daysAgo * 86400))
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return DailyUsage(
                date: formatter.string(from: date),
                totalCost: Double.random(in: 1...100),
                totalTokens: Int.random(in: 100...10000),
                modelsUsed: [["claude-3", "claude-3.5"].randomElement()!]
            )
        }
        
        return UsageStats(
            totalCost: dates.reduce(0) { $0 + $1.totalCost },
            totalTokens: dates.reduce(0) { $0 + $1.totalTokens },
            totalInputTokens: 50000,
            totalOutputTokens: 40000,
            totalCacheCreationTokens: 5000,
            totalCacheReadTokens: 5000,
            totalSessions: 365,
            byModel: [],
            byDate: dates,
            byProject: []
        )
    }
}

// MARK: - Test Tags

extension Tag {
    @Tag static var performance: Self
    @Tag static var integration: Self
    @Tag static var unit: Self
    @Tag static var async: Self
}

// MARK: - Mock Test Container

fileprivate final class TestDependencyContainer: DependencyContainer {
    let mockUsageDataService = MockUsageDataService()
    let mockSessionMonitorService = MockSessionMonitorService()
    let mockConfigurationService = MockConfigurationService()
    let mockPerformanceMetrics = MockPerformanceMetrics()
    
    var usageDataService: UsageDataService { mockUsageDataService }
    var sessionMonitorService: SessionMonitorService { mockSessionMonitorService }
    var configurationService: ConfigurationService { mockConfigurationService }
    var performanceMetrics: PerformanceMetricsProtocol { mockPerformanceMetrics }
}

fileprivate final class MockUsageDataService: UsageDataService {
    var statsToReturn: UsageStats?
    var mockEntries: [UsageEntry] = []
    var shouldThrow = false
    var onLoadStats: (() -> Void)?
    
    func loadStats() async throws -> UsageStats {
        onLoadStats?()
        
        if shouldThrow {
            throw DataLoadingError.fileNotFound(path: "/mock/path")
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
        return mockEntries
    }

    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        onLoadStats?()
        if shouldThrow {
            throw DataLoadingError.fileNotFound(path: "/mock/path")
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
        return (mockEntries, stats)
    }

    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        return try await loadEntriesAndStats()
    }

    func getDateRange() -> (start: Date, end: Date) {
        let baseDate = Date() // Use current date for range calculation
        return (baseDate.addingTimeInterval(-30 * 86400), baseDate)
    }
}

fileprivate final class MockSessionMonitorService: SessionMonitorService {
    var mockSession: SessionBlock?
    var mockBurnRate: BurnRate?
    var mockTokenLimit: Int?
    
    func getActiveSession() -> SessionBlock? { mockSession }
    func getBurnRate() -> BurnRate? { mockBurnRate }
    func getAutoTokenLimit() -> Int? { mockTokenLimit }
}

fileprivate final class MockConfigurationService: ConfigurationService {
    var configuration = AppConfiguration.default
    
    func updateConfiguration(_ config: AppConfiguration) {
        self.configuration = config
    }
}

fileprivate final class MockPerformanceMetrics: PerformanceMetricsProtocol {
    func record<T>(_ operation: String, metadata: [String: Any], block: () async throws -> T) async rethrows -> T {
        try await block()
    }
    
    func getStats(for operation: String) async -> MetricStats? { nil }
    func getAllStats() async -> [MetricStats] { [] }
    func clearMetrics(for operation: String?) async { }
    func exportMetrics() async -> Data? { nil }
    func generateReport() async -> String { "" }
}