//
//  HourlyCostChartTests.swift
//  Tests for HourlyCostChart implementation
//  Migrated to Swift Testing Framework
//

import Testing
import Foundation
import SwiftUI
@testable import UsageDashboardApp
@testable import ClaudeCodeUsage

@Suite("Hourly Cost Chart Tests")
struct HourlyCostChartTests {
    
    @Test("Hourly chart data creation")
    func hourlyChartDataCreation() {
        let data = HourlyChartData(
            hour: 10,
            cost: 5.50,
            model: "claude-opus-4",
            project: "TestProject"
        )
        
        #expect(data.hour == 10)
        #expect(data.cost == 5.50)
        #expect(data.model == "claude-opus-4")
        #expect(data.project == "TestProject")
        #expect(data.hourLabel == "10:00")
        #expect(data.costLabel == "$5.50")
    }
    
    @Test("Hourly chart data with empty cost")
    func hourlyChartDataEmptyCost() {
        let data = HourlyChartData(
            hour: 5,
            cost: 0,
            model: nil,
            project: nil
        )
        
        #expect(data.hour == 5)
        #expect(data.cost == 0)
        #expect(data.model == nil)
        #expect(data.project == nil)
        #expect(data.hourLabel == "05:00")
        #expect(data.costLabel == "")
    }
    
    @Test("Detailed hourly costs extraction")
    func detailedHourlyCostsExtraction() {
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
        #expect(chartData.count >= 24)
        
        // Check specific hours with data
        let hour9Data = chartData.filter { $0.hour == 9 }
        #expect(hour9Data.count > 0)
        
        // Find opus and sonnet entries for hour 9
        let hour9Opus = hour9Data.first { $0.model == "claude-opus-4" }
        let hour9Sonnet = hour9Data.first { $0.model == "claude-sonnet-4" }
        
        #expect(hour9Opus != nil)
        #expect(hour9Sonnet != nil)
        #expect(abs((hour9Opus?.cost ?? 0) - 2.50) < 0.01)
        #expect(abs((hour9Sonnet?.cost ?? 0) - 1.50) < 0.01)
        
        // Check hour 10
        let hour10Data = chartData.filter { $0.hour == 10 }
        #expect(hour10Data.count > 0)
        let hour10Opus = hour10Data.first { $0.model == "claude-opus-4" }
        #expect(hour10Opus != nil)
        #expect(abs((hour10Opus?.cost ?? 0) - 5.00) < 0.01)
        
        // Check hour 14
        let hour14Data = chartData.filter { $0.hour == 14 }
        #expect(hour14Data.count > 0)
        let hour14Haiku = hour14Data.first { $0.model == "claude-haiku" }
        #expect(hour14Haiku != nil)
        #expect(abs((hour14Haiku?.cost ?? 0) - 3.25) < 0.01)
    }
    
    @MainActor
    @Test("Chart data service integration")
    func chartDataServiceIntegration() async {
        let service = ChartDataService()
        
        // Load data (using new method with nil stats for testing)
        await service.loadHourlyCostsFromStats(nil)
        
        // Check that data is loaded (will be empty if no real data exists)
        #expect(service.isLoading == false)
        // detailedHourlyData is non-optional, so just check that it's not loading
        
        // If there's data, verify structure
        if !service.detailedHourlyData.isEmpty {
            let firstData = service.detailedHourlyData.first!
            #expect(firstData.hour >= 0 && firstData.hour < 24)
            #expect(firstData.cost >= 0)
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