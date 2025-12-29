//
//  UsageRepositoryImpl.swift
//  ClaudeUsageData
//
//  Implementation of UsageRepository protocol
//

import Foundation
import ClaudeUsageCore
import OSLog

private let logger = Logger(subsystem: "com.claudeusage", category: "Repository")

// MARK: - UsageRepositoryImpl

public actor UsageRepositoryImpl: UsageRepository {
    public let basePath: String

    private let parser = JSONLParser()
    private var fileCache: [String: CachedFile] = [:]
    private var processedHashes = Set<String>()

    public init(basePath: String = NSHomeDirectory() + "/.claude") {
        self.basePath = basePath
    }

    // MARK: - UsageRepository Protocol

    public func getTodayEntries() async throws -> [UsageEntry] {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filterFilesModifiedToday(allFiles)

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

    // MARK: - Additional Methods

    public func clearCache() {
        fileCache.removeAll()
        processedHashes.removeAll()
    }

    // MARK: - Private Loading

    private func loadEntries(from files: [FileMetadata]) async -> [UsageEntry] {
        var allEntries: [UsageEntry] = []

        for file in files {
            let entries = loadEntriesFromFile(file)
            allEntries.append(contentsOf: entries)
        }

        return allEntries.sorted()
    }

    private func loadEntriesFromFile(_ file: FileMetadata) -> [UsageEntry] {
        // Check cache
        if let cached = fileCache[file.path],
           cached.modificationDate >= file.modificationDate,
           cached.version == CachedFile.currentVersion {
            return cached.entries
        }

        // Parse file
        var localHashes = processedHashes
        let entries = parser.parseFile(
            at: file.path,
            project: file.projectName,
            processedHashes: &localHashes
        )
        processedHashes = localHashes

        // Cache results
        fileCache[file.path] = CachedFile(
            modificationDate: file.modificationDate,
            entries: entries,
            version: CachedFile.currentVersion
        )

        return entries
    }
}
