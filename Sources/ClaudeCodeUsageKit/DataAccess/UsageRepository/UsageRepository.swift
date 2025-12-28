//
//  UsageRepository.swift
//  ClaudeCodeUsage
//
//  Repository for accessing and processing Claude Code usage data.
//  Architecture: FP + SLAP (Functional Programming + Single Level of Abstraction Principle)
//
//  Split into extensions for focused responsibilities:
//    - +FileDiscovery: File discovery and metadata
//    - +Parsing: Entry parsing and transformation
//    - +Aggregation: Stats aggregation, filtering, sorting
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Repository")

// MARK: - Repository

/// Repository for accessing and processing usage data.
/// Uses actor isolation for thread safety.
/// Implements file-level caching based on modification time for optimal performance.
public actor UsageRepository {
    public let basePath: String

    /// Cache of parsed entries by file path, keyed on modification date
    var fileCache: [String: CachedFile] = [:]

    /// Persistent deduplication state across loads
    var globalDeduplication = Deduplication()

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

        logger.debug("Entries: \(entries.count) from \(files.count) files")

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

        logger.debug("Files: \(todayFiles.count) today / \(allFiles.count) total")

        let entries = await loadEntriesWithFreshDeduplication(from: todayFiles)
        return filterEntriesToday(entries)
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

    // MARK: - Internal Helpers

    func loadEntriesWithFreshDeduplication(from files: [FileMetadata]) async -> [UsageEntry] {
        await loadEntriesForToday(from: files)
    }

    func filterEntriesToday(_ entries: [UsageEntry]) -> [UsageEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return entries.filter { entry in
            entry.date.map { calendar.isDate($0, inSameDayAs: today) } ?? false
        }
    }

    func loadEntriesForToday(from files: [FileMetadata]) async -> [UsageEntry] {
        let (cachedFiles, dirtyFiles) = partitionByCache(files)
        let cachedEntries = cachedFiles.flatMap { fileCache[$0.path]?.entries ?? [] }
        let freshDeduplication = Deduplication()
        let newEntries = await loadNewEntries(from: dirtyFiles, deduplication: freshDeduplication)
        return cachedEntries + newEntries
    }
}

// MARK: - Extensions

extension UsageStats {
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

extension Array where Element: Sendable {
    func asyncFlatMap<T: Sendable>(_ transform: @escaping @Sendable (Element) async -> [T]) async -> [T] {
        var results: [T] = []
        for element in self {
            results.append(contentsOf: await transform(element))
        }
        return results
    }
}

// MARK: - Pipe Operator

infix operator |>: AdditionPrecedence
func |> <T, U>(value: T, transform: (T) -> U) -> U {
    transform(value)
}

// MARK: - Constants

enum RepositoryThreshold {
    static let parallelProcessing = 5
    static let batchProcessing = 500
    static let batchSize = 100
}

enum ByteValue {
    static let openBrace: UInt8 = 0x7B   // '{'
    static let closeBrace: UInt8 = 0x7D  // '}'
    static let newline: Int32 = 0x0A     // '\n'
}

enum RepositoryDateFormat {
    static let dayString = "yyyy-MM-dd"
}

// MARK: - Supporting Types

/// Sort order for queries
public enum SortOrder: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

struct FileMetadata: Sendable {
    let path: String
    let projectDir: String
    let earliestTimestamp: String
    let modificationDate: Date
}

struct CachedFile {
    let modificationDate: Date
    let entries: [UsageEntry]
    let version: Int
}

/// Cache version tracking - increment when pricing or parsing logic changes
enum CacheVersion {
    /// Current cache version - bump this when pricing or cost calculation changes
    /// v2: Fixed Haiku 4.5 pricing ($1/$5 instead of $0.80/$4)
    static let current = 2
}
