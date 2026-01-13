//
//  UsageAggregatorTests.swift
//
//  Specification for UsageAggregator - pure functions for usage data aggregation.
//
//  This test suite specifies:
//  - aggregate([UsageEntry]) → UsageStats: sums costs/tokens, counts sessions, groups by model/date
//  - aggregateByModel: groups by model, sorts by cost descending
//  - aggregateByDate: groups by date string (yyyy-MM-dd), sorts ascending
//  - filterToday: filters entries to reference date
//  - todayHourlyCosts: returns 24-element array of hourly costs
//

import Testing
import Foundation
@testable import ClaudeUsage

/// UsageAggregator is an enum with static methods for aggregating usage entries.
/// All methods are pure functions with no side effects.
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
        let entries = TestEntryFactory.entriesWithModels([
            (model: "claude-opus", cost: 5.00),
            (model: "claude-sonnet", cost: 3.00),
            (model: "claude-opus", cost: 2.00),
            (model: "claude-haiku", cost: 0.50)
        ])
        let result = UsageAggregator.aggregateByModel(entries)

        #expect(result.count == 3)

        let opusUsage = result.first { $0.model == "claude-opus" }
        #expect(opusUsage?.totalCost == 7.00)

        let sonnetUsage = result.first { $0.model == "claude-sonnet" }
        #expect(sonnetUsage?.totalCost == 3.00)
    }

    @Test("sorts models by cost descending")
    func sortsModelsByCostDescending() {
        let entries = TestEntryFactory.entriesWithModels([
            (model: "haiku", cost: 1.00),
            (model: "opus", cost: 10.00),
            (model: "sonnet", cost: 5.00)
        ])
        let result = UsageAggregator.aggregateByModel(entries)

        #expect(result[0].model == "opus")
        #expect(result[1].model == "sonnet")
        #expect(result[2].model == "haiku")
    }

    // MARK: - Aggregate By Date

    @Test("groups entries by date string")
    func groupsByDate() {
        let today = Date()
        let yesterday = TestEntryFactory.dateOffset(days: -1, from: today)

        let entries = TestEntryFactory.entriesWithTimestamps([
            (timestamp: today, cost: 2.00),
            (timestamp: today, cost: 1.00),
            (timestamp: yesterday, cost: 5.00)
        ])
        let result = UsageAggregator.aggregateByDate(entries)

        #expect(result.count == 2)

        // Results sorted ascending by date
        #expect(result[0].totalCost == 5.00) // yesterday
        #expect(result[1].totalCost == 3.00) // today
    }

    @Test("sorts dates ascending")
    func sortsDatesAscending() {
        let dates = TestEntryFactory.datesRelativeToToday([0, -1, -2, -3, -4])
        let entries = dates.map { TestEntryFactory.entry(timestamp: $0, cost: 1.00) }

        let result = UsageAggregator.aggregateByDate(entries)

        #expect(result.count == 5)
        #expect(result[0].date < result[4].date) // First is oldest
    }

    // MARK: - Ensure Today

    @Test("ensureToday adds empty today when missing")
    func ensureTodayAddsMissingToday() {
        let yesterday = TestEntryFactory.dateOffset(days: -1)
        let twoDaysAgo = TestEntryFactory.dateOffset(days: -2)
        let referenceDate = Date()
        let todayString = dateString(from: referenceDate)

        let existingDates = [
            DailyUsage(date: dateString(from: twoDaysAgo), totalCost: 5.0, totalTokens: 1000),
            DailyUsage(date: dateString(from: yesterday), totalCost: 10.0, totalTokens: 2000)
        ]

        let result = UsageAggregator.ensureToday(in: existingDates, referenceDate: referenceDate)

        #expect(result.count == 3)
        #expect(result.last?.date == todayString)
        #expect(result.last?.totalCost == 0)
        #expect(result.last?.totalTokens == 0)
        #expect(result.last?.modelsUsed.isEmpty == true)
    }

    @Test("ensureToday preserves existing today")
    func ensureTodayPreservesExisting() {
        let referenceDate = Date()
        let todayString = dateString(from: referenceDate)

        let existingDates = [
            DailyUsage(date: todayString, totalCost: 25.0, totalTokens: 5000, modelsUsed: ["opus"])
        ]

        let result = UsageAggregator.ensureToday(in: existingDates, referenceDate: referenceDate)

        #expect(result.count == 1)
        #expect(result[0].totalCost == 25.0)
        #expect(result[0].modelsUsed == ["opus"])
    }

    @Test("ensureToday maintains sort order")
    func ensureTodayMaintainsSortOrder() {
        let yesterday = TestEntryFactory.dateOffset(days: -1)
        let tomorrow = TestEntryFactory.dateOffset(days: 1)
        let referenceDate = Date()

        let existingDates = [
            DailyUsage(date: dateString(from: yesterday), totalCost: 5.0, totalTokens: 1000),
            DailyUsage(date: dateString(from: tomorrow), totalCost: 15.0, totalTokens: 3000)
        ]

        let result = UsageAggregator.ensureToday(in: existingDates, referenceDate: referenceDate)

        #expect(result.count == 3)
        #expect(result[0].date == dateString(from: yesterday))
        #expect(result[1].date == dateString(from: referenceDate))
        #expect(result[2].date == dateString(from: tomorrow))
    }

    // MARK: - Filter Today

    @Test("filters to today's entries only")
    func filtersTodayEntries() {
        let now = Date()
        let yesterday = TestEntryFactory.dateOffset(days: -1, from: now)
        let lastWeek = TestEntryFactory.dateOffset(days: -7, from: now)

        let entries = TestEntryFactory.entriesWithTimestamps([
            (timestamp: now, cost: 1.00),
            (timestamp: yesterday, cost: 2.00),
            (timestamp: lastWeek, cost: 3.00),
            (timestamp: now, cost: 0.50)
        ])
        let result = UsageAggregator.filterToday(entries)

        #expect(result.count == 2)
        #expect(sumCosts(result) == 1.50)
    }

    @Test("filterToday with custom reference date")
    func filtersTodayWithReferenceDate() {
        let referenceDate = TestEntryFactory.dateOffset(days: -5)
        let beforeReferenceDay = TestEntryFactory.dateOffset(days: -1, from: referenceDate)

        let entries = TestEntryFactory.entriesWithTimestamps([
            (timestamp: referenceDate, cost: 1.00),
            (timestamp: beforeReferenceDay, cost: 2.00)
        ])
        let result = UsageAggregator.filterToday(entries, referenceDate: referenceDate)

        #expect(result.count == 1)
        #expect(result[0].costUSD == 1.00)
    }

    // MARK: - Hourly Costs

    @Test("calculates hourly costs correctly")
    func calculatesHourlyCosts() {
        let today = Date()
        let hour9 = TestEntryFactory.hourOffset(9, on: today)
        let hour14 = TestEntryFactory.hourOffset(14, on: today)

        let entries = TestEntryFactory.entriesWithTimestamps([
            (timestamp: hour9, cost: 1.00),
            (timestamp: hour9, cost: 0.50),
            (timestamp: hour14, cost: 2.00)
        ])
        let referenceDate = Calendar.current.startOfDay(for: today)
        let result = UsageAggregator.todayHourlyCosts(from: entries, referenceDate: referenceDate)

        #expect(result.count == 24)
        #expect(result[9] == 1.50)
        #expect(result[14] == 2.00)
        #expect(result[0] == 0.00)
    }

    // MARK: - Helper Functions (Pure)

    /// Sums costs from entries (pure function)
    private func sumCosts(_ entries: [UsageEntry]) -> Double {
        entries.reduce(0) { $0 + $1.costUSD }
    }

    /// Formats date as yyyy-MM-dd string (pure function)
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Test Entry Factory (FP Style)

