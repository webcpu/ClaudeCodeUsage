//
//  UsageRepository.swift
//  ClaudeCodeUsage
//
//  Repository for accessing and processing Claude Code usage data.
//  Architecture: FP + SLAP (Functional Programming + Single Level of Abstraction Principle)
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Repository")

// MARK: - Constants

private enum Threshold {
    static let parallelProcessing = 5
    static let batchProcessing = 500
    static let batchSize = 100
}

private enum ByteValue {
    static let openBrace: UInt8 = 0x7B   // '{'
    static let closeBrace: UInt8 = 0x7D  // '}'
    static let newline: Int32 = 0x0A     // '\n'
}

private enum DateFormat {
    static let dayString = "yyyy-MM-dd"
}

// MARK: - File Metadata

private struct FileMetadata {
    let path: String
    let projectDir: String
    let earliestTimestamp: String
    let modificationDate: Date
}

// MARK: - Entry Cache

private struct CachedFile {
    let modificationDate: Date
    let entries: [UsageEntry]
}

// MARK: - Public Types

/// Sort order for queries
public enum SortOrder: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

// MARK: - Repository

/// Repository for accessing and processing usage data.
/// Uses actor isolation for thread safety.
/// Implements file-level caching based on modification time for optimal performance.
public actor UsageRepository {
    public let basePath: String

    /// Cache of parsed entries by file path, keyed on modification date
    private var fileCache: [String: CachedFile] = [:]

    /// Persistent deduplication state across loads
    private var globalDeduplication = Deduplication()

    /// Shared instance using default path
    public static let shared = UsageRepository()

    /// Initialize with base path (defaults to ~/.claude)
    public init(basePath: String = NSHomeDirectory() + "/.claude") {
        self.basePath = basePath
    }

    /// Clear cache (useful for testing or memory pressure)
    public func clearCache() {
        fileCache.removeAll()
        globalDeduplication = Deduplication()
    }

    // MARK: - Public API

    /// Get overall usage statistics
    public func getUsageStats() async throws -> UsageStats {
        let projectsPath = basePath + "/projects"
        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return UsageStats.empty
        }

        let files = try discoverFiles(in: projectsPath)
        let entries = await loadEntries(from: files)

        logger.debug("Loaded \(entries.count) entries from \(files.count) files")

        return Aggregator.aggregate(entries, sessionCount: countSessions(in: files))
    }

    /// Get detailed usage entries
    public func getUsageEntries(limit: Int? = nil) async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"
        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        let files = try discoverFiles(in: projectsPath)
        let entries = await loadEntries(from: files)
            .sorted { $0.timestamp > $1.timestamp }

        return limit.map { Array(entries.prefix($0)) } ?? entries
    }

    /// Get today's usage entries only - optimized for fast initial load
    public func getTodayUsageEntries() async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"
        guard FileManager.default.fileExists(atPath: projectsPath) else {
            return []
        }

        let allFiles = try discoverFiles(in: projectsPath)
        let todayFiles = filterFilesModifiedToday(allFiles)

        logger.debug("Today's files: \(todayFiles.count) of \(allFiles.count) total")

        // Load entries with fresh deduplication to allow re-loading on refresh
        let entries = await loadEntriesForToday(from: todayFiles)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
    }

    /// Load entries for today with fresh deduplication
    private func loadEntriesForToday(from files: [FileMetadata]) async -> [UsageEntry] {
        var cachedEntries: [UsageEntry] = []
        var dirtyFiles: [FileMetadata] = []

        for file in files {
            if let cached = fileCache[file.path],
               cached.modificationDate == file.modificationDate {
                cachedEntries.append(contentsOf: cached.entries)
            } else {
                dirtyFiles.append(file)
            }
        }

        // Fresh deduplication allows re-loading modified files during refresh
        // (global deduplication would skip entries already seen in previous loads)
        let freshDeduplication = Deduplication()
        let newEntries: [UsageEntry]
        if dirtyFiles.count > Threshold.parallelProcessing {
            newEntries = await loadEntriesInParallel(from: dirtyFiles, deduplication: freshDeduplication)
        } else {
            newEntries = loadEntriesSequentially(from: dirtyFiles, deduplication: freshDeduplication)
        }

        return cachedEntries + newEntries
    }

    /// Get today's stats - fast path for initial load
    public func getTodayUsageStats() async throws -> UsageStats {
        let entries = try await getTodayUsageEntries()
        let sessionCount = Set(entries.compactMap(\.sessionId)).count
        return Aggregator.aggregate(entries, sessionCount: sessionCount)
    }

    /// Get usage statistics filtered by date range
    public func getUsageByDateRange(startDate: Date, endDate: Date) async throws -> UsageStats {
        let allStats = try await getUsageStats()
        return Filter.byDateRange(allStats, start: startDate, end: endDate)
    }

    /// Get session-level statistics with optional filtering and sorting
    public func getSessionStats(
        since: Date? = nil,
        until: Date? = nil,
        order: SortOrder? = nil
    ) async throws -> [ProjectUsage] {
        try await getUsageStats().byProject
            |> { Filter.byDateRange($0, since: since, until: until) }
            |> { Sort.byCost($0, order: order) }
    }

    /// Load entries for a specific date
    public func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        return try await getUsageEntries().filter { entry in
            entry.date.map { calendar.startOfDay(for: $0) == targetDay } ?? false
        }
    }

    // MARK: - File Discovery

    private func discoverFiles(in projectsPath: String) throws -> [FileMetadata] {
        let todayStart = Calendar.current.startOfDay(for: Date())

        return try FileManager.default.contentsOfDirectory(atPath: projectsPath)
            .filter { !DirectoryFilter.shouldSkip($0) }
            .flatMap { projectDir in
                jsonlFiles(in: projectsPath + "/" + projectDir, projectDir: projectDir, todayStart: todayStart)
            }
            .sorted { $0.earliestTimestamp < $1.earliestTimestamp }
    }

    private func jsonlFiles(in projectPath: String, projectDir: String, todayStart: Date) -> [FileMetadata] {
        (try? FileManager.default.contentsOfDirectory(atPath: projectPath))
            .map { files in
                files
                    .filter { $0.hasSuffix(".jsonl") }
                    .compactMap { file -> FileMetadata? in
                        let filePath = projectPath + "/" + file

                        // Fast path: use cached metadata for old files (immutable)
                        if let cached = fileCache[filePath] {
                            let isOldFile = cached.modificationDate < todayStart
                            if isOldFile {
                                // Old files are immutable - skip filesystem read
                                return FileMetadata(
                                    path: filePath,
                                    projectDir: projectDir,
                                    earliestTimestamp: ISO8601DateFormatter().string(from: cached.modificationDate),
                                    modificationDate: cached.modificationDate
                                )
                            }
                        }

                        // Slow path: read fresh attributes for new or today's files
                        guard let (timestamp, modDate) = FileTimestamp.extract(from: filePath) else {
                            return nil
                        }
                        return FileMetadata(
                            path: filePath,
                            projectDir: projectDir,
                            earliestTimestamp: timestamp,
                            modificationDate: modDate
                        )
                    }
            } ?? []
    }

    private func filterFilesModifiedToday(_ files: [FileMetadata]) -> [FileMetadata] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        return files.filter { file in
            formatter.date(from: file.earliestTimestamp).map { $0 >= todayStart } ?? false
        }
    }

    // MARK: - Entry Loading

    private func loadEntries(from files: [FileMetadata]) async -> [UsageEntry] {
        // Partition files into cached (unchanged) and dirty (new or modified)
        var cachedEntries: [UsageEntry] = []
        var dirtyFiles: [FileMetadata] = []

        for file in files {
            if let cached = fileCache[file.path],
               cached.modificationDate == file.modificationDate {
                // File unchanged - use cached entries
                cachedEntries.append(contentsOf: cached.entries)
            } else {
                // File is new or modified - needs parsing
                dirtyFiles.append(file)
            }
        }

        // Only parse dirty files
        let newEntries: [UsageEntry]
        if dirtyFiles.count > Threshold.batchProcessing {
            newEntries = await loadEntriesInBatches(from: dirtyFiles, deduplication: globalDeduplication)
        } else if dirtyFiles.count > Threshold.parallelProcessing {
            newEntries = await loadEntriesInParallel(from: dirtyFiles, deduplication: globalDeduplication)
        } else {
            newEntries = loadEntriesSequentially(from: dirtyFiles, deduplication: globalDeduplication)
        }

        logger.debug("Cache: \(files.count - dirtyFiles.count) cached, \(dirtyFiles.count) loaded")

        return cachedEntries + newEntries
    }

    private func loadEntriesSequentially(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) -> [UsageEntry] {
        files.flatMap { parseFile($0, deduplication: deduplication) }
    }

    private func loadEntriesInParallel(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        await withTaskGroup(of: [UsageEntry].self) { group in
            for file in files {
                group.addTask { await self.parseFile(file, deduplication: deduplication) }
            }
            return await group.reduce(into: []) { $0.append(contentsOf: $1) }
        }
    }

    private func loadEntriesInBatches(
        from files: [FileMetadata],
        deduplication: Deduplication
    ) async -> [UsageEntry] {
        await stride(from: 0, to: files.count, by: Threshold.batchSize)
            .asyncFlatMap { startIndex in
                let endIndex = min(startIndex + Threshold.batchSize, files.count)
                let batch = Array(files[startIndex..<endIndex])
                return await self.loadEntriesInParallel(from: batch, deduplication: deduplication)
            }
    }

    // MARK: - File Parsing

    private func parseFile(_ file: FileMetadata, deduplication: Deduplication) -> [UsageEntry] {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: file.path)) else {
            return []
        }

        let projectPath = PathDecoder.decode(file.projectDir)
        let entries = LineScanner.extractRanges(from: fileData)
            .compactMap { range -> UsageEntry? in
                let lineData = fileData[range]
                guard JSONValidator.isValidObject(lineData),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      deduplication.shouldInclude(json: json) else {
                    return nil
                }
                return EntryParser.parse(json, projectPath: projectPath)
            }

        // Cache parsed entries for future use
        fileCache[file.path] = CachedFile(
            modificationDate: file.modificationDate,
            entries: entries
        )

        return entries
    }

    // MARK: - Session Counting

    private func countSessions(in files: [FileMetadata]) -> Int {
        Set(
            files.compactMap { file in
                let filename = URL(fileURLWithPath: file.path).lastPathComponent
                return filename.hasSuffix(".jsonl") ? String(filename.dropLast(6)) : nil
            }
        ).count
    }
}

