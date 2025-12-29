//
//  UsageAggregator.swift
//  ClaudeUsageCore
//
//  Pure functions for aggregating usage entries into statistics
//

import Foundation

// MARK: - Usage Aggregator

public enum UsageAggregator {
    /// Aggregate entries into usage statistics
    public static func aggregate(_ entries: [UsageEntry]) -> UsageStats {
        guard !entries.isEmpty else { return .empty }

        let totalCost = entries.reduce(0.0) { $0 + $1.costUSD }
        let tokens = entries.reduce(.zero) { $0 + $1.tokens }
        let sessionCount = Set(entries.compactMap(\.sessionId)).count

        return UsageStats(
            totalCost: totalCost,
            tokens: tokens,
            sessionCount: max(1, sessionCount),
            byModel: aggregateByModel(entries),
            byDate: aggregateByDate(entries),
            byProject: aggregateByProject(entries)
        )
    }

    /// Aggregate entries by model
    public static func aggregateByModel(_ entries: [UsageEntry]) -> [ModelUsage] {
        Dictionary(grouping: entries, by: \.model)
            .map { model, modelEntries in
                ModelUsage(
                    model: model,
                    totalCost: modelEntries.reduce(0.0) { $0 + $1.costUSD },
                    tokens: modelEntries.reduce(.zero) { $0 + $1.tokens },
                    sessionCount: Set(modelEntries.compactMap(\.sessionId)).count
                )
            }
            .sorted { $0.totalCost > $1.totalCost }
    }

    /// Aggregate entries by date
    public static func aggregateByDate(_ entries: [UsageEntry]) -> [DailyUsage] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let grouped = Dictionary(grouping: entries) { entry in
            dateFormatter.string(from: entry.timestamp)
        }

        return grouped.map { date, dayEntries in
            let hourlyCosts = calculateHourlyCosts(dayEntries, calendar: calendar)
            return DailyUsage(
                date: date,
                totalCost: dayEntries.reduce(0.0) { $0 + $1.costUSD },
                totalTokens: dayEntries.reduce(0) { $0 + $1.totalTokens },
                modelsUsed: Array(Set(dayEntries.map(\.model))),
                hourlyCosts: hourlyCosts
            )
        }
        .sorted { $0.date < $1.date }
    }

    /// Aggregate entries by project
    public static func aggregateByProject(_ entries: [UsageEntry]) -> [ProjectUsage] {
        Dictionary(grouping: entries, by: \.project)
            .map { project, projectEntries in
                let lastUsed = projectEntries.map(\.timestamp).max() ?? Date()
                let projectName = extractProjectName(from: project)
                return ProjectUsage(
                    projectPath: project,
                    projectName: projectName,
                    totalCost: projectEntries.reduce(0.0) { $0 + $1.costUSD },
                    totalTokens: projectEntries.reduce(0) { $0 + $1.totalTokens },
                    sessionCount: Set(projectEntries.compactMap(\.sessionId)).count,
                    lastUsed: lastUsed
                )
            }
            .sorted { $0.totalCost > $1.totalCost }
    }

    // MARK: - Helpers

    private static func calculateHourlyCosts(
        _ entries: [UsageEntry],
        calendar: Calendar
    ) -> [Double] {
        var hourlyCosts = Array(repeating: 0.0, count: 24)
        for entry in entries {
            let hour = calendar.component(.hour, from: entry.timestamp)
            hourlyCosts[hour] += entry.costUSD
        }
        return hourlyCosts
    }

    private static func extractProjectName(from path: String) -> String {
        // Extract the last path component as project name
        let components = path.split(separator: "/")
        return components.last.map(String.init) ?? path
    }
}

// MARK: - Today Filtering

public extension UsageAggregator {
    /// Filter entries to today only
    static func filterToday(_ entries: [UsageEntry], referenceDate: Date = Date()) -> [UsageEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return entries.filter { entry in
            calendar.startOfDay(for: entry.timestamp) == today
        }
    }

    /// Calculate hourly costs for today
    static func todayHourlyCosts(
        from entries: [UsageEntry],
        referenceDate: Date = Date()
    ) -> [Double] {
        let calendar = Calendar.current
        let todayEntries = filterToday(entries, referenceDate: referenceDate)
        return calculateHourlyCosts(todayEntries, calendar: calendar)
    }
}
