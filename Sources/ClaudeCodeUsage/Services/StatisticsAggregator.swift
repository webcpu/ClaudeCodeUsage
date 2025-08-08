//
//  StatisticsAggregator.swift
//  ClaudeCodeUsage
//
//  Service for aggregating usage statistics (Single Responsibility Principle)
//

import Foundation

/// Protocol for statistics aggregation
public protocol StatisticsAggregatorProtocol {
    /// Aggregate usage entries into statistics
    func aggregateStatistics(from entries: [UsageEntry], sessionCount: Int) -> UsageStats
}

/// Default statistics aggregator implementation
public struct StatisticsAggregator: StatisticsAggregatorProtocol {
    
    public init() {}
    
    public func aggregateStatistics(from entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        var totalCost = 0.0
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheWriteTokens = 0
        var totalCacheReadTokens = 0
        
        var modelStats: [String: ModelUsage] = [:]
        var dailyStats: [String: DailyUsage] = [:]
        var projectStats: [String: ProjectUsage] = [:]
        
        for entry in entries {
            // Update totals
            totalCost += entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheWriteTokens += entry.cacheWriteTokens
            totalCacheReadTokens += entry.cacheReadTokens
            
            // Update model stats
            updateModelStats(&modelStats, with: entry)
            
            // Update daily stats
            updateDailyStats(&dailyStats, with: entry)
            
            // Update project stats
            updateProjectStats(&projectStats, with: entry)
        }
        
        let totalTokens = totalInputTokens + totalOutputTokens + totalCacheWriteTokens + totalCacheReadTokens
        
        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCacheCreationTokens: totalCacheWriteTokens,
            totalCacheReadTokens: totalCacheReadTokens,
            totalSessions: sessionCount,
            byModel: Array(modelStats.values),
            byDate: Array(dailyStats.values).sorted { $0.date < $1.date },
            byProject: Array(projectStats.values)
        )
    }
    
    private func updateModelStats(_ modelStats: inout [String: ModelUsage], with entry: UsageEntry) {
        if var modelUsage = modelStats[entry.model] {
            modelUsage = ModelUsage(
                model: entry.model,
                totalCost: modelUsage.totalCost + entry.cost,
                totalTokens: modelUsage.totalTokens + entry.totalTokens,
                inputTokens: modelUsage.inputTokens + entry.inputTokens,
                outputTokens: modelUsage.outputTokens + entry.outputTokens,
                cacheCreationTokens: modelUsage.cacheCreationTokens + entry.cacheWriteTokens,
                cacheReadTokens: modelUsage.cacheReadTokens + entry.cacheReadTokens,
                sessionCount: modelUsage.sessionCount + 1
            )
            modelStats[entry.model] = modelUsage
        } else {
            modelStats[entry.model] = ModelUsage(
                model: entry.model,
                totalCost: entry.cost,
                totalTokens: entry.totalTokens,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheCreationTokens: entry.cacheWriteTokens,
                cacheReadTokens: entry.cacheReadTokens,
                sessionCount: 1
            )
        }
    }
    
    private func updateDailyStats(_ dailyStats: inout [String: DailyUsage], with entry: UsageEntry) {
        guard let date = entry.date else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        if var daily = dailyStats[dateString] {
            daily = DailyUsage(
                date: dateString,
                totalCost: daily.totalCost + entry.cost,
                totalTokens: daily.totalTokens + entry.totalTokens,
                modelsUsed: Array(Set(daily.modelsUsed + [entry.model]))
            )
            dailyStats[dateString] = daily
        } else {
            dailyStats[dateString] = DailyUsage(
                date: dateString,
                totalCost: entry.cost,
                totalTokens: entry.totalTokens,
                modelsUsed: [entry.model]
            )
        }
    }
    
    private func updateProjectStats(_ projectStats: inout [String: ProjectUsage], with entry: UsageEntry) {
        if var project = projectStats[entry.project] {
            project = ProjectUsage(
                projectPath: entry.project,
                projectName: URL(fileURLWithPath: entry.project).lastPathComponent,
                totalCost: project.totalCost + entry.cost,
                totalTokens: project.totalTokens + entry.totalTokens,
                sessionCount: project.sessionCount,
                lastUsed: max(project.lastUsed, entry.timestamp)
            )
            projectStats[entry.project] = project
        } else {
            projectStats[entry.project] = ProjectUsage(
                projectPath: entry.project,
                projectName: URL(fileURLWithPath: entry.project).lastPathComponent,
                totalCost: entry.cost,
                totalTokens: entry.totalTokens,
                sessionCount: 1,
                lastUsed: entry.timestamp
            )
        }
    }
}