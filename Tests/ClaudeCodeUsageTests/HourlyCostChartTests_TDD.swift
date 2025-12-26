//
//  HourlyCostChartTests_TDD.swift
//  TDD-compliant tests for hourly cost chart functionality
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit
@testable import ClaudeCodeUsage

// MARK: - User Story: Display Hourly Cost Breakdown

@Suite("As a user, I want to see my hourly costs so I can understand my usage patterns")
final class HourlyCostChartBehaviorTests {
    
    // MARK: - System Under Test
    
    private var sut: HourlyChartDataService!
    private var mockRepository: MockUsageRepository!
    private var testDate: Date!
    
    // MARK: - Setup
    
    init() {
        self.mockRepository = MockUsageRepository()
        self.sut = HourlyChartDataService(repository: mockRepository)
        
        // Fixed test date for consistent testing
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30
        self.testDate = Calendar.current.date(from: components)!
    }
    
    // MARK: - Display Requirements
    
    @Test("Should show 24 bars for each hour of the day")
    func displaysFullDayOfHours() async {
        // Given
        mockRepository.stubEntries = []
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars.count == 24)
        #expect(chartData.bars.first?.hour == 0)
        #expect(chartData.bars.last?.hour == 23)
    }
    
    @Test("Should show zero cost for hours with no usage")
    func showsZeroCostForUnusedHours() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 10, cost: 5.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        let hour9Bar = chartData.bars[9]
        let hour10Bar = chartData.bars[10]
        let hour11Bar = chartData.bars[11]
        
        #expect(hour9Bar.cost == 0.0)
        #expect(hour10Bar.cost == 5.0)
        #expect(hour11Bar.cost == 0.0)
    }
    
    // MARK: - Cost Calculation
    
    @Test("Should sum costs within the same hour")
    func sumsCostsWithinSameHour() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 14, minute: 10, cost: 10.0),
            createEntry(hour: 14, minute: 30, cost: 15.0),
            createEntry(hour: 14, minute: 45, cost: 5.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        let hour14Bar = chartData.bars[14]
        #expect(hour14Bar.cost == 30.0)
        #expect(hour14Bar.entryCount == 3)
    }
    
    @Test("Should separate costs by hour boundaries")
    func separatesCostsByHour() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 13, minute: 59, cost: 10.0),
            createEntry(hour: 14, minute: 00, cost: 20.0),
            createEntry(hour: 14, minute: 01, cost: 5.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars[13].cost == 10.0)
        #expect(chartData.bars[14].cost == 25.0)
    }
    
    // MARK: - Date Filtering
    
    @Test("Should only include entries from the specified date")
    func filtersEntriesByDate() async {
        // Given
        let yesterday = testDate.addingTimeInterval(-86400)
        let tomorrow = testDate.addingTimeInterval(86400)
        
        mockRepository.stubEntries = [
            createEntry(date: yesterday, hour: 10, cost: 100.0),
            createEntry(date: testDate, hour: 10, cost: 10.0),
            createEntry(date: tomorrow, hour: 10, cost: 200.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars[10].cost == 10.0)
        #expect(chartData.totalCost == 10.0)
    }
    
    // MARK: - Peak Hours Detection
    
    @Test("Should identify peak usage hour")
    func identifiesPeakUsageHour() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 9, cost: 10.0),
            createEntry(hour: 14, cost: 50.0),  // Peak
            createEntry(hour: 16, cost: 20.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.peakHour == 14)
        #expect(chartData.peakCost == 50.0)
    }
    
    // MARK: - Error Scenarios
    
    @Test("Should handle empty repository gracefully")
    func handlesEmptyRepository() async {
        // Given
        mockRepository.stubEntries = []
        mockRepository.shouldThrowError = false
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars.count == 24)
        #expect(chartData.totalCost == 0.0)
        #expect(chartData.bars.allSatisfy { $0.cost == 0 })
    }
    
    @Test("Should handle repository errors")
    func handlesRepositoryErrors() async {
        // Given
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = RepositoryError.fileNotFound
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.hasError == true)
        #expect(chartData.errorMessage == "Unable to load usage data")
    }
    
    // MARK: - Edge Cases
    
    @Test("Should handle midnight boundary correctly")
    func handlesMidnightBoundary() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 23, minute: 59, cost: 10.0),
            createEntry(hour: 0, minute: 0, cost: 20.0),
            createEntry(hour: 0, minute: 1, cost: 5.0)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars[23].cost == 10.0)
        #expect(chartData.bars[0].cost == 25.0)
    }
    
    @Test("Should handle very large costs")
    func handlesLargeCosts() async {
        // Given
        mockRepository.stubEntries = [
            createEntry(hour: 10, cost: 999_999.99)
        ]
        
        // When
        let chartData = await sut.generateHourlyChartData(for: testDate)
        
        // Then
        #expect(chartData.bars[10].cost == 999_999.99)
        #expect(chartData.bars[10].formattedCost == "$999,999.99")
    }
    
    // MARK: - Performance Requirements
    
    @Test("Should process large datasets efficiently")
    func handlesLargeDatasets() async {
        // Given: 1000 entries spread across the day
        var entries: [UsageEntry] = []
        for i in 0..<1000 {
            let hour = i % 24
            let minute = i % 60
            entries.append(createEntry(hour: hour, minute: minute, cost: 0.01))
        }
        mockRepository.stubEntries = entries
        
        // When
        let startTime = Date()
        let chartData = await sut.generateHourlyChartData(for: testDate)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(executionTime < 0.5) // Should complete in under 500ms for 1000 entries
        #expect(chartData.bars.count == 24)
    }
    
    // MARK: - Helper Methods
    
    private func createEntry(
        date: Date? = nil,
        hour: Int,
        minute: Int = 0,
        cost: Double
    ) -> UsageEntry {
        let entryDate = date ?? testDate!
        var components = Calendar.current.dateComponents([.year, .month, .day], from: entryDate)
        components.hour = hour
        components.minute = minute
        
        let timestamp = Calendar.current.date(from: components)!
        
        return UsageEntry(
            id: UUID().uuidString,
            timestamp: timestamp,
            cost: cost,
            model: "test-model"
        )
    }
}

