//
//  UsageAnalytics.swift
//  ClaudeUsageCore
//
//  Pure functions for usage analytics and calculations
//

import Foundation

// MARK: - UsageAnalytics

public enum UsageAnalytics {

    // MARK: - Cost Calculations

    public static func totalCost(from entries: [UsageEntry]) -> Double {
        entries.reduce(0) { $0 + $1.costUSD }
    }

    public static func averageCostPerSession(from entries: [UsageEntry]) -> Double {
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        guard sessionCount > 0 else { return 0 }
        return totalCost(from: entries) / Double(sessionCount)
    }

    public static func costBreakdown(from stats: UsageStats) -> [(model: String, cost: Double, percentage: Double)] {
        guard stats.totalCost > 0 else { return [] }
        return stats.byModel
            .sorted { $0.totalCost > $1.totalCost }
            .map { modelToCostPercentage($0, totalCost: stats.totalCost) }
    }

    private static func modelToCostPercentage(_ model: ModelUsage, totalCost: Double) -> (model: String, cost: Double, percentage: Double) {
        (model: model.model, cost: model.totalCost, percentage: (model.totalCost / totalCost) * 100)
    }

    // MARK: - Token Analysis

    public static func totalTokens(from entries: [UsageEntry]) -> Int {
        entries.reduce(0) { $0 + $1.totalTokens }
    }

    public static func tokenBreakdown(from stats: UsageStats) -> (
        inputPercentage: Double,
        outputPercentage: Double,
        cacheWritePercentage: Double,
        cacheReadPercentage: Double
    ) {
        let total = Double(stats.totalTokens)
        guard total > 0 else { return (0, 0, 0, 0) }

        let tokens = aggregateTokensByType(stats.byModel)
        return tokenPercentages(from: tokens, total: total)
    }

    private static func aggregateTokensByType(_ models: [ModelUsage]) -> (input: Int, output: Int, cacheWrite: Int, cacheRead: Int) {
        models.reduce((0, 0, 0, 0)) { acc, model in
            (acc.0 + model.tokens.input,
             acc.1 + model.tokens.output,
             acc.2 + model.tokens.cacheCreation,
             acc.3 + model.tokens.cacheRead)
        }
    }

    private static func tokenPercentages(
        from tokens: (input: Int, output: Int, cacheWrite: Int, cacheRead: Int),
        total: Double
    ) -> (inputPercentage: Double, outputPercentage: Double, cacheWritePercentage: Double, cacheReadPercentage: Double) {
        (inputPercentage: (Double(tokens.input) / total) * 100,
         outputPercentage: (Double(tokens.output) / total) * 100,
         cacheWritePercentage: (Double(tokens.cacheWrite) / total) * 100,
         cacheReadPercentage: (Double(tokens.cacheRead) / total) * 100)
    }

    // MARK: - Time-based Analysis

    public static func filterByDateRange(_ entries: [UsageEntry], from startDate: Date, to endDate: Date) -> [UsageEntry] {
        entries.filter { isWithinRange($0, startDate: startDate, endDate: endDate) }
    }

    private static func isWithinRange(_ entry: UsageEntry, startDate: Date, endDate: Date) -> Bool {
        entry.timestamp >= startDate && entry.timestamp <= endDate
    }

