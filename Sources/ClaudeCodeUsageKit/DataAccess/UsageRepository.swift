//
//  UsageRepository.swift
//  ClaudeCodeUsage
//
//  Repository for accessing and processing Claude Code usage data.
//  Simplified architecture: no protocol indirection, direct implementations.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Repository")

/// Sort order for queries
public enum SortOrder: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

/// Repository for accessing and processing usage data.
/// Uses actor isolation for thread safety.
public actor UsageRepository {
    public let basePath: String

    /// Shared instance using default path
    public static let shared = UsageRepository()

    /// Initialize with base path (defaults to ~/.claude)
    public init(basePath: String = NSHomeDirectory() + "/.claude") {
        self.basePath = basePath
    }

    // MARK: - Public API

    /// Get overall usage statistics
    public func getUsageStats() async throws -> UsageStats {
        let projectsPath = basePath + "/projects"

        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return createEmptyStats()
        }

        let deduplication = Deduplication()
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)

        let entries: [UsageEntry]
        if sortedFiles.count > 500 {
            entries = await processFilesInBatches(sortedFiles, batchSize: 100, deduplication: deduplication)
        } else {
            entries = await processFiles(sortedFiles, deduplication: deduplication)
        }

        #if DEBUG
        print("[UsageRepository] Loaded \(entries.count) entries from \(sortedFiles.count) files")
        #endif

        let sessionCount = countUniqueSessions(from: sortedFiles)
        return aggregateStatistics(from: entries, sessionCount: sessionCount)
    }

    /// Get detailed usage entries
    public func getUsageEntries(limit: Int? = nil) async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"

        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        let deduplication = Deduplication()
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        var entries = await processFiles(sortedFiles, deduplication: deduplication)

        entries.sort { $0.timestamp > $1.timestamp }

        if let limit = limit {
            return Array(entries.prefix(limit))
        }
        return entries
    }

    /// Get today's usage entries only - optimized for fast initial load
    public func getTodayUsageEntries() async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"

        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        let deduplication = Deduplication()
        let allFiles = try collectJSONLFiles(from: projectsPath)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()

        let todayFiles = allFiles.filter { file in
            if let date = formatter.date(from: file.earliestTimestamp) {
                return date >= todayStart
            }
            return false
        }

        #if DEBUG
        print("[UsageRepository] Today's files: \(todayFiles.count) of \(allFiles.count) total")
        #endif

        return await processFiles(todayFiles, deduplication: deduplication)
    }

    /// Get today's stats - fast path for initial load
    public func getTodayUsageStats() async throws -> UsageStats {
        let entries = try await getTodayUsageEntries()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        return aggregateStatistics(from: entries, sessionCount: sessionCount)
    }

    /// Get usage statistics filtered by date range
    public func getUsageByDateRange(startDate: Date, endDate: Date) async throws -> UsageStats {
        let allStats = try await getUsageStats()
        return filterByDateRange(allStats, start: startDate, end: endDate)
    }

    /// Get session-level statistics with optional filtering and sorting
    public func getSessionStats(
        since: Date? = nil,
        until: Date? = nil,
        order: SortOrder? = nil
    ) async throws -> [ProjectUsage] {
        let allStats = try await getUsageStats()
        var projects = allStats.byProject

        if let since = since, let until = until {
            projects = projects.filter { project in
                if let date = project.lastUsedDate {
                    return date >= since && date <= until
                }
                return false
            }
        }

        if let order = order {
            projects = projects.sorted { a, b in
                order == .ascending ? a.totalCost < b.totalCost : a.totalCost > b.totalCost
            }
        }

        return projects
    }

    /// Load entries for a specific date
    public func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry] {
        let allEntries = try await getUsageEntries()
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        return allEntries.filter { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.startOfDay(for: entryDate) == targetDay
        }
    }

    // MARK: - File Collection

    private func collectJSONLFiles(
        from projectsPath: String
    ) throws -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        var filesToProcess: [(path: String, projectDir: String, earliestTimestamp: String)] = []
        let projectDirs = try FileManager.default.contentsOfDirectory(atPath: projectsPath)

        for projectDir in projectDirs {
            if shouldSkipDirectory(projectDir) { continue }

            let projectPath = projectsPath + "/" + projectDir

            let files: [String]
            do {
                files = try FileManager.default.contentsOfDirectory(atPath: projectPath)
            } catch {
                logger.warning("Failed to read directory \(projectPath): \(error.localizedDescription)")
                continue
            }

            for file in files where file.hasSuffix(".jsonl") {
                let filePath = projectPath + "/" + file
                if let earliestTimestamp = getEarliestTimestamp(from: filePath) {
                    filesToProcess.append((
                        path: filePath,
                        projectDir: projectDir,
                        earliestTimestamp: earliestTimestamp
                    ))
                }
            }
        }

        return filesToProcess
    }

    private func sortFilesByTimestamp(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)]
    ) -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        files.sorted { $0.earliestTimestamp < $1.earliestTimestamp }
    }

    // MARK: - File Processing

    private func processFiles(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        if files.count > 5 {
            return await processFilesInParallel(files, deduplication: deduplication)
        } else {
            return processFilesSequentially(files, deduplication: deduplication)
        }
    }

    private func processFilesSequentially(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: Deduplication
    ) -> [UsageEntry] {
        var allEntries: [UsageEntry] = []
        for (filePath, projectDir, _) in files {
            let entries = processJSONLFile(at: filePath, projectDir: projectDir, deduplication: deduplication)
            allEntries.append(contentsOf: entries)
        }
        return allEntries
    }

    private func processFilesInParallel(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        await withTaskGroup(of: [UsageEntry].self) { group in
            for (filePath, projectDir, _) in files {
                group.addTask {
                    await self.processJSONLFile(at: filePath, projectDir: projectDir, deduplication: deduplication)
                }
            }

            var allEntries: [UsageEntry] = []
            for await entries in group {
                allEntries.append(contentsOf: entries)
            }
            return allEntries
        }
    }

    private func processFilesInBatches(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        batchSize: Int,
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        var allEntries: [UsageEntry] = []
        let totalBatches = (files.count + batchSize - 1) / batchSize

        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, files.count)
            let batch = Array(files[startIndex..<endIndex])
            let batchEntries = await processFilesInParallel(batch, deduplication: deduplication)
            allEntries.append(contentsOf: batchEntries)
        }

        return allEntries
    }

    private func processJSONLFile(
        at path: String,
        projectDir: String,
        deduplication: Deduplication
    ) -> [UsageEntry] {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return []
        }

        let decodedProjectPath = decodeProjectPath(projectDir)
        var entries: [UsageEntry] = []
        let lineRanges = extractLineRanges(from: fileData)

        for range in lineRanges {
            let lineData = fileData[range]

            guard lineData.count > 2,
                  lineData.first == 0x7B,  // '{'
                  lineData.last == 0x7D    // '}'
            else { continue }

            guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let messageId = extractMessageId(from: json)
            let requestId = extractRequestId(from: json)

            guard deduplication.shouldInclude(messageId: messageId, requestId: requestId) else {
                continue
            }

            if let entry = createEntry(from: json, projectPath: decodedProjectPath) {
                entries.append(entry)
            }
        }

        return entries
    }

    /// Extract line ranges using memchr for SIMD-optimized byte scanning
    private func extractLineRanges(from data: Data) -> [Range<Data.Index>] {
        var ranges: [Range<Data.Index>] = []
        let count = data.count
        guard count > 0 else { return ranges }

        let bytes = [UInt8](data)
        bytes.withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return }
            var offset = 0

            while offset < count {
                let remaining = count - offset
                let lineEnd: Int

                if let found = memchr(ptr + offset, 0x0A, remaining) {
                    lineEnd = UnsafePointer(found.assumingMemoryBound(to: UInt8.self)) - ptr
                } else {
                    lineEnd = count
                }

                if lineEnd > offset {
                    ranges.append(offset..<lineEnd)
                }
                offset = lineEnd + 1
            }
        }

        return ranges
    }

    // MARK: - JSON Parsing (Inlined from UsageDataParserProtocol)

    private func extractMessageId(from json: [String: Any]) -> String? {
        guard let message = json["message"] as? [String: Any] else { return nil }
        return message["id"] as? String
    }

    private func extractRequestId(from json: [String: Any]) -> String? {
        json["requestId"] as? String
    }

    private func createEntry(from json: [String: Any], projectPath: String) -> UsageEntry? {
        guard let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return nil
        }

        let model = message["model"] as? String ?? "unknown"
        let inputTokens = usage["input_tokens"] as? Int ?? 0
        let outputTokens = usage["output_tokens"] as? Int ?? 0
        let cacheWriteTokens = usage["cache_creation_input_tokens"] as? Int ?? 0
        let cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0

        if inputTokens == 0 && outputTokens == 0 && cacheWriteTokens == 0 && cacheReadTokens == 0 {
            return nil
        }

        var cost = json["costUSD"] as? Double ?? 0.0
        if cost == 0.0 && (inputTokens > 0 || outputTokens > 0) {
            if let pricing = ModelPricing.pricing(for: model) {
                cost = pricing.calculateCost(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheWriteTokens: cacheWriteTokens,
                    cacheReadTokens: cacheReadTokens
                )
            }
        }

        return UsageEntry(
            project: projectPath,
            timestamp: json["timestamp"] as? String ?? "",
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheWriteTokens: cacheWriteTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: json["sessionId"] as? String
        )
    }

    // MARK: - Path Decoding (Inlined from ProjectPathDecoder)

    private func decodeProjectPath(_ encodedPath: String) -> String {
        if encodedPath.hasPrefix("-") {
            return "/" + String(encodedPath.dropFirst()).replacingOccurrences(of: "-", with: "/")
        }
        return encodedPath.replacingOccurrences(of: "-", with: "/")
    }

    // MARK: - Statistics Aggregation (Inlined from StatisticsAggregator)

    private func aggregateStatistics(from entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        var totalCost = 0.0
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCacheWriteTokens = 0
        var totalCacheReadTokens = 0

        var modelStats: [String: ModelUsage] = [:]
        var dailyStats: [String: DailyUsage] = [:]
        var projectStats: [String: ProjectUsage] = [:]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for entry in entries {
            totalCost += entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheWriteTokens += entry.cacheWriteTokens
            totalCacheReadTokens += entry.cacheReadTokens

            // Model stats
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

            // Daily stats
            if let date = entry.date {
                let dateString = dateFormatter.string(from: date)
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

            // Project stats
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

    // MARK: - Filtering (Inlined from FilterService)

    private func filterByDateRange(_ stats: UsageStats, start: Date, end: Date) -> UsageStats {
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

        if filteredByDate.isEmpty {
            return stats
        }

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

    // MARK: - Helpers

    private func getEarliestTimestamp(from path: String) -> String? {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let modDate = attributes[.modificationDate] as? Date {
            return ISO8601DateFormatter().string(from: modDate)
        }
        return ISO8601DateFormatter().string(from: Date())
    }

    private func countUniqueSessions(
        from files: [(path: String, projectDir: String, earliestTimestamp: String)]
    ) -> Int {
        var sessionIds = Set<String>()
        for (filePath, _, _) in files {
            let filename = URL(fileURLWithPath: filePath).lastPathComponent
            if filename.hasSuffix(".jsonl") {
                sessionIds.insert(String(filename.dropLast(6)))
            }
        }
        return sessionIds.count
    }

    private func shouldSkipDirectory(_ directoryName: String) -> Bool {
        directoryName.hasPrefix("-private-var-folders-") ||
        directoryName.contains("claude-kit-sessions") ||
        directoryName.hasPrefix(".")
    }

    private func createEmptyStats() -> UsageStats {
        UsageStats(
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
}

// MARK: - Deduplication (Inlined from DeduplicationService)

/// Thread-safe deduplication using messageId:requestId hash
private final class Deduplication: @unchecked Sendable {
    private var processedHashes: Set<String> = []
    private let queue = DispatchQueue(label: "com.claudeusage.deduplication", attributes: .concurrent)

    func shouldInclude(messageId: String?, requestId: String?) -> Bool {
        guard let messageId = messageId, let requestId = requestId else {
            return true
        }

        let uniqueHash = "\(messageId):\(requestId)"

        var shouldInclude = false
        queue.sync(flags: .barrier) {
            if !processedHashes.contains(uniqueHash) {
                processedHashes.insert(uniqueHash)
                shouldInclude = true
            }
        }

        return shouldInclude
    }
}
