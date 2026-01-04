//
//  HeatmapStoreTests.swift
//  Behavioral tests for HeatmapStore
//

import Testing
import Foundation
@testable import ClaudeUsageCore
@testable import ClaudeUsageUI

// MARK: - Heatmap Store Tests

@Suite("HeatmapStore behavior")
@MainActor
struct HeatmapStoreTests {

    // MARK: - Dataset Generation

    @Test("generates approximately a year of weeks")
    func generatesFullYearDataset() async throws {
        let sut = HeatmapStore()
        let stats = TestDataFactory.mockStats(days: 365)

        await sut.updateStats(stats)

        let dataset = try #require(sut.dataset)
        // Date range can span 12-13 months depending on whether data crosses year boundary
        #expect(dataset.weeks.count >= 48 && dataset.weeks.count <= 60)
        #expect(sut.error == nil)
        #expect(sut.isLoading == false)
    }

    @Test("handles empty statistics gracefully")
    func handlesEmptyStats() async {
        let sut = HeatmapStore()
        let emptyStats = TestDataFactory.emptyStats()

        await sut.updateStats(emptyStats)

        #expect(sut.dataset != nil)
        #expect(sut.dataset?.totalCost == 0)
        #expect(sut.error == nil)
    }

    @Test("handles invalid date ranges with error")
    func handlesInvalidDateRange() async {
        let sut = HeatmapStore()
        let stats = TestDataFactory.statsWithInvalidDate()

        await sut.updateStats(stats)

        #expect(sut.error != nil)
        #expect(sut.dataset == nil)
    }

    // MARK: - Color Intensity

    @Test("maps costs to correct color intensities")
    func mapsColorIntensitiesCorrectly() async throws {
        let sut = HeatmapStore()
        let today = Date()
        let stats = TestDataFactory.statsWithCosts([
            (daysAgo: 10, cost: 0),    // No usage
            (daysAgo: 9, cost: 10),    // Low
            (daysAgo: 8, cost: 50),    // Medium
            (daysAgo: 7, cost: 100)    // High
        ], relativeTo: today)

        await sut.updateStats(stats)

        let dataset = try #require(sut.dataset)
        let targetDates = (7...10).map { Calendar.current.date(byAdding: .day, value: -$0, to: today)! }
            .map { Calendar.current.startOfDay(for: $0) }

        let matchingDays = dataset.allDays
            .filter { targetDates.contains(Calendar.current.startOfDay(for: $0.date)) }
            .sorted { $0.date < $1.date }

        #expect(matchingDays.count == 4)
        #expect(matchingDays[0].intensity == 0.0)
        #expect(matchingDays[1].intensity > 0 && matchingDays[1].intensity <= 0.25)
        #expect(matchingDays[2].intensity > 0.25 && matchingDays[2].intensity <= 0.75)
        #expect(matchingDays[3].intensity > 0.75)
    }

    // MARK: - Summary Statistics

    @Test("calculates summary statistics correctly")
    func calculatesSummaryStats() async throws {
        let sut = HeatmapStore()
        let stats = TestDataFactory.statsWithCosts([
            (daysAgo: 5, cost: 100),
            (daysAgo: 4, cost: 0),
            (daysAgo: 3, cost: 200),
            (daysAgo: 2, cost: 150),
            (daysAgo: 1, cost: 50)
        ], relativeTo: Date())

        await sut.updateStats(stats)

        let summary = try #require(sut.summaryStats)
        #expect(summary.daysWithUsage == 4)
        #expect(summary.maxDailyCost == 200)
        #expect(summary.totalCost == 500)
    }

    // MARK: - Today Highlighting

    @Test("marks today's date correctly")
    func marksTodayCorrectly() async throws {
        let sut = HeatmapStore()
        let stats = TestDataFactory.statsWithCosts([(daysAgo: 0, cost: 50)], relativeTo: Date())

        await sut.updateStats(stats)

        let dataset = try #require(sut.dataset)
        let todaySquare = dataset.allDays.first { $0.isToday }
        #expect(todaySquare != nil)
        #expect(todaySquare?.cost == 50)
    }

    // MARK: - Hover Interaction