// MARK: - Pure Transformations

private enum DirectoryFilter {
    static func shouldSkip(_ name: String) -> Bool {
        name.hasPrefix("-private-var-folders-") ||
        name.hasPrefix(".")
    }
}

private enum PathDecoder {
    static func decode(_ encodedPath: String) -> String {
        if encodedPath.hasPrefix("-") {
            return "/" + String(encodedPath.dropFirst()).replacingOccurrences(of: "-", with: "/")
        }
        return encodedPath.replacingOccurrences(of: "-", with: "/")
    }
}

private enum FileTimestamp {
    /// Extract both timestamp string and modification date from file
    static func extract(from path: String) -> (timestamp: String, modificationDate: Date)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return (ISO8601DateFormatter().string(from: modDate), modDate)
    }
}

private enum JSONValidator {
    static func isValidObject(_ data: Data) -> Bool {
        data.count > 2 &&
        data.first == ByteValue.openBrace &&
        data.last == ByteValue.closeBrace
    }
}

private enum LineScanner {
    static func extractRanges(from data: Data) -> [Range<Data.Index>] {
        guard data.count > 0 else { return [] }

        return [UInt8](data).withUnsafeBufferPointer { buffer in
            guard let ptr = buffer.baseAddress else { return [] }
            var ranges: [Range<Int>] = []
            var offset = 0

            while offset < data.count {
                let remaining = data.count - offset
                let lineEnd = memchr(ptr + offset, ByteValue.newline, remaining)
                    .map { UnsafePointer($0.assumingMemoryBound(to: UInt8.self)) - ptr }
                    ?? data.count

                if lineEnd > offset {
                    ranges.append(offset..<lineEnd)
                }
                offset = lineEnd + 1
            }
            return ranges
        }
    }
}

