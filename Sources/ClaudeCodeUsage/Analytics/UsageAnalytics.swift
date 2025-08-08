//
//  UsageAnalytics.swift
//  ClaudeCodeUsage
//
//  Analytics and filtering utilities for usage data
//

import Foundation

/// Analytics utilities for usage data
public class UsageAnalytics {
    
    /// Calculate cost breakdown by percentage
    public static func costBreakdown(from stats: UsageStats) -> [(model: String, percentage: Double, cost: Double)] {
        guard stats.totalCost > 0 else { return [] }
        
        return stats.byModel.map { model in
            let percentage = (model.totalCost / stats.totalCost) * 100
            return (model: model.model, percentage: percentage, cost: model.totalCost)
        }.sorted { $0.cost > $1.cost }
    }
    
    /// Calculate token breakdown by type
    public static func tokenBreakdown(from stats: UsageStats) -> TokenBreakdown {
        let total = stats.totalTokens
        guard total > 0 else {
            return TokenBreakdown(
                inputPercentage: 0,
                outputPercentage: 0,
                cacheWritePercentage: 0,
                cacheReadPercentage: 0
            )
        }
        
        return TokenBreakdown(
            inputPercentage: (Double(stats.totalInputTokens) / Double(total)) * 100,
            outputPercentage: (Double(stats.totalOutputTokens) / Double(total)) * 100,
            cacheWritePercentage: (Double(stats.totalCacheCreationTokens) / Double(total)) * 100,
            cacheReadPercentage: (Double(stats.totalCacheReadTokens) / Double(total)) * 100
        )
    }
    
    /// Find the most expensive sessions
    public static func topExpensiveSessions(from projects: [ProjectUsage], limit: Int = 10) -> [ProjectUsage] {
        Array(projects.sorted { $0.totalCost > $1.totalCost }.prefix(limit))
    }
    
    /// Find the most token-intensive sessions
    public static func topTokenIntensiveSessions(from projects: [ProjectUsage], limit: Int = 10) -> [ProjectUsage] {
        Array(projects.sorted { $0.totalTokens > $1.totalTokens }.prefix(limit))
    }
    
    /// Calculate daily average cost
    public static func dailyAverageCost(from dailyUsage: [DailyUsage]) -> Double {
        guard !dailyUsage.isEmpty else { return 0 }
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        return totalCost / Double(dailyUsage.count)
    }
    
    /// Calculate weekly trends
    public static func weeklyTrends(from dailyUsage: [DailyUsage]) -> WeeklyTrend {
        guard dailyUsage.count >= 14 else {
            return WeeklyTrend(
                currentWeekCost: dailyUsage.suffix(7).reduce(0) { $0 + $1.totalCost },
                previousWeekCost: 0,
                percentageChange: 0,
                trend: .stable
            )
        }
        
        let currentWeek = dailyUsage.suffix(7)
        let previousWeek = dailyUsage.dropLast(7).suffix(7)
        
        let currentCost = currentWeek.reduce(0) { $0 + $1.totalCost }
        let previousCost = previousWeek.reduce(0) { $0 + $1.totalCost }
        
        let percentageChange = previousCost > 0 ? ((currentCost - previousCost) / previousCost) * 100 : 0
        
        let trend: WeeklyTrend.Trend
        if percentageChange > 10 {
            trend = .increasing
        } else if percentageChange < -10 {
            trend = .decreasing
        } else {
            trend = .stable
        }
        
        return WeeklyTrend(
            currentWeekCost: currentCost,
            previousWeekCost: previousCost,
            percentageChange: percentageChange,
            trend: trend
        )
    }
    
    /// Predict monthly cost based on current usage
    public static func predictMonthlyCost(from stats: UsageStats, daysElapsed: Int) -> Double {
        guard daysElapsed > 0 else { return 0 }
        let dailyAverage = stats.totalCost / Double(daysElapsed)
        return dailyAverage * 30
    }
    
    /// Group usage by hour of day
    public static func usageByHour(from entries: [UsageEntry]) -> [Int: Double] {
        var hourlyUsage: [Int: Double] = [:]
        
        for entry in entries {
            if let date = entry.date {
                let hour = Calendar.current.component(.hour, from: date)
                hourlyUsage[hour, default: 0] += entry.cost
            }
        }
        
        return hourlyUsage
    }
    
    /// Find peak usage hours
    public static func peakUsageHours(from entries: [UsageEntry], top: Int = 3) -> [(hour: Int, cost: Double)] {
        let hourlyUsage = usageByHour(from: entries)
        return hourlyUsage
            .sorted { $0.value > $1.value }
            .prefix(top)
            .map { (hour: $0.key, cost: $0.value) }
    }
    
    /// Calculate savings from cache usage
    public static func cacheSavings(from stats: UsageStats) -> CacheSavings {
        // Calculate what it would have cost without cache
        let opus4Pricing = ModelPricing.opus4
        let sonnet4Pricing = ModelPricing.sonnet4
        
        var potentialCost = 0.0
        let actualCost = stats.totalCost
        
        for model in stats.byModel {
            let pricing = model.model.contains("opus") ? opus4Pricing : sonnet4Pricing
            
            // Cache read tokens would have been input tokens
            let additionalInputCost = (Double(model.cacheReadTokens) / 1_000_000) * pricing.inputPricePerMillion
            potentialCost += additionalInputCost
        }
        
        let savedAmount = potentialCost
        let savedPercentage = actualCost > 0 ? (savedAmount / (actualCost + savedAmount)) * 100 : 0
        
        return CacheSavings(
            savedAmount: savedAmount,
            savedPercentage: savedPercentage,
            cacheHitRate: calculateCacheHitRate(from: stats)
        )
    }
    
