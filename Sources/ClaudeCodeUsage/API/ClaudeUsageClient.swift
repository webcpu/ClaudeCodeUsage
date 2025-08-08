//
//  ClaudeUsageClient.swift
//  ClaudeCodeUsage
//
//  API client using SOLID principles and dependency injection
//

import Foundation

/// Client using the repository pattern and SOLID principles
public class ClaudeUsageClient: UsageDataSource {
    
    /// Shared instance
    public static let shared = ClaudeUsageClient()
    
    private let repository: UsageRepository
    private let mockDataProvider: MockDataProvider?
    
    /// Data source mode
    public enum DataSource {
        case localFiles(basePath: String)
        case mock
    }
    
    /// Initialize with a specific data source
    public init(dataSource: DataSource = .localFiles(basePath: NSHomeDirectory() + "/.claude")) {
        switch dataSource {
        case .localFiles(let basePath):
            self.repository = UsageRepository(basePath: basePath)
            self.mockDataProvider = nil
            
        case .mock:
            // Use mock file system for testing
            let mockFS = MockFileSystem()
            self.repository = UsageRepository(
                fileSystem: mockFS,
                parser: JSONLUsageParser(),
                deduplication: NoDeduplication(),
                pathDecoder: ProjectPathDecoder(),
                aggregator: StatisticsAggregator(),
                basePath: "/mock"
            )
            self.mockDataProvider = MockDataProvider()
        }
    }
    
    /// Initialize with custom dependencies (for testing)
    public init(repository: UsageRepository, mockDataProvider: MockDataProvider? = nil) {
        self.repository = repository
        self.mockDataProvider = mockDataProvider
    }
    
    // MARK: - Public API
    
    /// Get overall usage statistics
    public func getUsageStats() async throws -> UsageStats {
        if let mockProvider = mockDataProvider {
            return mockProvider.mockUsageStats()
        }
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
        if let mockProvider = mockDataProvider {
            return mockProvider.mockUsageEntries(count: limit ?? 10)
        }
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
        
        // Recalculate totals based on filtered data
        let totalCost = filteredByDate.reduce(0) { $0 + $1.totalCost }
        let totalTokens = filteredByDate.reduce(0) { $0 + $1.totalTokens }
        
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

// MARK: - Mock Data Provider

/// Provider for mock data (Single Responsibility)
public struct MockDataProvider {
    
    public init() {}
    
    public func mockUsageStats() -> UsageStats {
        let dailyUsage = mockDailyUsage()
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }
        
        let sonnet4Stats = ModelUsage(
            model: "claude-3-5-sonnet-20241022",
            totalCost: 73.76,
            totalTokens: 315_741,
            inputTokens: 4_666,
            outputTokens: 311_075,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            sessionCount: 7
        )
        
        let opus4Stats = ModelUsage(
            model: "claude-opus-4-1-20250805",
            totalCost: 108.85,
            totalTokens: 47_813,
            inputTokens: 3_896,
            outputTokens: 43_917,
            cacheCreationTokens: 0,
            cacheReadTokens: 0,
            sessionCount: 1
        )
        
        return UsageStats(
            totalCost: totalCost,
            totalTokens: totalTokens,
            totalInputTokens: 8_562,
            totalOutputTokens: 354_992,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 8,
            byModel: [opus4Stats, sonnet4Stats],
            byDate: dailyUsage,
            byProject: mockProjectUsage()
        )
    }
    
    func mockDailyUsage() -> [DailyUsage] {
        return [
            DailyUsage(date: "2025-07-30", totalCost: 4.00, totalTokens: 16_010,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-07-31", totalCost: 10.04, totalTokens: 19_844,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-01", totalCost: 0.40, totalTokens: 1_554,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-02", totalCost: 1.07, totalTokens: 1_876,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-03", totalCost: 12.07, totalTokens: 65_057,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-04", totalCost: 40.06, totalTokens: 187_442,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-05", totalCost: 6.12, totalTokens: 28_624,
                      modelsUsed: ["claude-3-5-sonnet-20241022"]),
            DailyUsage(date: "2025-08-06", totalCost: 108.85, totalTokens: 47_813,
                      modelsUsed: ["claude-opus-4-1-20250805"])
        ]
    }
    
    func mockProjectUsage() -> [ProjectUsage] {
        [
            ProjectUsage(
                projectPath: "/Users/liang/Downloads/Data/tmp/claudia",
                projectName: "claudia",
                totalCost: 108.85,
                totalTokens: 47_813,
                sessionCount: 1,
                lastUsed: "2025-08-06T19:39:00Z"
            ),
            ProjectUsage(
                projectPath: "/Users/liang/Projects/swift-sdk",
                projectName: "swift-sdk",
                totalCost: 73.76,
                totalTokens: 315_741,
                sessionCount: 7,
                lastUsed: "2025-08-05T18:00:00Z"
            )
        ]
    }
    
    public func mockUsageEntries(count: Int) -> [UsageEntry] {
        (0..<count).map { index in
            UsageEntry(
                project: "/Users/user/project\(index % 3)",
                timestamp: ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(-index * 3600))),
                model: index % 2 == 0 ? "claude-opus-4-1-20250805" : "claude-3-5-sonnet-20241022",
                inputTokens: Int.random(in: 1000...10000),
                outputTokens: Int.random(in: 500...5000),
                cacheWriteTokens: Int.random(in: 0...1000),
                cacheReadTokens: Int.random(in: 0...500),
                cost: Double.random(in: 0.01...1.0),
                sessionId: UUID().uuidString
            )
        }
    }
}