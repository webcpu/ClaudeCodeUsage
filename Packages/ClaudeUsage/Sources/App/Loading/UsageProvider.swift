//
//  UsageProvider.swift
//  Provides usage data from .jsonl files
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "UsageProvider")

// MARK: - UsageProvider

public actor UsageProvider: UsageProviding {

    // MARK: - Properties

    public let basePath: String

    private let parser = JSONLParser()
    private var fileCache: [String: CachedFile] = [:]

    // MARK: - Initialization

    public init(basePath: String = NSHomeDirectory() + "/.claude") {
        self.basePath = basePath
    }

    // MARK: - UsageProviding

    public func getTodayEntries() async throws -> [UsageEntry] {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filter(allFiles, by: FileFilters.modifiedToday())

        logger.debug("Files: \(todayFiles.count) today / \(allFiles.count) total")

        let entries = await loadEntries(from: todayFiles)
        return UsageAggregator.filterToday(entries)
    }

    public func getUsageStats() async throws -> UsageStats {
        let entries = try await getAllEntries()
        return UsageAggregator.aggregate(entries)
    }

    public func getAllEntries() async throws -> [UsageEntry] {
        let files = try FileDiscovery.discoverFiles(in: basePath)
        return await loadEntries(from: files)
    }

    // MARK: - Cache Management

    public func clearCache() {
        fileCache.removeAll()
    }

    // MARK: - Entry Loading

    private func loadEntries(from files: [FileMetadata]) async -> [UsageEntry] {
        files
            .flatMap(loadEntriesFromFile)
            .sorted()
    }

    private func loadEntriesFromFile(_ file: FileMetadata) -> [UsageEntry] {
        if let cachedEntries = validCachedEntries(for: file) {
            return cachedEntries
        }
        return parseAndCacheEntries(from: file)
    }

    // MARK: - Caching

    private func validCachedEntries(for file: FileMetadata) -> [UsageEntry]? {
        guard let cached = fileCache[file.path],
              cached.modificationDate >= file.modificationDate,
              cached.version == CachedFile.currentVersion else {
            return nil
        }
        return cached.entries
    }

    private func parseAndCacheEntries(from file: FileMetadata) -> [UsageEntry] {
        let entries = parseEntries(from: file)
        cacheEntries(entries, for: file)
        return entries
    }

    // MARK: - Parsing

    private func parseEntries(from file: FileMetadata) -> [UsageEntry] {
        var fileHashes = Set<String>()
        return parser.parseFile(
            at: file.path,
            project: file.projectName,
            processedHashes: &fileHashes
        )
    }

    private func cacheEntries(_ entries: [UsageEntry], for file: FileMetadata) {
        fileCache[file.path] = CachedFile(
            modificationDate: file.modificationDate,
            entries: entries,
            version: CachedFile.currentVersion
        )
    }
}