    public static func groupByDate(_ entries: [UsageEntry]) -> [String: [UsageEntry]] {
        let formatter = dateFormatter()
        return Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.timestamp)
        }
    }

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }

    public static func dailyUsage(from entries: [UsageEntry]) -> [DailyUsage] {
        groupByDate(entries)
            .map { toDailyUsage(date: $0, entries: $1) }
            .sorted { $0.date < $1.date }
    }

    private static func toDailyUsage(date: String, entries: [UsageEntry]) -> DailyUsage {
        DailyUsage(
            date: date,
            totalCost: totalCost(from: entries),
            totalTokens: totalTokens(from: entries),
            modelsUsed: Array(Set(entries.map { $0.model }))
        )
    }

    // MARK: - Predictions

    public static func predictMonthlyCost(from stats: UsageStats, daysElapsed: Int) -> Double {
        guard daysElapsed > 0 else { return 0 }
        return (stats.totalCost / Double(daysElapsed)) * 30
    }

    public static func burnRate(from entries: [UsageEntry], hours: Int = 24) -> Double {
        let recentEntries = Array(entries.suffix(100))
        guard !recentEntries.isEmpty else { return 0 }

        let hoursElapsed = calculateHoursElapsed(recentEntries)
        guard hoursElapsed > 0 else { return 0 }

        return totalCost(from: recentEntries) / hoursElapsed
    }

    private static func calculateHoursElapsed(_ entries: [UsageEntry]) -> Double {
        let timestamps = entries.map(\.timestamp)
        guard let minTime = timestamps.min(), let maxTime = timestamps.max() else { return 0 }
        return maxTime.timeIntervalSince(minTime) / 3600
    }

    // MARK: - Cache Efficiency

    public static func cacheSavings(from stats: UsageStats) -> CacheSavings {
        let cacheReadTokens = stats.byModel.reduce(0) { $0 + $1.tokens.cacheRead }
        let estimatedSaved = estimateCacheSavings(cacheReadTokens)
        return CacheSavings(
            tokensSaved: cacheReadTokens,
            estimatedSaved: estimatedSaved,
            description: cacheSavingsDescription(tokens: cacheReadTokens, saved: estimatedSaved)
        )
    }

    private static func estimateCacheSavings(_ cacheReadTokens: Int) -> Double {
        max(0, Double(cacheReadTokens) * 0.000009)
    }

    private static func cacheSavingsDescription(tokens: Int, saved: Double) -> String {
        tokens > 0
            ? "Saved ~$\(String(format: "%.2f", saved)) with cache (\(tokens.abbreviated) tokens)"
            : "No cache usage yet"
    }
}

// MARK: - Hourly Accumulation

public extension UsageAnalytics {

    static func todayHourlyAccumulation(from entries: [UsageEntry], referenceDate: Date = Date()) -> [Double] {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: referenceDate)

        let todayEntries = UsageAggregator.filterToday(entries, referenceDate: referenceDate)
        let hourlyCosts = groupCostsByHour(todayEntries, calendar: calendar)
        return buildCumulativeArray(from: hourlyCosts, throughHour: currentHour)
    }

    private static func groupCostsByHour(_ entries: [UsageEntry], calendar: Calendar) -> [Int: Double] {
        entries.reduce(into: [Int: Double]()) { result, entry in
            let hour = calendar.component(.hour, from: entry.timestamp)
            result[hour, default: 0] += entry.costUSD
        }
    }

    private static func buildCumulativeArray(from hourlyCosts: [Int: Double], throughHour: Int) -> [Double] {
        (0...throughHour)
            .map { hourlyCosts[$0] ?? 0 }
            .reduce(into: [Double]()) { cumulative, cost in
                let runningTotal = (cumulative.last ?? 0) + cost
                cumulative.append(runningTotal)
            }
    }
}

// MARK: - Formatting Extensions

public extension Int {
    var abbreviated: String {
        abbreviatedNumber(self)
    }
}

private func abbreviatedNumber(_ value: Int) -> String {
    switch value {
    case 1_000_000_000...:
        return String(format: "%.1fB", Double(value) / 1_000_000_000)
    case 1_000_000...:
        return String(format: "%.1fM", Double(value) / 1_000_000)
    case 1_000...:
        return String(format: "%.1fK", Double(value) / 1_000)
    default:
        return "\(value)"
    }
}

public extension Double {
    var asCurrency: String {
        String(format: "$%.2f", self)
    }

    var asPercentage: String {
        String(format: "%.1f%%", self)
    }
}

// MARK: - Supporting Types

public struct CacheSavings: Sendable {
    public let tokensSaved: Int
    public let estimatedSaved: Double
    public let description: String

    public init(tokensSaved: Int, estimatedSaved: Double, description: String) {
        self.tokensSaved = tokensSaved
        self.estimatedSaved = estimatedSaved
        self.description = description
    }
}
