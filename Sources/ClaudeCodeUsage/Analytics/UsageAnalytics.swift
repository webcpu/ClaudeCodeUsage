//
//  UsageAnalytics.swift
//  ClaudeCodeUsage
//
//  Analytics and computations for usage data
//

import Foundation

public enum UsageAnalytics {
    
    // MARK: - Cost Calculations
    
    /// Calculate total cost from usage entries
    public static func totalCost(from entries: [UsageEntry]) -> Double {
        entries.reduce(0) { $0 + $1.cost }
    }
    
    /// Calculate average cost per session
    public static func averageCostPerSession(from entries: [UsageEntry]) -> Double {
        let sessions = Set(entries.compactMap { $0.sessionId })
        guard !sessions.isEmpty else { return 0 }
        return totalCost(from: entries) / Double(sessions.count)
    }
    
    /// Get cost breakdown by model
    public static func costBreakdown(from stats: UsageStats) -> [(model: String, cost: Double, percentage: Double)] {
        let total = stats.totalCost
        guard total > 0 else { return [] }
        
        return stats.byModel
            .sorted { $0.totalCost > $1.totalCost }
            .map { model in
                (model: model.model,
                 cost: model.totalCost,
                 percentage: (model.totalCost / total) * 100)
            }
    }
    
    // MARK: - Token Analysis
    
    /// Calculate total tokens from usage entries
    public static func totalTokens(from entries: [UsageEntry]) -> Int {
        entries.reduce(0) { $0 + $1.totalTokens }
    }
    
    /// Get token breakdown by type
    public static func tokenBreakdown(from stats: UsageStats) -> (
        inputPercentage: Double,
        outputPercentage: Double,
        cacheWritePercentage: Double,
        cacheReadPercentage: Double
    ) {
        let total = Double(stats.totalTokens)
        guard total > 0 else { return (0, 0, 0, 0) }
        
        let input = stats.byModel.reduce(0) { $0 + $1.inputTokens }
        let output = stats.byModel.reduce(0) { $0 + $1.outputTokens }
        let cacheWrite = stats.byModel.reduce(0) { $0 + $1.cacheCreationTokens }
        let cacheRead = stats.byModel.reduce(0) { $0 + $1.cacheReadTokens }
        
        return (
            inputPercentage: (Double(input) / total) * 100,
            outputPercentage: (Double(output) / total) * 100,
            cacheWritePercentage: (Double(cacheWrite) / total) * 100,
            cacheReadPercentage: (Double(cacheRead) / total) * 100
        )
    }
    
    // MARK: - Time-based Analysis
    
    /// Filter entries by date range
    public static func filterByDateRange(_ entries: [UsageEntry], from startDate: Date, to endDate: Date) -> [UsageEntry] {
        entries.filter { entry in
            guard let date = entry.date else { return false }
            return date >= startDate && date <= endDate
        }
    }
    
    /// Group entries by date
    public static func groupByDate(_ entries: [UsageEntry]) -> [String: [UsageEntry]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current // Use local timezone for grouping
        
        var grouped: [String: [UsageEntry]] = [:]
        for entry in entries {
            guard let date = entry.date else { continue }
            let dateString = formatter.string(from: date)
            grouped[dateString, default: []].append(entry)
        }
        return grouped
    }
    
