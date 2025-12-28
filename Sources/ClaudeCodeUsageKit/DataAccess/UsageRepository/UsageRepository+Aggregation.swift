//
//  UsageRepository+Aggregation.swift
//
//  Statistics aggregation, filtering, and sorting.
//

import Foundation

// MARK: - Aggregation

enum Aggregator {
    static func aggregate(_ entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = RepositoryDateFormat.dayString
        let calendar = Calendar.current

        let result = entries.reduce(into: AggregationState()) { state, entry in
            state.addEntry(entry, dateFormatter: dateFormatter, calendar: calendar)
        }

        return UsageStats(
            totalCost: result.totalCost,
            totalTokens: result.totalTokens,
            totalInputTokens: result.totalInputTokens,
            totalOutputTokens: result.totalOutputTokens,
            totalCacheCreationTokens: result.totalCacheWriteTokens,
            totalCacheReadTokens: result.totalCacheReadTokens,
            totalSessions: sessionCount,
            byModel: Array(result.modelStats.values),
            byDate: result.buildDailyUsage(),
            byProject: Array(result.projectStats.values)
        )
    }
}

// MARK: - Aggregation State

private struct AggregationState {
    var totalCost: Double = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheWriteTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    var modelStats: [String: ModelUsage] = [:]
    var dailyStats: [String: DailyUsageBuilder] = [:]
    var projectStats: [String: ProjectUsage] = [:]

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheWriteTokens + totalCacheReadTokens
    }

    mutating func addEntry(_ entry: UsageEntry, dateFormatter: DateFormatter, calendar: Calendar) {
        totalCost += entry.cost
        totalInputTokens += entry.inputTokens
        totalOutputTokens += entry.outputTokens
        totalCacheWriteTokens += entry.cacheWriteTokens
        totalCacheReadTokens += entry.cacheReadTokens

        updateModelStats(entry)
        updateDailyStats(entry, dateFormatter: dateFormatter, calendar: calendar)
        updateProjectStats(entry)
    }

    private mutating func updateModelStats(_ entry: UsageEntry) {
        let existing = modelStats[entry.model]
        modelStats[entry.model] = ModelUsage(
            model: entry.model,
            totalCost: (existing?.totalCost ?? 0) + entry.cost,
            totalTokens: (existing?.totalTokens ?? 0) + entry.totalTokens,
            inputTokens: (existing?.inputTokens ?? 0) + entry.inputTokens,
            outputTokens: (existing?.outputTokens ?? 0) + entry.outputTokens,
            cacheCreationTokens: (existing?.cacheCreationTokens ?? 0) + entry.cacheWriteTokens,
            cacheReadTokens: (existing?.cacheReadTokens ?? 0) + entry.cacheReadTokens,
            sessionCount: (existing?.sessionCount ?? 0) + 1
        )
    }

    private mutating func updateDailyStats(_ entry: UsageEntry, dateFormatter: DateFormatter, calendar: Calendar) {
        guard let date = entry.date else { return }
        let dateString = dateFormatter.string(from: date)
        let hour = calendar.component(.hour, from: date)

        var builder = dailyStats[dateString] ?? DailyUsageBuilder()
        builder.totalCost += entry.cost
        builder.totalTokens += entry.totalTokens
        builder.models.insert(entry.model)
        builder.hourlyCosts[hour] += entry.cost
        dailyStats[dateString] = builder
    }

    private mutating func updateProjectStats(_ entry: UsageEntry) {
        let existing = projectStats[entry.project]
        projectStats[entry.project] = ProjectUsage(
            projectPath: entry.project,
            projectName: URL(fileURLWithPath: entry.project).lastPathComponent,
            totalCost: (existing?.totalCost ?? 0) + entry.cost,
            totalTokens: (existing?.totalTokens ?? 0) + entry.totalTokens,
            sessionCount: existing?.sessionCount ?? 1,
            lastUsed: max(existing?.lastUsed ?? "", entry.timestamp)
        )
    }

    func buildDailyUsage() -> [DailyUsage] {
        dailyStats.map { date, builder in
            DailyUsage(
                date: date,
                totalCost: builder.totalCost,
                totalTokens: builder.totalTokens,
                modelsUsed: Array(builder.models),
                hourlyCosts: builder.hourlyCosts
            )
        }.sorted { $0.date < $1.date }
    }
}

// MARK: - Daily Usage Builder

private struct DailyUsageBuilder {
    var totalCost: Double = 0
    var totalTokens: Int = 0
    var models: Set<String> = []
    var hourlyCosts: [Double] = Array(repeating: 0, count: 24)
}

// MARK: - Filtering

enum Filter {
    static func byDateRange(_ stats: UsageStats, start: Date, end: Date) -> UsageStats {
        guard start.timeIntervalSince1970 >= 0 else { return stats }

        let formatter = DateFormatter()
        formatter.dateFormat = RepositoryDateFormat.dayString
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)

        let filtered = stats.byDate.filter { $0.date >= startString && $0.date <= endString }
        guard !filtered.isEmpty else { return stats }

        let (totalCost, totalTokens) = filtered.reduce((0.0, 0)) { ($0.0 + $1.totalCost, $0.1 + $1.totalTokens) }

        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: stats.totalInputTokens,
            totalOutputTokens: stats.totalOutputTokens,
            totalCacheCreationTokens: stats.totalCacheCreationTokens,
            totalCacheReadTokens: stats.totalCacheReadTokens,
            totalSessions: stats.totalSessions,
            byModel: stats.byModel,
            byDate: filtered,
            byProject: stats.byProject
        )
    }

    static func byDateRange(_ projects: [ProjectUsage], since: Date?, until: Date?) -> [ProjectUsage] {
        guard let since = since, let until = until else { return projects }
        return projects.filter { project in
            project.lastUsedDate.map { $0 >= since && $0 <= until } ?? false
        }
    }
}

// MARK: - Sorting

enum Sort {
    static func byCost(_ projects: [ProjectUsage], order: SortOrder?) -> [ProjectUsage] {
        guard let order = order else { return projects }
        return projects.sorted { a, b in
            order == .ascending ? a.totalCost < b.totalCost : a.totalCost > b.totalCost
        }
    }
}
