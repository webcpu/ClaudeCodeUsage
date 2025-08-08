//
//  HourlyCostChartTests.swift
//  Tests for HourlyCostChart implementation
//

import XCTest
import SwiftUI
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage

final class HourlyCostChartTests: XCTestCase {
    
    func testHourlyChartDataCreation() {
        let data = HourlyChartData(
            hour: 10,
            cost: 5.50,
            model: "claude-opus-4",
            project: "TestProject"
        )
        
        XCTAssertEqual(data.hour, 10)
        XCTAssertEqual(data.cost, 5.50)
        XCTAssertEqual(data.model, "claude-opus-4")
        XCTAssertEqual(data.project, "TestProject")
        XCTAssertEqual(data.hourLabel, "10:00")
        XCTAssertEqual(data.costLabel, "$5.50")
    }
    
    func testHourlyChartDataEmptyCost() {
        let data = HourlyChartData(
            hour: 5,
            cost: 0,
            model: nil,
            project: nil
        )
        
        XCTAssertEqual(data.hour, 5)
        XCTAssertEqual(data.cost, 0)
        XCTAssertNil(data.model)
        XCTAssertNil(data.project)
        XCTAssertEqual(data.hourLabel, "05:00")
        XCTAssertEqual(data.costLabel, "")
    }
    
    func testDetailedHourlyCostsExtraction() {
        // Create test entries
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        let entries: [UsageEntry] = [
            createTestEntry(
                date: calendar.date(byAdding: .hour, value: 9, to: today)!,
                cost: 2.50,
                model: "claude-opus-4",
                project: "ProjectA"
            ),
            createTestEntry(
                date: calendar.date(byAdding: .hour, value: 9, to: today)!,
                cost: 1.50,
                model: "claude-sonnet-4",
                project: "ProjectB"
            ),
            createTestEntry(
                date: calendar.date(byAdding: .hour, value: 10, to: today)!,
                cost: 5.00,
                model: "claude-opus-4",
                project: "ProjectA"
            ),
            createTestEntry(
                date: calendar.date(byAdding: .hour, value: 14, to: today)!,
                cost: 3.25,
                model: "claude-haiku",
                project: "ProjectC"
            )
        ]
        
        let chartData = UsageAnalytics.detailedHourlyCosts(from: entries)
        
        // Should have data for all 24 hours
        XCTAssertTrue(chartData.count >= 24)
        
        // Check specific hours with data
        let hour9Data = chartData.filter { $0.hour == 9 }
        XCTAssertTrue(hour9Data.count > 0)
        
        // Find opus and sonnet entries for hour 9
        let hour9Opus = hour9Data.first { $0.model == "claude-opus-4" }
        let hour9Sonnet = hour9Data.first { $0.model == "claude-sonnet-4" }
        
        XCTAssertNotNil(hour9Opus)
        XCTAssertNotNil(hour9Sonnet)
        XCTAssertEqual(hour9Opus?.cost ?? 0, 2.50, accuracy: 0.01)
        XCTAssertEqual(hour9Sonnet?.cost ?? 0, 1.50, accuracy: 0.01)
        
        // Check hour 10
        let hour10Data = chartData.filter { $0.hour == 10 }
        XCTAssertTrue(hour10Data.count > 0)
        let hour10Opus = hour10Data.first { $0.model == "claude-opus-4" }
        XCTAssertNotNil(hour10Opus)
        XCTAssertEqual(hour10Opus?.cost ?? 0, 5.00, accuracy: 0.01)
        
        // Check hour 14
        let hour14Data = chartData.filter { $0.hour == 14 }
        XCTAssertTrue(hour14Data.count > 0)
        let hour14Haiku = hour14Data.first { $0.model == "claude-haiku" }
        XCTAssertNotNil(hour14Haiku)
        XCTAssertEqual(hour14Haiku?.cost ?? 0, 3.25, accuracy: 0.01)
    }
    
    @MainActor
    func testChartDataServiceIntegration() async {
        let service = ChartDataService()
        
        // Load data
        await service.loadTodayHourlyCosts()
        
        // Check that data is loaded (will be empty if no real data exists)
        XCTAssertFalse(service.isLoading)
        XCTAssertNotNil(service.detailedHourlyData)
        
        // If there's data, verify structure
        if !service.detailedHourlyData.isEmpty {
            let firstData = service.detailedHourlyData.first!
            XCTAssertTrue(firstData.hour >= 0 && firstData.hour < 24)
            XCTAssertTrue(firstData.cost >= 0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestEntry(
        date: Date,
        cost: Double,
        model: String,
        project: String
    ) -> UsageEntry {
        return UsageEntry(
            project: project,
            timestamp: ISO8601DateFormatter().string(from: date),
            model: model,
            inputTokens: 100,
            outputTokens: 200,
            cacheWriteTokens: 0,
            cacheReadTokens: 0,
            cost: cost,
            sessionId: UUID().uuidString
        )
    }
}