    /// Get daily usage statistics
    public static func dailyUsage(from entries: [UsageEntry]) -> [DailyUsage] {
        let grouped = groupByDate(entries)
        
        return grouped.map { (date, dayEntries) in
            let models = Set(dayEntries.map { $0.model })
            return DailyUsage(
                date: date,
                totalCost: totalCost(from: dayEntries),
                totalTokens: totalTokens(from: dayEntries),
                modelsUsed: Array(models)
            )
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Predictions
    
    /// Predict monthly cost based on daily average
    public static func predictMonthlyCost(from stats: UsageStats, daysElapsed: Int) -> Double {
        guard daysElapsed > 0 else { return 0 }
        let dailyAverage = stats.totalCost / Double(daysElapsed)
        return dailyAverage * 30
    }
    
    /// Calculate burn rate (cost per hour)
    public static func burnRate(from entries: [UsageEntry], hours: Int = 24) -> Double {
        let recentEntries = entries.suffix(100) // Look at recent entries
        guard !recentEntries.isEmpty else { return 0 }
        
        let timeRange = recentEntries.compactMap { $0.date }.reduce((min: Date.distantFuture, max: Date.distantPast)) { result, date in
            (min: min(result.min, date), max: max(result.max, date))
        }
        
        let hours = timeRange.max.timeIntervalSince(timeRange.min) / 3600
        guard hours > 0 else { return 0 }
        
        return totalCost(from: Array(recentEntries)) / hours
    }
    
    // MARK: - Cache Efficiency
    
    /// Calculate cache savings
    public static func cacheSavings(from stats: UsageStats) -> CacheSavings {
        let cacheReadTokens = stats.byModel.reduce(0) { $0 + $1.cacheReadTokens }
        let inputTokens = stats.byModel.reduce(0) { $0 + $1.inputTokens }
        
        // Estimate savings (cache reads are typically 10% of input cost)
        let estimatedInputCost = Double(inputTokens) * 0.00001 // Rough estimate
        let estimatedCacheCost = Double(cacheReadTokens) * 0.000001 // 10% of input
        let saved = max(0, (Double(cacheReadTokens) * 0.000009)) // 90% savings
        
        return CacheSavings(
            tokensSaved: cacheReadTokens,
            estimatedSaved: saved,
            description: cacheReadTokens > 0 ? 
                "Saved ~$\(String(format: "%.2f", saved)) with cache (\(cacheReadTokens.abbreviated) tokens)" :
                "No cache usage yet"
        )
    }
}

// Note: TimeRange is already defined in UsageModels.swift

// MARK: - Formatting Extensions
public extension Int {
    /// Format large numbers with abbreviations (K, M, B)
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

// MARK: - Supporting Types
public struct CacheSavings {
    public let tokensSaved: Int
    public let estimatedSaved: Double
    public let description: String
}

// MARK: - Hourly Accumulation
public extension UsageAnalytics {
    /// Get hourly cost accumulation for today from usage entries (cumulative)
    static func todayHourlyAccumulation(from entries: [UsageEntry]) -> [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentHour = calendar.component(.hour, from: Date())
        
        // Filter entries for today
        let todayEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
        
        // Sort by timestamp
        let sortedEntries = todayEntries.sorted { 
            ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) 
        }
        
        // Group costs by hour
        var hourlyCosts = [Int: Double]()
        for entry in sortedEntries {
            guard let date = entry.date else { continue }
            let hour = calendar.component(.hour, from: date)
            hourlyCosts[hour, default: 0] += entry.cost
        }
        
        // Create cumulative array
        var cumulative: [Double] = []
        var total = 0.0
        
        for hour in 0...currentHour {
            total += hourlyCosts[hour] ?? 0
            cumulative.append(total)
        }
        
        return cumulative
    }
    
    /// Get individual hourly costs for today from usage entries (non-cumulative) with proper timezone handling
    static func todayHourlyCosts(from entries: [UsageEntry]) -> [Double] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Debug: Print timezone info
        #if DEBUG
        print("Current timezone: \(calendar.timeZone.identifier)")
        print("Today starts at: \(today)")
        print("Current time: \(now)")
        #endif
        
        // Filter entries for today in local timezone
        let todayEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            // Calendar.isDate properly handles timezone conversion
            return calendar.isDate(date, inSameDayAs: today)
        }
        
        #if DEBUG
        print("Found \(todayEntries.count) entries for today")
        #endif
        
        // Group costs by hour in local timezone
        var hourlyCosts = [Int: Double]()
        for entry in todayEntries {
            guard let date = entry.date else { continue }
            // calendar.component automatically converts UTC to local timezone
            let hour = calendar.component(.hour, from: date)
            hourlyCosts[hour, default: 0] += entry.cost
            
            #if DEBUG
            if entry.cost > 0 {
                print("Entry at \(date) (UTC) -> hour \(hour) (local): $\(entry.cost)")
            }
            #endif
        }
        
        // Create full 24-hour array with individual hourly costs
        var hourlyArray: [Double] = []
        for hour in 0..<24 {
            let cost = hourlyCosts[hour] ?? 0
            hourlyArray.append(cost)
            
            #if DEBUG
            if cost > 0 {
                print("Hour \(hour): $\(cost)")
            }
            #endif
        }
        
        return hourlyArray
    }
}