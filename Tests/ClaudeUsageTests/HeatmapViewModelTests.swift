//
//  HeatmapStoreTests.swift
//  Behavioral tests for HeatmapStore
//

import Testing
import Foundation
@testable import ClaudeUsageCore
@testable import ClaudeUsage

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
        #expect(dataset.weeks.count >= 48 && dataset.weeks.count <= 53)
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

        // Hover over first cell
        let gridBounds = CGRect(x: 0, y: 0, width: 800, height: 200)
        sut.handleHover(at: CGPoint(x: 10, y: 10), in: gridBounds)

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
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func mockStats(days: Int) -> UsageStats {
        let today = Date()
        let dailyUsage = (0..<days).map { i -> DailyUsage in
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today)!
            return DailyUsage(
                date: dateFormatter.string(from: date),
                totalCost: Double(i * 10),
                totalTokens: i * 100,
                modelsUsed: ["claude-3"]
            )
        }

        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }

        return UsageStats(
            totalCost: totalCost,
            tokens: TokenCounts(
                input: Int(Double(totalTokens) * 0.6),
                output: Int(Double(totalTokens) * 0.3),
                cacheCreation: Int(Double(totalTokens) * 0.05),
                cacheRead: Int(Double(totalTokens) * 0.05)
            ),
            sessionCount: days,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }

    static func emptyStats() -> UsageStats {
        UsageStats(
            totalCost: 0,
            tokens: TokenCounts(input: 0, output: 0, cacheCreation: 0, cacheRead: 0),
            sessionCount: 0,
            byModel: [],
            byDate: [],
            byProject: []
        )
    }

    static func statsWithInvalidDate() -> UsageStats {
        UsageStats(
            totalCost: 100,
            tokens: TokenCounts(input: 500, output: 400, cacheCreation: 50, cacheRead: 50),
            sessionCount: 5,
            byModel: [],
            byDate: [DailyUsage(date: "invalid-date", totalCost: 100, totalTokens: 1000, modelsUsed: ["claude-3"])],
            byProject: []
        )
    }

    static func statsWithCosts(_ entries: [(daysAgo: Int, cost: Double)], relativeTo today: Date) -> UsageStats {
        let dailyUsage = entries.map { entry -> DailyUsage in
            let date = Calendar.current.date(byAdding: .day, value: -entry.daysAgo, to: today)!
            return DailyUsage(
                date: dateFormatter.string(from: date),
                totalCost: entry.cost,
                totalTokens: Int(entry.cost * 10),
                modelsUsed: entry.cost > 0 ? ["claude-3"] : []
            )
        }

        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }

        return UsageStats(
            totalCost: totalCost,
            tokens: TokenCounts(
                input: Int(Double(totalTokens) * 0.5),
                output: Int(Double(totalTokens) * 0.4),
                cacheCreation: Int(Double(totalTokens) * 0.05),
                cacheRead: Int(Double(totalTokens) * 0.05)
            ),
            sessionCount: entries.count,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }
}