private enum TestEntryFactory {

    // MARK: - Pure Factory Functions

    /// Creates a test entry with specified attributes (pure function)
    static func entry(
        model: String = "claude-sonnet",
        timestamp: Date = Date(),
        cost: Double = 0.0,
        tokens: TokenCounts = .zero,
        project: String = "test-project"
    ) -> UsageEntry {
        makeEntry(
            model: model,
            timestamp: timestamp,
            cost: cost,
            tokens: tokens,
            project: project
        )
    }

    // MARK: - Batch Creation (Functional Combinators)

    /// Creates entries by mapping costs to entries (pure function)
    static func entriesWithCosts(_ costs: [Double]) -> [UsageEntry] {
        costs.map { entry(cost: $0) }
    }

    /// Creates entries by mapping (model, cost) pairs (pure function)
    static func entriesWithModels(_ modelCosts: [(model: String, cost: Double)]) -> [UsageEntry] {
        modelCosts.map { entry(model: $0.model, cost: $0.cost) }
    }

    /// Creates entries by mapping (timestamp, cost) pairs (pure function)
    static func entriesWithTimestamps(_ timestampCosts: [(timestamp: Date, cost: Double)]) -> [UsageEntry] {
        timestampCosts.map { entry(timestamp: $0.timestamp, cost: $0.cost) }
    }

    /// Creates entries by mapping (project, cost) pairs (pure function)
    static func entriesWithProjects(_ projectCosts: [(project: String, cost: Double)]) -> [UsageEntry] {
        projectCosts.map { Self.entry(cost: $0.cost, project: $0.project) }
    }

    // MARK: - Date Helpers (Pure Functions)

    /// Generates dates relative to today (pure function)
    static func datesRelativeToToday(_ dayOffsets: [Int]) -> [Date] {
        dayOffsets.map { dateOffset(days: $0, from: Date()) }
    }

    /// Single date offset (pure function)
    static func dateOffset(days: Int, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: reference)!
    }

    /// Hour offset within a day (pure function)
    static func hourOffset(_ hour: Int, on date: Date) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .hour, value: hour, to: startOfDay)!
    }

    // MARK: - Private Implementation

    private static func makeEntry(
        model: String,
        timestamp: Date,
        cost: Double,
        tokens: TokenCounts,
        project: String
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