private enum EntryParser {
    static func parse(_ json: [String: Any], projectPath: String) -> UsageEntry? {
        guard let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return nil
        }

        let tokens = extractTokens(from: usage)
        guard tokens.hasUsage else { return nil }

        let model = message["model"] as? String ?? "unknown"
        let cost = calculateCost(json: json, model: model, tokens: tokens)

        return UsageEntry(
            project: projectPath,
            timestamp: json["timestamp"] as? String ?? "",
            model: model,
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheWriteTokens: tokens.cacheWrite,
            cacheReadTokens: tokens.cacheRead,
            cost: cost,
            sessionId: json["sessionId"] as? String
        )
    }

    private static func extractTokens(from usage: [String: Any]) -> TokenCounts {
        TokenCounts(
            input: usage["input_tokens"] as? Int ?? 0,
            output: usage["output_tokens"] as? Int ?? 0,
            cacheWrite: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheRead: usage["cache_read_input_tokens"] as? Int ?? 0
        )
    }

    private static func calculateCost(json: [String: Any], model: String, tokens: TokenCounts) -> Double {
        if let cost = json["costUSD"] as? Double, cost > 0 {
            return cost
        }
        return ModelPricing.pricing(for: model)?.calculateCost(
            inputTokens: tokens.input,
            outputTokens: tokens.output,
            cacheWriteTokens: tokens.cacheWrite,
            cacheReadTokens: tokens.cacheRead
        ) ?? 0.0
    }

    private struct TokenCounts {
        let input: Int
        let output: Int
        let cacheWrite: Int
        let cacheRead: Int

        var hasUsage: Bool {
            input > 0 || output > 0 || cacheWrite > 0 || cacheRead > 0
        }
    }
}

