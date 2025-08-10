//
//  ClaudeUsageClient.swift
//  ClaudeCodeUsage
//
//  API client using SOLID principles and dependency injection
//

import Foundation

/// Client using the repository pattern and SOLID principles
public actor ClaudeUsageClient: UsageDataSource {
    
    /// Shared instance
    public static let shared = ClaudeUsageClient()
    
    private let repository: UsageRepository
    
    /// Data source mode
    public enum DataSource {
        case localFiles(basePath: String)
    }
    
    /// Initialize with a specific data source
    public init(dataSource: DataSource = .localFiles(basePath: NSHomeDirectory() + "/.claude")) {
        switch dataSource {
        case .localFiles(let basePath):
            self.repository = UsageRepository(basePath: basePath)
        }
    }
    
    /// Initialize with custom dependencies (for testing)
    internal init(repository: UsageRepository) {
        self.repository = repository
    }
    
    // MARK: - Public API
    
    /// Get overall usage statistics
    public func getUsageStats() async throws -> UsageStats {
        return try await repository.getUsageStats()
    }
    
    /// Get usage statistics filtered by date range
    public func getUsageByDateRange(startDate: Date, endDate: Date) async throws -> UsageStats {
        let allStats = try await getUsageStats()
        return FilterService.filterByDateRange(allStats, start: startDate, end: endDate)
    }
    
    /// Get session-level statistics
    public func getSessionStats(since: Date? = nil, until: Date? = nil, order: SortOrder? = nil) async throws -> [ProjectUsage] {
        let allStats = try await getUsageStats()
        var projects = allStats.byProject
        
        // Apply date filtering
        if let since = since, let until = until {
            projects = FilterService.filterProjects(projects, since: since, until: until)
        }
        
        // Apply sorting
        if let order = order {
            projects = SortingService.sortProjects(projects, order: order)
        }
        
        return projects
    }
    
    /// Get detailed usage entries
    public func getUsageDetails(limit: Int? = nil) async throws -> [UsageEntry] {
        return try await repository.getUsageEntries(limit: limit)
    }
    
    /// Get today's usage entries with timestamps
    public func getTodayUsageEntries() async throws -> [UsageEntry] {
        let allEntries = try await getUsageDetails()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return allEntries.filter { entry in
            guard let date = entry.date else { return false }
            return date >= today && date < tomorrow
        }
    }
}

// MARK: - Filter Service

/// Service for filtering usage data (Single Responsibility)
struct FilterService {
    static func filterByDateRange(_ stats: UsageStats, start: Date, end: Date) -> UsageStats {
        // For "all time" (distant past), just return original stats
        if start.timeIntervalSince1970 < 0 {
            return stats
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        let filteredByDate = stats.byDate.filter { daily in
            daily.date >= startString && daily.date <= endString
        }
        
        // If no data in range, return original stats
        if filteredByDate.isEmpty {
            return stats
        }
        
        // Recalculate totals based on filtered data (single-pass reduction)
        let (totalCost, totalTokens) = filteredByDate.reduce((0.0, 0)) { acc, daily in
            (acc.0 + daily.totalCost, acc.1 + daily.totalTokens)
        }
        
        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: stats.totalInputTokens,
            totalOutputTokens: stats.totalOutputTokens,
            totalCacheCreationTokens: stats.totalCacheCreationTokens,
            totalCacheReadTokens: stats.totalCacheReadTokens,
            totalSessions: stats.totalSessions,
            byModel: stats.byModel,
            byDate: filteredByDate,
            byProject: stats.byProject
        )
    }
    
    static func filterProjects(_ projects: [ProjectUsage], since: Date, until: Date) -> [ProjectUsage] {
        return projects.filter { project in
            if let date = project.lastUsedDate {
                return date >= since && date <= until
            }
            return false
        }
    }
}

// MARK: - Sorting Service

/// Service for sorting usage data (Single Responsibility)
struct SortingService {
    static func sortProjects(_ projects: [ProjectUsage], order: SortOrder) -> [ProjectUsage] {
        return projects.sorted { (a, b) in
            order == .ascending ? a.totalCost < b.totalCost : a.totalCost > b.totalCost
        }
    }
}

/// Protocol for usage data source
public protocol UsageDataSource {
    func getUsageStats() async throws -> UsageStats
    func getUsageByDateRange(startDate: Date, endDate: Date) async throws -> UsageStats
    func getSessionStats(since: Date?, until: Date?, order: SortOrder?) async throws -> [ProjectUsage]
    func getUsageDetails(limit: Int?) async throws -> [UsageEntry]
}

/// Sort order for queries
public enum SortOrder: String {
    case ascending = "asc"
    case descending = "desc"
}
