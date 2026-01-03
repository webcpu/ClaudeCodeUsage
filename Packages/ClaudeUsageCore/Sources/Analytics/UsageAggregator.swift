//
//  UsageAggregator.swift
//  ClaudeUsageCore
//

import Foundation

// MARK: - Aggregation Strategy

/// An aggregation strategy transforms usage entries into aggregated output
public typealias AggregationStrategy<Output> = @Sendable ([UsageEntry]) -> Output

// MARK: - Strategy Builders

/// Builds an aggregation strategy from its components:
/// group >>> build >>> sort
public func buildStrategy<Key: Hashable, Output>(
    groupBy: @escaping @Sendable (UsageEntry) -> Key,
    build: @escaping @Sendable ((key: Key, value: [UsageEntry])) -> Output,
    sort: @escaping @Sendable ([Output]) -> [Output]
) -> AggregationStrategy<[Output]> {
    let group: AggregationStrategy<[Key: [UsageEntry]]> = { entries in
        Dictionary(grouping: entries, by: groupBy)
    }

    let mapBuild: @Sendable ([Key: [UsageEntry]]) -> [Output] = { dict in
        dict.map(build)
    }

    return group >>> mapBuild >>> sort
}

// MARK: - Predefined Strategies

public enum AggregationStrategies {

    // MARK: - Model Strategy

    public static let byModel: AggregationStrategy<[ModelUsage]> = buildStrategy(
        groupBy: \.model,
        build: ModelUsageBuilder.build,
        sort: { $0.sorted { $0.totalCost > $1.totalCost } }
    )

    // MARK: - Date Strategy

    public static let byDate: AggregationStrategy<[DailyUsage]> = buildStrategy(
        groupBy: { DateFormatters.yearMonthDay.string(from: $0.timestamp) },
        build: DailyUsageBuilder.build,
        sort: { $0.sorted { $0.date < $1.date } }
    )

    // MARK: - Project Strategy

    public static let byProject: AggregationStrategy<[ProjectUsage]> = buildStrategy(
        groupBy: \.project,
        build: ProjectUsageBuilder.build,
        sort: { $0.sorted { $0.totalCost > $1.totalCost } }
    )
}

// MARK: - Model Usage Builder

private enum ModelUsageBuilder {
    static let build: @Sendable ((key: String, value: [UsageEntry])) -> ModelUsage = { pair in
        ModelUsage(
            model: pair.key,
            totalCost: pair.value.reduce(0.0) { $0 + $1.costUSD },
            tokens: pair.value.reduce(.zero) { $0 + $1.tokens },
            sessionCount: Set(pair.value.compactMap(\.sessionId)).count
        )
    }
}

// MARK: - Daily Usage Builder

private enum DailyUsageBuilder {
    static let build: @Sendable ((key: String, value: [UsageEntry])) -> DailyUsage = { pair in
        DailyUsage(
            date: pair.key,
            totalCost: pair.value.reduce(0.0) { $0 + $1.costUSD },
            totalTokens: pair.value.reduce(0) { $0 + $1.totalTokens },
            modelsUsed: Array(Set(pair.value.map(\.model))),
            hourlyCosts: calculateHourlyCosts(pair.value)
        )
    }

    private static func calculateHourlyCosts(_ entries: [UsageEntry]) -> [Double] {
        entries.reduce(into: Array(repeating: 0.0, count: 24)) { costs, entry in
            let hour = Calendar.current.component(.hour, from: entry.timestamp)
            costs[hour] += entry.costUSD
        }
    }
}

// MARK: - Project Usage Builder

private enum ProjectUsageBuilder {
    static let build: @Sendable ((key: String, value: [UsageEntry])) -> ProjectUsage = { pair in
        ProjectUsage(
            projectPath: pair.key,
            projectName: extractProjectName(from: pair.key),
            totalCost: pair.value.reduce(0.0) { $0 + $1.costUSD },
            totalTokens: pair.value.reduce(0) { $0 + $1.totalTokens },
            sessionCount: Set(pair.value.compactMap(\.sessionId)).count,
            lastUsed: pair.value.map(\.timestamp).max() ?? Date()
        )
    }

    private static func extractProjectName(from path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

// MARK: - UsageAggregator

public enum UsageAggregator {

    // MARK: - Public Interface

    public static func aggregate(_ entries: [UsageEntry]) -> UsageStats {
        guard !entries.isEmpty else { return .empty }

        return UsageStats(
            totalCost: sumCosts(entries),
            tokens: sumTokens(entries),
            sessionCount: countUniqueSessions(entries),
            byModel: AggregationStrategies.byModel(entries),
            byDate: AggregationStrategies.byDate(entries),
            byProject: AggregationStrategies.byProject(entries)
        )
    }

    /// Aggregate with custom strategies - open for extension
    public static func aggregate(
        _ entries: [UsageEntry],
        modelStrategy: AggregationStrategy<[ModelUsage]> = AggregationStrategies.byModel,
        dateStrategy: AggregationStrategy<[DailyUsage]> = AggregationStrategies.byDate,
        projectStrategy: AggregationStrategy<[ProjectUsage]> = AggregationStrategies.byProject
    ) -> UsageStats {
        guard !entries.isEmpty else { return .empty }

        return UsageStats(
            totalCost: sumCosts(entries),
            tokens: sumTokens(entries),
            sessionCount: countUniqueSessions(entries),
            byModel: modelStrategy(entries),
            byDate: dateStrategy(entries),
            byProject: projectStrategy(entries)
        )
    }

    // MARK: - Individual Aggregations (for direct use)

    public static func aggregateByModel(_ entries: [UsageEntry]) -> [ModelUsage] {
        AggregationStrategies.byModel(entries)
    }

    public static func aggregateByDate(_ entries: [UsageEntry]) -> [DailyUsage] {
        AggregationStrategies.byDate(entries)
    }

    public static func aggregateByProject(_ entries: [UsageEntry]) -> [ProjectUsage] {
        AggregationStrategies.byProject(entries)
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
        entries.reduce(into: Array(repeating: 0.0, count: Constants.hoursPerDay)) { costs, entry in
            let hour = Calendar.current.component(.hour, from: entry.timestamp)
            costs[hour] += entry.costUSD
        }
    }

    static func isOnDate(_ entry: UsageEntry, targetDate: Date) -> Bool {
        Calendar.current.startOfDay(for: entry.timestamp) == targetDate
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