    private static func calculateCacheHitRate(from stats: UsageStats) -> Double {
        let totalCacheOperations = stats.totalCacheCreationTokens + stats.totalCacheReadTokens
        guard totalCacheOperations > 0 else { return 0 }
        return (Double(stats.totalCacheReadTokens) / Double(totalCacheOperations)) * 100
    }
}

// MARK: - Supporting Types

/// Token breakdown percentages
public struct TokenBreakdown {
    public let inputPercentage: Double
    public let outputPercentage: Double
    public let cacheWritePercentage: Double
    public let cacheReadPercentage: Double
    
    public var description: String {
        String(format: "Input: %.1f%%, Output: %.1f%%, Cache Write: %.1f%%, Cache Read: %.1f%%",
               inputPercentage, outputPercentage, cacheWritePercentage, cacheReadPercentage)
    }
}

/// Weekly usage trend analysis
public struct WeeklyTrend {
    public enum Trend {
        case increasing
        case decreasing
        case stable
        
        public var symbol: String {
            switch self {
            case .increasing: return "↑"
            case .decreasing: return "↓"
            case .stable: return "→"
            }
        }
    }
    
    public let currentWeekCost: Double
    public let previousWeekCost: Double
    public let percentageChange: Double
    public let trend: Trend
    
    public var description: String {
        String(format: "%@ %.1f%% ($%.2f → $%.2f)",
               trend.symbol, abs(percentageChange), previousWeekCost, currentWeekCost)
    }
}

/// Cache savings analysis
public struct CacheSavings {
    public let savedAmount: Double
    public let savedPercentage: Double
    public let cacheHitRate: Double
    
    public var description: String {
        String(format: "Saved $%.2f (%.1f%%) with %.1f%% cache hit rate",
               savedAmount, savedPercentage, cacheHitRate)
    }
}

// MARK: - Filtering Extensions

public extension Array where Element == UsageEntry {
    
    /// Filter entries by date range
    func filtered(by timeRange: TimeRange) -> [UsageEntry] {
        let range = timeRange.dateRange
        return self.filter { entry in
            guard let date = entry.date else { return false }
            return date >= range.start && date <= range.end
        }
    }
    
    /// Filter entries by model
    func filteredByModel(_ model: String) -> [UsageEntry] {
        self.filter { $0.model.contains(model) }
    }
    
    /// Filter entries by minimum cost
    func filtered(minimumCost: Double) -> [UsageEntry] {
        self.filter { $0.cost >= minimumCost }
    }
    
    /// Filter entries by project
    func filteredByProject(_ project: String) -> [UsageEntry] {
        self.filter { $0.project.contains(project) }
    }
}

public extension Array where Element == ProjectUsage {
    
    /// Sort projects by various criteria
    enum SortCriteria {
        case cost
        case tokens
        case sessions
        case lastUsed
        case name
    }
    
    /// Sort projects
    func sorted(by criteria: SortCriteria, ascending: Bool = false) -> [ProjectUsage] {
        self.sorted { a, b in
            let comparison: Bool
            switch criteria {
            case .cost:
                comparison = a.totalCost > b.totalCost
            case .tokens:
                comparison = a.totalTokens > b.totalTokens
            case .sessions:
                comparison = a.sessionCount > b.sessionCount
            case .lastUsed:
                comparison = a.lastUsed > b.lastUsed
            case .name:
                comparison = a.projectName < b.projectName
            }
            return ascending ? !comparison : comparison
        }
    }
}

// MARK: - Chart Data Helpers

/// Helper struct for chart data points
public struct ChartDataPoint: Identifiable {
    public let id: UUID
    public let label: String
    public let value: Double
    public let category: String?
    
    public init(label: String, value: Double, category: String? = nil) {
        self.id = UUID()
        self.label = label
        self.value = value
        self.category = category
    }
}

public extension UsageStats {
    
    /// Convert daily usage to chart data
    var dailyChartData: [ChartDataPoint] {
        byDate.map { daily in
            ChartDataPoint(label: daily.date, value: daily.totalCost)
        }
    }
    
    /// Convert model usage to chart data
    var modelChartData: [ChartDataPoint] {
        byModel.map { model in
            ChartDataPoint(
                label: model.model.components(separatedBy: "-").prefix(3).joined(separator: "-"),
                value: model.totalCost,
                category: "Model"
            )
        }
    }
    
    /// Convert project usage to chart data
    var projectChartData: [ChartDataPoint] {
        byProject.map { project in
            ChartDataPoint(
                label: project.projectName,
                value: project.totalCost,
                category: "Project"
            )
        }
    }
}

// MARK: - Formatting Helpers

public extension Double {
    /// Format as currency
    var asCurrency: String {
        String(format: "$%.2f", self)
    }
    
    /// Format as percentage
    var asPercentage: String {
        String(format: "%.1f%%", self)
    }
}

public extension Int {
    /// Format as abbreviated number (K, M, B)
    var abbreviated: String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", Double(self) / 1_000_000_000)
        } else if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        } else {
            return "\(self)"
        }
    }
}