// MARK: - Aggregation

private enum Aggregator {
    static func aggregate(_ entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormat.dayString

        let result = entries.reduce(into: AggregationState()) { state, entry in
            state.addEntry(entry, dateFormatter: dateFormatter)
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
            byDate: result.dailyStats.values.sorted { $0.date < $1.date },
            byProject: Array(result.projectStats.values)
        )
    }

    private struct AggregationState {
        var totalCost: Double = 0
        var totalInputTokens: Int = 0
        var totalOutputTokens: Int = 0
        var totalCacheWriteTokens: Int = 0
        var totalCacheReadTokens: Int = 0
        var modelStats: [String: ModelUsage] = [:]
        var dailyStats: [String: DailyUsage] = [:]
        var projectStats: [String: ProjectUsage] = [:]

        var totalTokens: Int {
            totalInputTokens + totalOutputTokens + totalCacheWriteTokens + totalCacheReadTokens
        }

        mutating func addEntry(_ entry: UsageEntry, dateFormatter: DateFormatter) {
            totalCost += entry.cost
            totalInputTokens += entry.inputTokens
            totalOutputTokens += entry.outputTokens
            totalCacheWriteTokens += entry.cacheWriteTokens
            totalCacheReadTokens += entry.cacheReadTokens

            updateModelStats(entry)
            updateDailyStats(entry, dateFormatter: dateFormatter)
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

        private mutating func updateDailyStats(_ entry: UsageEntry, dateFormatter: DateFormatter) {
            guard let date = entry.date else { return }
            let dateString = dateFormatter.string(from: date)
            let existing = dailyStats[dateString]

            dailyStats[dateString] = DailyUsage(
                date: dateString,
                totalCost: (existing?.totalCost ?? 0) + entry.cost,
                totalTokens: (existing?.totalTokens ?? 0) + entry.totalTokens,
                modelsUsed: Array(Set((existing?.modelsUsed ?? []) + [entry.model]))
            )
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
    }
}

// MARK: - Filtering

private enum Filter {
    static func byDateRange(_ stats: UsageStats, start: Date, end: Date) -> UsageStats {
        guard start.timeIntervalSince1970 >= 0 else { return stats }

        let formatter = DateFormatter()
        formatter.dateFormat = DateFormat.dayString
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

private enum Sort {
    static func byCost(_ projects: [ProjectUsage], order: SortOrder?) -> [ProjectUsage] {
        guard let order = order else { return projects }
        return projects.sorted { a, b in
            order == .ascending ? a.totalCost < b.totalCost : a.totalCost > b.totalCost
        }
    }
}

// MARK: - Deduplication

private final class Deduplication: @unchecked Sendable {
    private var processedHashes: Set<String> = []
    private let queue = DispatchQueue(label: "com.claudeusage.deduplication", attributes: .concurrent)

    func shouldInclude(json: [String: Any]) -> Bool {
        guard let message = json["message"] as? [String: Any],
              let messageId = message["id"] as? String,
              let requestId = json["requestId"] as? String else {
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

// MARK: - Extensions

private extension UsageStats {
    static let empty = UsageStats(
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

// MARK: - Async Helpers

private extension StrideTo where Element == Int {
    func asyncFlatMap<T>(_ transform: @escaping (Int) async -> [T]) async -> [T] {
        var results: [T] = []
        for element in self {
            results.append(contentsOf: await transform(element))
        }
        return results
    }
}

// MARK: - Pipe Operator

infix operator |>: AdditionPrecedence
private func |> <T, U>(value: T, transform: (T) -> U) -> U {
    transform(value)
}
