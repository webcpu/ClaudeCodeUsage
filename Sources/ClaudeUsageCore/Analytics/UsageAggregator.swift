//
//  UsageAggregator.swift
//  ClaudeUsageCore
//

import Foundation

// MARK: - UsageAggregator

public enum UsageAggregator {

    // MARK: - Public Interface

    public static func aggregate(_ entries: [UsageEntry]) -> UsageStats {
        guard !entries.isEmpty else { return .empty }

        return UsageStats(
            totalCost: sumCosts(entries),
            tokens: sumTokens(entries),
            sessionCount: countUniqueSessions(entries),
            byModel: aggregateByModel(entries),
            byDate: aggregateByDate(entries),
            byProject: aggregateByProject(entries)
        )
    }

    public static func aggregateByModel(_ entries: [UsageEntry]) -> [ModelUsage] {
        groupByModel(entries)
            .map(buildModelUsage)
            .sortedByTotalCostDescending()
    }

    public static func aggregateByDate(_ entries: [UsageEntry]) -> [DailyUsage] {
        groupByDateString(entries)
            .map(buildDailyUsage)
            .sortedByDateAscending()
    }

    public static func aggregateByProject(_ entries: [UsageEntry]) -> [ProjectUsage] {
        groupByProject(entries)
            .map(buildProjectUsage)
            .sortedByTotalCostDescending()
    }

    // MARK: - Today Filtering

    public static func filterToday(
        _ entries: [UsageEntry],
        referenceDate: Date = Date()
    ) -> [UsageEntry] {
        let today = Calendar.current.startOfDay(for: referenceDate)
        return entries.filter { isOnDate($0, targetDate: today) }
    }

    public static func todayHourlyCosts(
        from entries: [UsageEntry],
        referenceDate: Date = Date()
    ) -> [Double] {
        filterToday(entries, referenceDate: referenceDate)
            |> calculateHourlyCosts
    }
}

// MARK: - Aggregation Helpers

private extension UsageAggregator {
    static func sumCosts(_ entries: [UsageEntry]) -> Double {
        entries.reduce(0.0) { $0 + $1.costUSD }
    }

    static func sumTokens(_ entries: [UsageEntry]) -> TokenCounts {
        entries.reduce(.zero) { $0 + $1.tokens }
    }

    static func countUniqueSessions(_ entries: [UsageEntry]) -> Int {
        max(Constants.minimumSessionCount, Set(entries.compactMap(\.sessionId)).count)
    }

    static func calculateHourlyCosts(_ entries: [UsageEntry]) -> [Double] {
        entries.reduce(into: emptyHourlyCostsArray()) { costs, entry in
            costs[hourOfDay(from: entry.timestamp)] += entry.costUSD
        }
    }

    static func emptyHourlyCostsArray() -> [Double] {
        Array(repeating: 0.0, count: Constants.hoursPerDay)
    }

    static func hourOfDay(from date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    static func isOnDate(_ entry: UsageEntry, targetDate: Date) -> Bool {
        Calendar.current.startOfDay(for: entry.timestamp) == targetDate
    }
}

// MARK: - Grouping Functions

private extension UsageAggregator {
    static func groupByModel(_ entries: [UsageEntry]) -> [String: [UsageEntry]] {
        Dictionary(grouping: entries, by: \.model)
    }

    static func groupByDateString(_ entries: [UsageEntry]) -> [String: [UsageEntry]] {
        Dictionary(grouping: entries) { formatDateString($0.timestamp) }
    }

    static func groupByProject(_ entries: [UsageEntry]) -> [String: [UsageEntry]] {
        Dictionary(grouping: entries, by: \.project)
    }

    static func formatDateString(_ date: Date) -> String {
        DateFormatters.yearMonthDay.string(from: date)
    }
}

// MARK: - Builder Functions

private extension UsageAggregator {
    static func buildModelUsage(_ pair: (key: String, value: [UsageEntry])) -> ModelUsage {
        ModelUsage(
            model: pair.key,
            totalCost: sumCosts(pair.value),
            tokens: sumTokens(pair.value),
            sessionCount: Set(pair.value.compactMap(\.sessionId)).count
        )
    }

    static func buildDailyUsage(_ pair: (key: String, value: [UsageEntry])) -> DailyUsage {
        DailyUsage(
            date: pair.key,
            totalCost: sumCosts(pair.value),
            totalTokens: pair.value.reduce(0) { $0 + $1.totalTokens },
            modelsUsed: uniqueModels(from: pair.value),
            hourlyCosts: calculateHourlyCosts(pair.value)
        )
    }

    static func buildProjectUsage(_ pair: (key: String, value: [UsageEntry])) -> ProjectUsage {
        ProjectUsage(
            projectPath: pair.key,
            projectName: extractProjectName(from: pair.key),
            totalCost: sumCosts(pair.value),
            totalTokens: pair.value.reduce(0) { $0 + $1.totalTokens },
            sessionCount: Set(pair.value.compactMap(\.sessionId)).count,
            lastUsed: latestTimestamp(from: pair.value)
        )
    }

    static func uniqueModels(from entries: [UsageEntry]) -> [String] {
        Array(Set(entries.map(\.model)))
    }

    static func latestTimestamp(from entries: [UsageEntry]) -> Date {
        entries.map(\.timestamp).max() ?? Date()
    }

    static func extractProjectName(from path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

// MARK: - Sorting Extensions

private extension Array where Element == ModelUsage {
    func sortedByTotalCostDescending() -> [ModelUsage] {
        sorted { $0.totalCost > $1.totalCost }
    }
}

private extension Array where Element == DailyUsage {
    func sortedByDateAscending() -> [DailyUsage] {
        sorted { $0.date < $1.date }
    }
}

private extension Array where Element == ProjectUsage {
    func sortedByTotalCostDescending() -> [ProjectUsage] {
        sorted { $0.totalCost > $1.totalCost }
    }
}

// MARK: - Pipe Operator

infix operator |>: AdditionPrecedence

private func |> <T, U>(value: T, function: (T) -> U) -> U {
    function(value)
}

// MARK: - Constants

private enum Constants {
    static let hoursPerDay = 24
    static let minimumSessionCount = 1
}

// MARK: - Date Formatters

private enum DateFormatters {
    static let yearMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
