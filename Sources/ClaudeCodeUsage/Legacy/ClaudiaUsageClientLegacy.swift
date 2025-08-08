//
//  ClaudeUsageClient.swift
//  ClaudeCodeUsage
//
//  API client for fetching Claude Code usage data
//

import Foundation
#if os(macOS) || os(iOS)
import Combine
#endif

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

/// Legacy client for accessing Claude Code usage data (deprecated - use ClaudeUsageClient instead)
public class ClaudiaUsageClientLegacy: UsageDataSource {
    
    /// Shared instance
    public static let shared = ClaudiaUsageClientLegacy()
    
    /// Data source mode
    public enum DataSource {
        case localFiles(basePath: String)
        case mock
    }
    
    private let dataSource: DataSource
    
    /// Initialize with a specific data source
    public init(dataSource: DataSource = .localFiles(basePath: NSHomeDirectory() + "/.claude")) {
        self.dataSource = dataSource
    }
    
    // MARK: - Public API
    
    /// Get overall usage statistics
    public func getUsageStats() async throws -> UsageStats {
        switch dataSource {
        case .localFiles(let basePath):
            return try await parseLocalUsageFiles(basePath: basePath)
            
        case .mock:
            return mockUsageStats()
        }
    }
    
    /// Get usage statistics filtered by date range
    public func getUsageByDateRange(startDate: Date, endDate: Date) async throws -> UsageStats {
        switch dataSource {
        case .localFiles(let basePath):
            let allStats = try await parseLocalUsageFiles(basePath: basePath)
            return filterStatsByDateRange(allStats, start: startDate, end: endDate)
            
        case .mock:
            return mockUsageStats()
        }
    }
    
    /// Get session-level statistics
    public func getSessionStats(since: Date? = nil, until: Date? = nil, order: SortOrder? = nil) async throws -> [ProjectUsage] {
        switch dataSource {
        case .localFiles(let basePath):
            let allStats = try await parseLocalUsageFiles(basePath: basePath)
            var projects = allStats.byProject
            
            // Apply date filtering
            if let since = since, let until = until {
                projects = projects.filter { project in
                    if let date = project.lastUsedDate {
                        return date >= since && date <= until
                    }
                    return false
                }
            }
            
            // Apply sorting
            if let order = order {
                projects.sort { (a, b) in
                    order == .ascending ? a.totalCost < b.totalCost : a.totalCost > b.totalCost
                }
            }
            
            return projects
            
        case .mock:
            return mockProjectUsage()
        }
    }
    
    /// Get detailed usage entries
    public func getUsageDetails(limit: Int? = nil) async throws -> [UsageEntry] {
        switch dataSource {
        case .localFiles(let basePath):
            let entries = try await parseLocalUsageEntries(basePath: basePath)
            if let limit = limit {
                return Array(entries.prefix(limit))
            }
            return entries
            
        case .mock:
            return mockUsageEntries(count: limit ?? 10)
        }
    }
    
    // MARK: - Private Methods
    
