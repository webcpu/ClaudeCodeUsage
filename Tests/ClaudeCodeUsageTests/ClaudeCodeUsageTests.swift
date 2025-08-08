//
//  ClaudeCodeUsageTests.swift
//  ClaudeCodeUsage Tests
//
//  Unit tests for the SDK
//

import XCTest
@testable import ClaudeCodeUsage

final class ClaudeCodeUsageTests: XCTestCase {
    
    var client: ClaudeUsageClient!
    
    override func setUp() {
        super.setUp()
        // Use mock data for testing
        client = ClaudeUsageClient(dataSource: .mock)
    }
    
    override func tearDown() {
        client = nil
        super.tearDown()
    }
    
    // MARK: - Model Tests
    
    func testUsageEntryTotalTokens() {
        let entry = UsageEntry(
            project: "test-project",
            timestamp: ISO8601DateFormatter().string(from: Date()),
            model: "claude-opus-4",
            inputTokens: 1000,
            outputTokens: 500,
            cacheWriteTokens: 100,
            cacheReadTokens: 50,
            cost: 0.5,
            sessionId: "test-session"
        )
        
        XCTAssertEqual(entry.totalTokens, 1650)
    }
    
    func testModelUsageAverages() {
        let modelUsage = ModelUsage(
            model: "claude-opus-4",
            totalCost: 100.0,
            totalTokens: 1_000_000,
            inputTokens: 700_000,
            outputTokens: 300_000,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            sessionCount: 10
        )
        
        XCTAssertEqual(modelUsage.averageCostPerSession, 10.0)
        XCTAssertEqual(modelUsage.averageTokensPerSession, 100_000)
    }
    
    func testTimeRangeDateCalculation() {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let timeRange = TimeRange.last7Days
        let dateRange = timeRange.dateRange
        
        // Check that start date is approximately 7 days ago
        let timeDifference = abs(dateRange.start.timeIntervalSince(sevenDaysAgo))
        XCTAssertLessThan(timeDifference, 1.0) // Less than 1 second difference
        
        // Check that end date is now
        let endDifference = abs(dateRange.end.timeIntervalSince(now))
        XCTAssertLessThan(endDifference, 1.0)
    }
    
    func testModelPricingCalculation() {
        let opus4 = ModelPricing.opus4
        
        let cost = opus4.calculateCost(
            inputTokens: 1_000_000,
            outputTokens: 500_000,
            cacheWriteTokens: 100_000,
            cacheReadTokens: 50_000
        )
        
        let expectedCost = 15.0 + 37.5 + 1.875 + 0.075
        XCTAssertEqual(cost, expectedCost, accuracy: 0.001)
    }
    
    // MARK: - Client Tests
    
    func testGetUsageStats() async throws {
        let stats = try await client.getUsageStats()
        
        XCTAssertGreaterThan(stats.totalCost, 0)
        XCTAssertGreaterThan(stats.totalTokens, 0)
        XCTAssertGreaterThan(stats.totalSessions, 0)
        XCTAssertFalse(stats.byModel.isEmpty)
        XCTAssertFalse(stats.byDate.isEmpty)
        XCTAssertFalse(stats.byProject.isEmpty)
    }
    
    func testGetUsageByDateRange() async throws {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        let stats = try await client.getUsageByDateRange(
            startDate: startDate,
            endDate: endDate
        )
        
        XCTAssertNotNil(stats)
        XCTAssertGreaterThanOrEqual(stats.totalCost, 0)
    }
    
    func testGetSessionStats() async throws {
        let projects = try await client.getSessionStats(order: .descending)
        
        XCTAssertFalse(projects.isEmpty)
        
        // Check that projects are sorted by cost (descending)
        for i in 0..<projects.count - 1 {
            XCTAssertGreaterThanOrEqual(projects[i].totalCost, projects[i + 1].totalCost)
        }
    }
    
    func testGetUsageDetails() async throws {
        let entries = try await client.getUsageDetails(limit: 5)
        
        XCTAssertEqual(entries.count, 5)
        
        for entry in entries {
            XCTAssertGreaterThan(entry.totalTokens, 0)
            XCTAssertGreaterThanOrEqual(entry.cost, 0)
        }
    }
    
    // MARK: - Analytics Tests
    
    func testCostBreakdown() async throws {
        let stats = try await client.getUsageStats()
        let breakdown = UsageAnalytics.costBreakdown(from: stats)
        
        XCTAssertFalse(breakdown.isEmpty)
        
        // Check that percentages add up to approximately 100%
        let totalPercentage = breakdown.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(totalPercentage, 100.0, accuracy: 0.1)
    }
    