// MARK: - Tooltip Behavior Tests

@Suite("As a user, I want to see details when hovering over a bar")
final class HourlyChartTooltipTests {
    
    private var sut: HourlyChartTooltipViewModel!
    
    init() {
        self.sut = HourlyChartTooltipViewModel()
    }
    
    @Test("Should show hour range in tooltip")
    func showsHourRange() {
        // Given
        let bar = HourlyBar(hour: 14, cost: 25.50, entryCount: 3)
        
        // When
        let tooltip = sut.generateTooltip(for: bar)
        
        // Then
        #expect(tooltip.timeRange == "2:00 PM - 3:00 PM")
        #expect(tooltip.cost == "$25.50")
        #expect(tooltip.entryCount == "3 requests")
    }
    
    @Test("Should format midnight correctly")
    func formatsMidnight() {
        // Given
        let bar = HourlyBar(hour: 0, cost: 10.0, entryCount: 1)
        
        // When
        let tooltip = sut.generateTooltip(for: bar)
        
        // Then
        #expect(tooltip.timeRange == "12:00 AM - 1:00 AM")
    }
    
    @Test("Should format noon correctly")
    func formatsNoon() {
        // Given
        let bar = HourlyBar(hour: 12, cost: 10.0, entryCount: 1)
        
        // When
        let tooltip = sut.generateTooltip(for: bar)
        
        // Then
        #expect(tooltip.timeRange == "12:00 PM - 1:00 PM")
    }
    
    @Test("Should handle zero cost")
    func handlesZeroCost() {
        // Given
        let bar = HourlyBar(hour: 10, cost: 0, entryCount: 0)
        
        // When
        let tooltip = sut.generateTooltip(for: bar)
        
        // Then
        #expect(tooltip.cost == "No usage")
        #expect(tooltip.entryCount == "No requests")
    }
}

// MARK: - Mock Infrastructure

final class MockUsageRepository: UsageRepositoryProtocol {
    var stubEntries: [UsageEntry] = []
    var shouldThrowError = false
    var errorToThrow: Error = RepositoryError.fileNotFound
    var loadCallCount = 0
    
    func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry] {
        loadCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return stubEntries.filter { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.startOfDay(for: entryDate) == targetDay
        }
    }
}

enum RepositoryError: Error {
    case fileNotFound
    case invalidData
    case accessDenied
}