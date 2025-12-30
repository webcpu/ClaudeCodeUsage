//
//  UsageAggregatorTests.swift
//  ClaudeUsageCoreTests
//

import Testing
import Foundation
@testable import ClaudeUsageCore

@Suite("UsageAggregator")
struct UsageAggregatorTests {

    // MARK: - Aggregate

    @Test("aggregates empty entries to empty stats")
    func aggregatesEmptyEntries() {
        let result = UsageAggregator.aggregate([])

        #expect(result.totalCost == 0)
        #expect(result.tokens == .zero)
        #expect(result.sessionCount == 0)
        #expect(result.byModel.isEmpty)
        #expect(result.byDate.isEmpty)
        #expect(result.byProject.isEmpty)
    }

    @Test("aggregates single entry correctly")
    func aggregatesSingleEntry() {
        let entry = TestEntryFactory.entry(cost: 1.50, tokens: TokenCounts(input: 1000, output: 500))
        let result = UsageAggregator.aggregate([entry])

        #expect(result.totalCost == 1.50)
        #expect(result.tokens.input == 1000)
        #expect(result.tokens.output == 500)
        #expect(result.sessionCount == 1)
    }

    @Test("sums costs and tokens from multiple entries")
    func sumsCostsAndTokens() {
        let entries = [
            TestEntryFactory.entry(cost: 1.00, tokens: TokenCounts(input: 100, output: 50)),
            TestEntryFactory.entry(cost: 2.00, tokens: TokenCounts(input: 200, output: 100)),
            TestEntryFactory.entry(cost: 0.50, tokens: TokenCounts(input: 50, output: 25))
        ]
        let result = UsageAggregator.aggregate(entries)

        #expect(result.totalCost == 3.50)
        #expect(result.tokens.input == 350)
        #expect(result.tokens.output == 175)
    }

    // MARK: - Aggregate By Model

    @Test("groups entries by model")
    func groupsByModel() {
        let entries = [
            TestEntryFactory.entry(model: "claude-opus", cost: 5.00),
            TestEntryFactory.entry(model: "claude-sonnet", cost: 3.00),
            TestEntryFactory.entry(model: "claude-opus", cost: 2.00),
            TestEntryFactory.entry(model: "claude-haiku", cost: 0.50)
        ]
        let result = UsageAggregator.aggregateByModel(entries)

        #expect(result.count == 3)

        let opusUsage = result.first { $0.model == "claude-opus" }
        #expect(opusUsage?.totalCost == 7.00)

        let sonnetUsage = result.first { $0.model == "claude-sonnet" }
        #expect(sonnetUsage?.totalCost == 3.00)
    }

    @Test("sorts models by cost descending")
    func sortsModelsByCostDescending() {
        let entries = [
            TestEntryFactory.entry(model: "haiku", cost: 1.00),
            TestEntryFactory.entry(model: "opus", cost: 10.00),
            TestEntryFactory.entry(model: "sonnet", cost: 5.00)
        ]
        let result = UsageAggregator.aggregateByModel(entries)

        #expect(result[0].model == "opus")
        #expect(result[1].model == "sonnet")
        #expect(result[2].model == "haiku")
    }

    // MARK: - Aggregate By Date

    @Test("groups entries by date string")
    func groupsByDate() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let entries = [
            TestEntryFactory.entry(timestamp: today, cost: 2.00),
            TestEntryFactory.entry(timestamp: today, cost: 1.00),
            TestEntryFactory.entry(timestamp: yesterday, cost: 5.00)
        ]
        let result = UsageAggregator.aggregateByDate(entries)

        #expect(result.count == 2)