    private func parseLocalUsageFiles(basePath: String) async throws -> UsageStats {
        let projectsPath = basePath + "/projects"
        let fileManager = FileManager.default
        
        var allEntries: [UsageEntry] = []
        var sessionIds = Set<String>()
        var processedHashes = Set<String>() // For deduplication
        
        // Check if projects directory exists
        guard fileManager.fileExists(atPath: projectsPath) else {
            // Removed debug print to avoid console clutter
            return UsageStats(
                totalCost: 0,
                totalTokens: 0,
                totalInputTokens: 0,
                totalOutputTokens: 0,
                totalCacheCreationTokens: 0,
                totalCacheReadTokens: 0,
                totalSessions: 0,
                byModel: [],
                byDate: [],
                byProject: []
            )
        }
        
        // Collect all JSONL files with their earliest timestamps
        var filesToProcess: [(path: String, projectDir: String, earliestTimestamp: String)] = []
        
        // Scan all project directories
        if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
            for projectDir in projectDirs {
                let projectPath = projectsPath + "/" + projectDir
                
                // Look for JSONL files
                if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
                    let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
                    
                    for file in jsonlFiles {
                        let sessionId = String(file.dropLast(6)) // Remove .jsonl
                        sessionIds.insert(sessionId)
                        
                        let filePath = projectPath + "/" + file
                        // Get earliest timestamp from file for sorting
                        if let earliestTimestamp = getEarliestTimestamp(from: filePath) {
                            filesToProcess.append((path: filePath, projectDir: projectDir, earliestTimestamp: earliestTimestamp))
                        }
                    }
                }
            }
        }
        
        // Sort files by their earliest timestamp (matching Rust backend)
        filesToProcess.sort { $0.earliestTimestamp < $1.earliestTimestamp }
        
        // Process files in order with deduplication
        for (filePath, projectDir, _) in filesToProcess {
            do {
                let entries = try parseJSONLFileWithDeduplication(at: filePath, projectPath: projectDir, processedHashes: &processedHashes)
                if !entries.isEmpty {
                    allEntries.append(contentsOf: entries)
                }
            } catch {
                // Silently skip files with parsing errors
            }
        }
        
        // Calculate statistics
        return calculateStats(from: allEntries, sessionCount: sessionIds.count)
    }
    
    private func getEarliestTimestamp(from path: String) -> String? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let lines = content.components(separatedBy: .newlines)
        
        var earliestTimestamp: String?
        
        for line in lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestamp = json["timestamp"] as? String else { continue }
            
            if let current = earliestTimestamp {
                if timestamp < current {
                    earliestTimestamp = timestamp
                }
            } else {
                earliestTimestamp = timestamp
            }
        }
        
        return earliestTimestamp
    }
    
    private func parseLocalUsageEntries(basePath: String) async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"
        let fileManager = FileManager.default
        
        var allEntries: [UsageEntry] = []
        
        // Scan all project directories
        if let projectDirs = try? fileManager.contentsOfDirectory(atPath: projectsPath) {
            for projectDir in projectDirs {
                let projectPath = projectsPath + "/" + projectDir
                
                // Look for JSONL files
                if let files = try? fileManager.contentsOfDirectory(atPath: projectPath) {
                    for file in files where file.hasSuffix(".jsonl") {
                        let filePath = projectPath + "/" + file
                        if let entries = try? parseJSONLFile(at: filePath, projectPath: projectDir) {
                            allEntries.append(contentsOf: entries)
                        }
                    }
                }
            }
        }
        
        // Sort by timestamp (newest first)
        allEntries.sort { $0.timestamp > $1.timestamp }
        
        return allEntries
    }
    
    private func parseJSONLFile(at path: String, projectPath: String) throws -> [UsageEntry] {
        // Keep original method for backward compatibility
        var processedHashes = Set<String>()
        return try parseJSONLFileWithDeduplication(at: path, projectPath: projectPath, processedHashes: &processedHashes)
    }
    
    private func parseJSONLFileWithDeduplication(at path: String, projectPath: String, processedHashes: inout Set<String>) throws -> [UsageEntry] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = decodeProjectPath(projectPath)
        
        for line in lines {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Look for messages with usage data
                if let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    
                    // Deduplication based on message ID and request ID (matching Rust backend)
                    if let messageId = message["id"] as? String,
                       let requestId = json["requestId"] as? String {
                        let uniqueHash = "\(messageId):\(requestId)"
                        if processedHashes.contains(uniqueHash) {
                            continue // Skip duplicate entry
                        }
                        processedHashes.insert(uniqueHash)
                    }
                    
                    let model = message["model"] as? String ?? "unknown"
                    let inputTokens = usage["input_tokens"] as? Int ?? 0
                    let outputTokens = usage["output_tokens"] as? Int ?? 0
                    let cacheWriteTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
                    
                    // Skip entries without meaningful token usage
                    if inputTokens == 0 && outputTokens == 0 && cacheWriteTokens == 0 && cacheReadTokens == 0 {
                        continue
                    }
                    
                    // Calculate cost if not provided (including cache read tokens like Rust)
                    var cost = json["costUSD"] as? Double ?? 0.0
                    if cost == 0.0 && (inputTokens > 0 || outputTokens > 0) {
                        // Use model pricing to calculate cost
                        if let pricing = ModelPricing.pricing(for: model) {
                            cost = pricing.calculateCost(
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                cacheWriteTokens: cacheWriteTokens,
                                cacheReadTokens: cacheReadTokens
                            )
                        }
                    }
                    
                    // Ensure timestamp is valid
                    let timestamp = json["timestamp"] as? String ?? ""
                    
                    let entry = UsageEntry(
                        project: decodedProjectPath,
                        timestamp: timestamp,
                        model: model,
                        inputTokens: inputTokens,
                        outputTokens: outputTokens,
                        cacheWriteTokens: cacheWriteTokens,
                        cacheReadTokens: cacheReadTokens,
                        cost: cost,
                        sessionId: json["sessionId"] as? String
                    )
                    
                    entries.append(entry)
                }
            }
        }
        
        return entries
    }
    
    private func decodeProjectPath(_ encodedPath: String) -> String {
        // Decode the project path - dashes replace slashes
        // Example: -Users-liang-Downloads -> /Users/liang/Downloads
        
        // Remove leading dash and replace remaining dashes with slashes
        if encodedPath.hasPrefix("-") {
            let pathWithoutLeadingDash = String(encodedPath.dropFirst())
            return "/" + pathWithoutLeadingDash.replacingOccurrences(of: "-", with: "/")
        }
        
        // Fallback for unexpected formats
        return encodedPath.replacingOccurrences(of: "-", with: "/")
    }
    
    private func calculateStats(from entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        var totalCost = 0.0
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheWriteTokens = 0
        var totalCacheReadTokens = 0
        
        var modelStats: [String: ModelUsage] = [:]
        var dailyStats: [String: DailyUsage] = [:]
        var projectStats: [String: ProjectUsage] = [:]
        
        for entry in entries {
            totalCost += entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheWriteTokens += entry.cacheWriteTokens
            totalCacheReadTokens += entry.cacheReadTokens
            
            // Update model stats
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
            
            // Update daily stats
            if let date = entry.date {
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
            
            // Update project stats
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
    
    private func filterStatsByDateRange(_ stats: UsageStats, start: Date, end: Date) -> UsageStats {
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
            totalInputTokens: stats.totalInputTokens, // Keep original for now
            totalOutputTokens: stats.totalOutputTokens,
            totalCacheCreationTokens: stats.totalCacheCreationTokens,
            totalCacheReadTokens: stats.totalCacheReadTokens,
            totalSessions: stats.totalSessions,
            byModel: stats.byModel,
            byDate: filteredByDate,
            byProject: stats.byProject
        )
    }
    
    // MARK: - Mock Data
    
    private func mockUsageStats() -> UsageStats {
        // Calculate totals from daily usage
        let dailyUsage = mockDailyUsage()
        let totalCost = dailyUsage.reduce(0) { $0 + $1.totalCost }
        let totalTokens = dailyUsage.reduce(0) { $0 + $1.totalTokens }
        
        // Separate model stats based on the data
        let sonnet4Stats = ModelUsage(
            model: "claude-3-5-sonnet-20241022",
            totalCost: 73.76,  // Sum of sonnet-4 days
            totalTokens: 315_741,  // Sum of sonnet-4 tokens
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
    
    private func mockDailyUsage() -> [DailyUsage] {
        // Precise daily usage data
        return [
            DailyUsage(
                date: "2025-07-30",
                totalCost: 4.00,
                totalTokens: 16_010,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-07-31",
                totalCost: 10.04,
                totalTokens: 19_844,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-01",
                totalCost: 0.40,
                totalTokens: 1_554,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-02",
                totalCost: 1.07,
                totalTokens: 1_876,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-03",
                totalCost: 12.07,
                totalTokens: 65_057,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-04",
                totalCost: 40.06,
                totalTokens: 187_442,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-05",
                totalCost: 6.12,
                totalTokens: 28_624,
                modelsUsed: ["claude-3-5-sonnet-20241022"]
            ),
            DailyUsage(
                date: "2025-08-06",
                totalCost: 108.85,
                totalTokens: 47_813,
                modelsUsed: ["claude-opus-4-1-20250805"]
            )
        ]
    }
    
    private func mockProjectUsage() -> [ProjectUsage] {
        [
            ProjectUsage(
                projectPath: "/Users/liang/Downloads/Data/tmp/Claude",
                projectName: "Claude",
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
    
    private func mockUsageEntries(count: Int) -> [UsageEntry] {
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

/// Errors that can occur in the usage client
public enum UsageClientError: LocalizedError {
    case fileNotFound
    case parsingError
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found"
        case .parsingError:
            return "Failed to parse usage data"
        }
    }
}
