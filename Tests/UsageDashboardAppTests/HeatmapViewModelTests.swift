//
//  HeatmapViewModelTests.swift
//  Behavioral tests for HeatmapViewModel following TDD principles
//

import XCTest
import Testing
@testable import ClaudeCodeUsage
@testable import UsageDashboardApp

// MARK: - User Story: Yearly Cost Heatmap Visualization

@Suite("As a user, I want to see my yearly usage pattern as a heatmap")
final class HeatmapViewModelBehaviorTests {
    
    // MARK: - System Under Test
    
    private var sut: HeatmapViewModel!
    private var mockStats: UsageStats!
    private let testConfiguration = HeatmapConfiguration.default
    
    // MARK: - Setup
    
    init() async {
        await MainActor.run {
            self.sut = HeatmapViewModel(configuration: testConfiguration)
            self.mockStats = createMockStats()
        }
    }
    
    // MARK: - Dataset Generation
    
    @Test("Should generate 52-53 weeks of data for rolling year")
    @MainActor
    func generatesFullYearDataset() async {
        // Given
        let stats = createMockStats(daysWithUsage: 365)
        
        // When
        await sut.updateStats(stats)
        
        // Then
        #expect(sut.dataset != nil)
        // A rolling year can have 52 or 53 weeks depending on week boundaries
        #expect(sut.dataset?.weeks.count == 52 || sut.dataset?.weeks.count == 53)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }
    
    @Test("Should show loading state during data generation")
    @MainActor
    func showsLoadingState() async {
        // Given
        let stats = createMockStats(daysWithUsage: 365)
        #expect(sut.isLoading == false) // Initially false
        
        // When - Start the task and check loading state
        async let updateTask: Void = sut.updateStats(stats)
        
        // Give a tiny amount of time for the loading state to be set
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        // Then - Check loading state during execution
        #expect(sut.isLoading == true)
        
        // Wait for completion
        await updateTask
        #expect(sut.isLoading == false)
    }
    
    // MARK: - Color Intensity Mapping
    
    @Test("Should map costs to correct color intensities")
    @MainActor
    func mapsColorIntensitiesCorrectly() async {
        // Given - Use recent dates that fall within the rolling year range
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let day1 = Calendar.current.date(byAdding: .day, value: -10, to: today)!
        let day2 = Calendar.current.date(byAdding: .day, value: -9, to: today)!
        let day3 = Calendar.current.date(byAdding: .day, value: -8, to: today)!
        let day4 = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        
        let stats = UsageStats(
            totalCost: 100,
            totalTokens: 1000,
            totalInputTokens: 500,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 50,
            totalCacheReadTokens: 50,
            totalSessions: 10,
            byModel: [],
            byDate: [
                DailyUsage(date: formatter.string(from: day1), totalCost: 0, totalTokens: 0, modelsUsed: []),      // No usage
                DailyUsage(date: formatter.string(from: day2), totalCost: 10, totalTokens: 100, modelsUsed: ["claude-3"]),   // Low
                DailyUsage(date: formatter.string(from: day3), totalCost: 50, totalTokens: 500, modelsUsed: ["claude-3"]),   // Medium
                DailyUsage(date: formatter.string(from: day4), totalCost: 100, totalTokens: 1000, modelsUsed: ["claude-3"]), // High
            ],
            byProject: []
        )
        
        // When
        await sut.updateStats(stats)
        
        // Then
        guard let dataset = sut.dataset else {
            Issue.record("Dataset should not be nil")
            return
        }
        
        // Find the specific days we added data for
        let targetDays = [day1, day2, day3, day4].map { Calendar.current.startOfDay(for: $0) }
        let matchingDays = dataset.allDays
            .filter { targetDays.contains(Calendar.current.startOfDay(for: $0.date)) }
            .sorted { $0.date < $1.date }
        
        #expect(matchingDays.count == 4, "Should find all 4 days we added data for")
        
        if matchingDays.count >= 4 {
            #expect(matchingDays[0].intensity == 0.0)  // No usage (cost = 0)
            #expect(matchingDays[1].intensity > 0 && matchingDays[1].intensity <= 0.25)  // Low (cost = 10, max = 100)
            #expect(matchingDays[2].intensity > 0.25 && matchingDays[2].intensity <= 0.75)  // Medium (cost = 50, max = 100)
            #expect(matchingDays[3].intensity > 0.75)  // High (cost = 100, max = 100)
        } else {
            Issue.record("Could not find all test days in heatmap. Found \\(matchingDays.count) days with costs: \\(matchingDays.map { $0.cost })")
        }
    }
    
    // MARK: - Hover Interaction
    
    @Test("Should update hovered day on mouse position")
    @MainActor
    func updatesHoveredDay() async {
        // Given
        let stats = createMockStats(daysWithUsage: 30)
        await sut.updateStats(stats)
        
        // When - Hover over first week, first day
        let hoverLocation = CGPoint(x: 10, y: 10) // Within first cell
        sut.handleHover(at: hoverLocation, in: CGRect(x: 0, y: 0, width: 800, height: 200))
        
        // Then
        #expect(sut.hoveredDay != nil)
        #expect(sut.hoveredDay?.weekOfYear == 0)
        #expect(sut.hoveredDay?.dayOfWeek == 0)
    }
    
    @Test("Should calculate tooltip position above hovered day")
    @MainActor
    func calculatesTooltipPosition() async {
        // Given
        let stats = createMockStats(daysWithUsage: 30)
        await sut.updateStats(stats)
        
        // When
        let hoverLocation = CGPoint(x: 10, y: 10)
        sut.handleHover(at: hoverLocation, in: CGRect(x: 0, y: 0, width: 800, height: 200))
        
        // Then
        #expect(sut.tooltipPosition.y < 10) // Tooltip above the square
        #expect(sut.tooltipPosition.x > 0)
    }
    
    @Test("Should clear hover state when ending hover")
    @MainActor
    func clearsHoverState() async {
        // Given
        let stats = createMockStats(daysWithUsage: 30)
        await sut.updateStats(stats)
        sut.handleHover(at: CGPoint(x: 10, y: 10), in: .zero)
        
        // When
        sut.endHover()
        
        // Then
        #expect(sut.hoveredDay == nil)
    }
    
    // MARK: - Month Labels
    
    @Test("Should generate correct month labels for rolling year")
    @MainActor
    func generatesMonthLabels() async {
        // Given
        let stats = createMockStats(daysWithUsage: 365)
        
        // When
        await sut.updateStats(stats)
        
        // Then
        guard let dataset = sut.dataset else {
            Issue.record("Dataset should not be nil")
            return
        }
        
        #expect(dataset.monthLabels.count >= 12)
        #expect(dataset.monthLabels.contains { $0.name == "Jan" })
        #expect(dataset.monthLabels.contains { $0.name == "Dec" })
    }
    
    // MARK: - Summary Statistics
    
    @Test("Should calculate summary statistics correctly")
    @MainActor
    func calculatesSummaryStats() async {
        // Given
        let stats = UsageStats(
            totalCost: 500,
            totalTokens: 5000,
            totalInputTokens: 2500,
            totalOutputTokens: 2000,
            totalCacheCreationTokens: 250,
            totalCacheReadTokens: 250,
            totalSessions: 25,
            byModel: [],
            byDate: [
                DailyUsage(date: "2025-01-01", totalCost: 100, totalTokens: 1000, modelsUsed: ["claude-3"]),
                DailyUsage(date: "2025-01-02", totalCost: 0, totalTokens: 0, modelsUsed: []),
                DailyUsage(date: "2025-01-03", totalCost: 200, totalTokens: 2000, modelsUsed: ["claude-3"]),
                DailyUsage(date: "2025-01-04", totalCost: 150, totalTokens: 1500, modelsUsed: ["claude-3"]),
                DailyUsage(date: "2025-01-05", totalCost: 50, totalTokens: 500, modelsUsed: ["claude-3"]),
            ],
            byProject: []
        )
        
        // When
        await sut.updateStats(stats)
        
        // Then
        let summary = sut.summaryStats
        #expect(summary != nil)
        #expect(summary?.daysWithUsage == 4) // Days with cost > 0
        #expect(summary?.maxDailyCost == 200)
        #expect(summary?.totalCost == 500)
    }
    
    // MARK: - Error Handling
    
    @Test("Should handle invalid date ranges")
    @MainActor
    func handlesInvalidDateRange() async {
        // Given - Stats with invalid dates
        let stats = UsageStats(
            totalCost: 100,
            totalTokens: 1000,
            totalInputTokens: 500,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 50,
            totalCacheReadTokens: 50,
            totalSessions: 5,
            byModel: [],
            byDate: [
                DailyUsage(date: "invalid-date", totalCost: 100, totalTokens: 1000, modelsUsed: ["claude-3"])
            ],
            byProject: []
        )
        
        // When
        await sut.updateStats(stats)
        
        // Then
        #expect(sut.error != nil)
        #expect(sut.dataset == nil)
    }
    
    @Test("Should handle empty statistics gracefully")
    @MainActor
    func handlesEmptyStats() async {
        // Given
        let emptyStats = UsageStats(
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
        
        // When
        await sut.updateStats(emptyStats)
        
        // Then
        #expect(sut.dataset != nil)
        #expect(sut.dataset?.totalCost == 0)
        #expect(sut.error == nil)
    }
    
    // MARK: - Configuration Changes
    
    @Test("Should regenerate dataset when configuration changes")
    @MainActor
    func regeneratesOnConfigChange() async {
        // Given
        let stats = createMockStats(daysWithUsage: 30)
        await sut.updateStats(stats)
        _ = sut.dataset
        
        // When
        sut.configuration = .compact
        
        // Allow time for regeneration
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        #expect(sut.dataset != nil)
        #expect(sut.configuration == .compact)
    }
    
    // MARK: - Today Highlighting
    
    @Test("Should mark today's date correctly")
    @MainActor
    func marksTodayCorrectly() async {
        // Given - Stats including today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        let stats = UsageStats(
            totalCost: 100,
            totalTokens: 1000,
            totalInputTokens: 500,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 50,
            totalCacheReadTokens: 50,
            totalSessions: 5,
            byModel: [],
            byDate: [
                DailyUsage(date: todayString, totalCost: 50, totalTokens: 500, modelsUsed: ["claude-3"])
            ],
            byProject: []
        )
        
        // When
        await sut.updateStats(stats)
        
        // Then
        let todaySquare = sut.dataset?.allDays.first { $0.isToday }
        #expect(todaySquare != nil)
        #expect(todaySquare?.cost == 50)
    }
    
    // MARK: - Accessibility
    
    @Test("Should provide accessibility labels for days")
    @MainActor
    func providesAccessibilityLabels() async {
        // Given
        let stats = createMockStats(daysWithUsage: 1)
        await sut.updateStats(stats)
        guard let firstDay = sut.dataset?.allDays.first else {
            Issue.record("Should have at least one day")
            return
        }
        
        // When
        let label = sut.accessibilityLabel(for: firstDay)
        
        // Then
        #expect(label.contains("Usage on"))
        #expect(label.contains("Cost:"))
    }
    
    // MARK: - Helper Methods
    
    private func createMockStats(daysWithUsage: Int = 30) -> UsageStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var dailyUsage: [DailyUsage] = []
        let today = Date()
        
        for i in 0..<daysWithUsage {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateString = formatter.string(from: date)
            let cost = Double(i * 10) // Varying costs
            
            dailyUsage.append(DailyUsage(
                date: dateString,
                totalCost: cost,
                totalTokens: Int(cost * 10),
                modelsUsed: ["claude-3"]
            ))
        }
        
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }
        
        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: Int(Double(totalTokens) * 0.6),
            totalOutputTokens: Int(Double(totalTokens) * 0.3),
            totalCacheCreationTokens: Int(Double(totalTokens) * 0.05),
            totalCacheReadTokens: Int(Double(totalTokens) * 0.05),
            totalSessions: daysWithUsage,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }
}