        // Results sorted ascending by date
        #expect(result[0].totalCost == 5.00) // yesterday
        #expect(result[1].totalCost == 3.00) // today
    }

    @Test("sorts dates ascending")
    func sortsDatesAscending() {
        let dates = (0..<5).map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! }
        let entries = dates.map { TestEntryFactory.entry(timestamp: $0, cost: 1.00) }

        let result = UsageAggregator.aggregateByDate(entries)

        #expect(result.count == 5)
        #expect(result[0].date < result[4].date) // First is oldest
    }

    // MARK: - Aggregate By Project

    @Test("groups entries by project path")
    func groupsByProject() {
        let entries = [
            TestEntryFactory.entry(cost: 10.00, project: "/Users/dev/project-a"),
            TestEntryFactory.entry(cost: 5.00, project: "/Users/dev/project-b"),
            TestEntryFactory.entry(cost: 3.00, project: "/Users/dev/project-a")
        ]
        let result = UsageAggregator.aggregateByProject(entries)

        #expect(result.count == 2)

        let projectA = result.first { $0.projectPath == "/Users/dev/project-a" }
        #expect(projectA?.totalCost == 13.00)
        #expect(projectA?.projectName == "project-a")
    }

    @Test("sorts projects by cost descending")
    func sortsProjectsByCostDescending() {
        let entries = [
            TestEntryFactory.entry(cost: 1.00, project: "cheap"),
            TestEntryFactory.entry(cost: 100.00, project: "expensive"),
            TestEntryFactory.entry(cost: 10.00, project: "medium")
        ]
        let result = UsageAggregator.aggregateByProject(entries)

        #expect(result[0].projectPath == "expensive")
        #expect(result[1].projectPath == "medium")
        #expect(result[2].projectPath == "cheap")
    }

    // MARK: - Filter Today

    @Test("filters to today's entries only")
    func filtersTodayEntries() {
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: now)!

        let entries = [
            TestEntryFactory.entry(timestamp: now, cost: 1.00),
            TestEntryFactory.entry(timestamp: yesterday, cost: 2.00),
            TestEntryFactory.entry(timestamp: lastWeek, cost: 3.00),
            TestEntryFactory.entry(timestamp: now, cost: 0.50)
        ]
        let result = UsageAggregator.filterToday(entries)

        #expect(result.count == 2)
        #expect(result.reduce(0) { $0 + $1.costUSD } == 1.50)
    }

    @Test("filterToday with custom reference date")
    func filtersTodayWithReferenceDate() {
        let referenceDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let onReferenceDay = referenceDate
        let beforeReferenceDay = Calendar.current.date(byAdding: .day, value: -1, to: referenceDate)!

        let entries = [
            TestEntryFactory.entry(timestamp: onReferenceDay, cost: 1.00),
            TestEntryFactory.entry(timestamp: beforeReferenceDay, cost: 2.00)
        ]
        let result = UsageAggregator.filterToday(entries, referenceDate: referenceDate)

        #expect(result.count == 1)
        #expect(result[0].costUSD == 1.00)
    }

    // MARK: - Hourly Costs

    @Test("calculates hourly costs correctly")
    func calculatesHourlyCosts() {
        let today = Calendar.current.startOfDay(for: Date())
        let hour9 = Calendar.current.date(byAdding: .hour, value: 9, to: today)!
        let hour14 = Calendar.current.date(byAdding: .hour, value: 14, to: today)!

        let entries = [
            TestEntryFactory.entry(timestamp: hour9, cost: 1.00),
            TestEntryFactory.entry(timestamp: hour9, cost: 0.50),
            TestEntryFactory.entry(timestamp: hour14, cost: 2.00)
        ]
        let result = UsageAggregator.todayHourlyCosts(from: entries, referenceDate: today)

        #expect(result.count == 24)
        #expect(result[9] == 1.50)
        #expect(result[14] == 2.00)
        #expect(result[0] == 0.00)
    }
}

// MARK: - Test Factory

private enum TestEntryFactory {
    static func entry(
        model: String = "claude-sonnet",
        timestamp: Date = Date(),
        cost: Double = 0.0,
        tokens: TokenCounts = .zero,
        project: String = "test-project"
    ) -> UsageEntry {
        UsageEntry(
            id: UUID().uuidString,
            timestamp: timestamp,
            model: model,
            tokens: tokens,
            costUSD: cost,
            project: project,
            sourceFile: "test.jsonl",
            sessionId: UUID().uuidString
        )
    }
}