    @Test("hover interaction updates and clears state")
    func hoverInteraction() async throws {
        let sut = HeatmapStore()
        let stats = TestDataFactory.mockStats(days: 30)
        await sut.updateStats(stats)

        // Hover over a valid cell (y=60 targets dayIndex 4, which is Thursday Jan 1, 2026)
        // Week 0 has nil for Sun-Wed (Dec 2025) since date range is Jan 1 - Dec 31, 2026
        let gridBounds = CGRect(x: 0, y: 0, width: 800, height: 200)
        sut.handleHover(at: CGPoint(x: 10, y: 60), in: gridBounds)

        #expect(sut.hoveredDay != nil)
        #expect(sut.tooltipPosition.x > 0)

        // End hover
        sut.endHover()
        #expect(sut.hoveredDay == nil)
    }
}

// MARK: - Performance Tests

@Suite("HeatmapStore performance")
@MainActor
struct HeatmapPerformanceTests {

    @Test("handles 365 days efficiently", .timeLimit(.minutes(1)))
    func handlesFullYearEfficiently() async {
        let sut = HeatmapStore()
        let stats = TestDataFactory.mockStats(days: 365)

        let startTime = Date()
        await sut.updateStats(stats)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration < 1.0, "Should complete in under 1 second")
        #expect(sut.dataset != nil)
    }
}

// MARK: - Test Data Factory

private enum TestDataFactory {

    // MARK: - High-Level Factory Methods (SLAP Layer 1)

    static func mockStats(days: Int) -> UsageStats {
        let dailyUsage = generateDailyUsage(days: days, relativeTo: Date())
        return buildStats(from: dailyUsage, sessionCount: days)
    }

    static func emptyStats() -> UsageStats {
        buildStats(from: [], sessionCount: 0)
    }

    static func statsWithInvalidDate() -> UsageStats {
        let invalidUsage = DailyUsage(
            date: "invalid-date",
            totalCost: 100,
            totalTokens: 1000,
            modelsUsed: ["claude-3"]
        )
        return UsageStats(
            totalCost: 100,
            tokens: TokenCounts(input: 500, output: 400, cacheCreation: 50, cacheRead: 50),
            sessionCount: 5,
            byModel: [],
            byDate: [invalidUsage],
            byProject: []
        )
    }

    static func statsWithCosts(
        _ entries: [(daysAgo: Int, cost: Double)],
        relativeTo today: Date
    ) -> UsageStats {
        let dailyUsage = entries.map { makeDailyUsage(daysAgo: $0.daysAgo, cost: $0.cost, relativeTo: today) }
        return buildStats(from: dailyUsage, sessionCount: entries.count)
    }

    // MARK: - Mid-Level Builders (SLAP Layer 2)

    private static func generateDailyUsage(days: Int, relativeTo today: Date) -> [DailyUsage] {
        (0..<days).map { dayIndex in
            makeDailyUsage(
                daysAgo: dayIndex,
                cost: Double(dayIndex * 10),
                tokens: dayIndex * 100,
                relativeTo: today
            )
        }
    }

    private static func buildStats(from dailyUsage: [DailyUsage], sessionCount: Int) -> UsageStats {
        let totalCost = sumCosts(dailyUsage)
        let totalTokens = sumTokens(dailyUsage)

        return UsageStats(
            totalCost: totalCost,
            tokens: distributeTokens(totalTokens),
            sessionCount: sessionCount,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }

    // MARK: - Pure Functions (SLAP Layer 3)

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func makeDailyUsage(
        daysAgo: Int,
        cost: Double,
        tokens: Int? = nil,
        relativeTo today: Date
    ) -> DailyUsage {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
        let tokenCount = tokens ?? Int(cost * 10)
        let modelsUsed = cost > 0 ? ["claude-3"] : []

        return DailyUsage(
            date: dateFormatter.string(from: date),
            totalCost: cost,
            totalTokens: tokenCount,
            modelsUsed: modelsUsed
        )
    }

    private static func sumCosts(_ dailyUsage: [DailyUsage]) -> Double {
        dailyUsage.map(\.totalCost).reduce(0, +)
    }

    private static func sumTokens(_ dailyUsage: [DailyUsage]) -> Int {
        dailyUsage.map(\.totalTokens).reduce(0, +)
    }

    private static func distributeTokens(_ total: Int) -> TokenCounts {
        let totalDouble = Double(total)
        return TokenCounts(
            input: Int(totalDouble * 0.6),
            output: Int(totalDouble * 0.3),
            cacheCreation: Int(totalDouble * 0.05),
            cacheRead: Int(totalDouble * 0.05)
        )
    }
}