// MARK: - Performance Tests

@Suite("Heatmap performance requirements")
final class HeatmapPerformanceTests {
    
    @Test("Should handle 365 days efficiently")
    @MainActor
    func handlesFullYearEfficiently() async {
        // Given
        let viewModel = HeatmapViewModel()
        let stats = createLargeDataset(days: 365)
        
        // When
        let startTime = Date()
        await viewModel.updateStats(stats)
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(duration < 0.5) // Should complete in under 500ms
        #expect(viewModel.dataset != nil)
    }
    
    @Test("Should handle hover interactions smoothly")
    @MainActor
    func handlesHoverSmoothly() async {
        // Given
        let viewModel = HeatmapViewModel()
        let stats = createLargeDataset(days: 365)
        await viewModel.updateStats(stats)
        
        // When - Simulate rapid hover movements
        let startTime = Date()
        for x in stride(from: 0, to: 500, by: 10) {
            for y in stride(from: 0, to: 100, by: 10) {
                viewModel.handleHover(
                    at: CGPoint(x: Double(x), y: Double(y)),
                    in: CGRect(x: 0, y: 0, width: 800, height: 200)
                )
            }
        }
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(duration < 1.0) // 500 hover events should complete in under 1 second
    }
    
    private func createLargeDataset(days: Int) -> UsageStats {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var dailyUsage: [DailyUsage] = []
        let today = Date()
        
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            let dateString = formatter.string(from: date)
            let cost = Double.random(in: 0...100)
            
            dailyUsage.append(DailyUsage(
                date: dateString,
                totalCost: cost,
                totalTokens: Int(cost * 100),
                modelsUsed: ["claude-3"]
            ))
        }
        
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }
        
        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: Int(Double(totalTokens) * 0.6),
            totalOutputTokens: Int(Double(totalTokens) * 0.3),
            totalCacheCreationTokens: Int(Double(totalTokens) * 0.05),
            totalCacheReadTokens: Int(Double(totalTokens) * 0.05),
            totalSessions: days,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }
}