    func testTokenBreakdown() async throws {
        let stats = try await client.getUsageStats()
        let breakdown = UsageAnalytics.tokenBreakdown(from: stats)
        
        let total = breakdown.inputPercentage + breakdown.outputPercentage +
                   breakdown.cacheWritePercentage + breakdown.cacheReadPercentage
        
        XCTAssertEqual(total, 100.0, accuracy: 0.1)
    }
    
    func testDailyAverageCost() {
        let dailyUsage = [
            DailyUsage(date: "2024-01-01", totalCost: 10.0, totalTokens: 1000, modelsUsed: ["model1"]),
            DailyUsage(date: "2024-01-02", totalCost: 20.0, totalTokens: 2000, modelsUsed: ["model1"]),
            DailyUsage(date: "2024-01-03", totalCost: 30.0, totalTokens: 3000, modelsUsed: ["model1"])
        ]
        
        let average = UsageAnalytics.dailyAverageCost(from: dailyUsage)
        XCTAssertEqual(average, 20.0)
    }
    
    func testWeeklyTrends() {
        var dailyUsage: [DailyUsage] = []
        
        // Create 14 days of data
        for i in 0..<14 {
            let cost = i < 7 ? 10.0 : 20.0 // Second week has double the cost
            dailyUsage.append(
                DailyUsage(
                    date: "2024-01-\(String(format: "%02d", i + 1))",
                    totalCost: cost,
                    totalTokens: Int(cost * 1000),
                    modelsUsed: ["model1"]
                )
            )
        }
        
        let trend = UsageAnalytics.weeklyTrends(from: dailyUsage)
        
        XCTAssertEqual(trend.previousWeekCost, 70.0)
        XCTAssertEqual(trend.currentWeekCost, 140.0)
        XCTAssertEqual(trend.percentageChange, 100.0, accuracy: 0.1)
        XCTAssertEqual(trend.trend, .increasing)
    }
    
    func testPredictMonthlyCost() async throws {
        let stats = try await client.getUsageStats()
        let prediction = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: 7)
        
        // Prediction should be approximately 4x the weekly cost
        let expectedPrediction = (stats.totalCost / 7) * 30
        XCTAssertEqual(prediction, expectedPrediction, accuracy: 0.01)
    }
    
    // MARK: - Filtering Tests
    
    func testFilterEntriesByTimeRange() async throws {
        let entries = try await client.getUsageDetails(limit: 100)
        
        let filtered = entries.filtered(by: .last7Days)
        
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        for entry in filtered {
            if let date = entry.date {
                XCTAssertGreaterThanOrEqual(date, sevenDaysAgo)
            }
        }
    }
    
    func testFilterEntriesByModel() async throws {
        let entries = try await client.getUsageDetails(limit: 100)
        
        let opusEntries = entries.filteredByModel("opus")
        
        for entry in opusEntries {
            XCTAssertTrue(entry.model.contains("opus"))
        }
    }
    
    func testSortProjects() async throws {
        let projects = try await client.getSessionStats()
        
        let sortedByCost = projects.sorted(by: .cost)
        let sortedByTokens = projects.sorted(by: .tokens)
        let sortedByName = projects.sorted(by: .name, ascending: true)
        
        // Verify cost sorting
        for i in 0..<sortedByCost.count - 1 {
            XCTAssertGreaterThanOrEqual(sortedByCost[i].totalCost, sortedByCost[i + 1].totalCost)
        }
        
        // Verify token sorting
        for i in 0..<sortedByTokens.count - 1 {
            XCTAssertGreaterThanOrEqual(sortedByTokens[i].totalTokens, sortedByTokens[i + 1].totalTokens)
        }
        
        // Verify name sorting
        for i in 0..<sortedByName.count - 1 {
            XCTAssertLessThanOrEqual(sortedByName[i].projectName, sortedByName[i + 1].projectName)
        }
    }
    
    // MARK: - Formatting Tests
    
    func testCurrencyFormatting() {
        let value = 123.456
        XCTAssertEqual(value.asCurrency, "$123.46")
    }
    
    func testPercentageFormatting() {
        let value = 45.678
        XCTAssertEqual(value.asPercentage, "45.7%")
    }
    
    func testNumberAbbreviation() {
        XCTAssertEqual(1_234.abbreviated, "1.2K")
        XCTAssertEqual(1_234_567.abbreviated, "1.2M")
        XCTAssertEqual(1_234_567_890.abbreviated, "1.2B")
        XCTAssertEqual(123.abbreviated, "123")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfStatsCalculation() async throws {
        measure {
            Task {
                _ = try? await client.getUsageStats()
            }
        }
    }
}
