//
//  UsageRepository.swift
//  ClaudeCodeUsage
//
//  Repository for accessing usage data (Repository Pattern + Dependency Injection)
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Repository")

/// Repository for accessing and processing usage data
/// Uses actor isolation for thread safety and proper async/await patterns
public actor UsageRepository {
    private let fileSystem: FileSystemProtocol
    private let parser: UsageDataParserProtocol
    private let pathDecoder: ProjectPathDecoderProtocol
    private let aggregator: StatisticsAggregatorProtocol
    public let basePath: String
    
    /// Initialize with all dependencies injected
    public init(
        fileSystem: FileSystemProtocol,
        parser: UsageDataParserProtocol,
        pathDecoder: ProjectPathDecoderProtocol,
        aggregator: StatisticsAggregatorProtocol,
        basePath: String
    ) {
        self.fileSystem = fileSystem
        self.parser = parser
        self.pathDecoder = pathDecoder
        self.aggregator = aggregator
        self.basePath = basePath
    }
    
    /// Convenience initializer with default implementations
    public init(basePath: String = NSHomeDirectory() + "/.claude") {
        self.init(
            fileSystem: FileSystemService(),
            parser: JSONLUsageParser(),
            pathDecoder: ProjectPathDecoder(),
            aggregator: StatisticsAggregator(),
            basePath: basePath
        )
    }
    
    /// Get usage statistics
    public func getUsageStats() async throws -> UsageStats {
        let projectsPath = basePath + "/projects"
        
        // Check if projects directory exists
        guard fileSystem.fileExists(atPath: projectsPath) else {
            return createEmptyStats()
        }
        
        // Create a fresh deduplication instance for this operation
        let deduplication = HashBasedDeduplication()
        
        // Collect and process all JSONL files
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        
        // Process files in parallel (batch only for very large datasets to manage memory)
        let entries: [UsageEntry]
        if sortedFiles.count > 500 {
            // Only batch for extremely large datasets
            entries = await processFilesInBatches(sortedFiles, batchSize: 100, deduplication: deduplication)
        } else {
            // Direct parallel processing for typical usage
            entries = await processFiles(sortedFiles, deduplication: deduplication)
        }
        
        #if DEBUG
        print("[UsageRepository] Loaded \(entries.count) entries from \(sortedFiles.count) files")
        let todayEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            return Calendar.current.isDateInToday(date)
        }
        let todayCost = todayEntries.reduce(0) { $0 + $1.cost }
        print("[UsageRepository] Today's entries: \(todayEntries.count), total cost: $\(todayCost)")
        #endif
        
        // Calculate session count
        let sessionCount = countUniqueSessions(from: sortedFiles)
        
        // Aggregate statistics
        return aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)
    }
    
    /// Get detailed usage entries
    public func getUsageEntries(limit: Int? = nil) async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"
        
        guard fileSystem.fileExists(atPath: projectsPath) else {
            return []
        }
        
        // Create a fresh deduplication instance for this operation
        let deduplication = HashBasedDeduplication()
        
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        var entries = await processFiles(sortedFiles, deduplication: deduplication)
        
        // Sort by timestamp (newest first)
        entries.sort { $0.timestamp > $1.timestamp }
        
        if let limit = limit {
            return Array(entries.prefix(limit))
        }
        return entries
    }

    /// Get today's usage entries only - much faster than loading all entries
    /// Filters files by modification date before processing
    public func getTodayUsageEntries() async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"

        guard fileSystem.fileExists(atPath: projectsPath) else {
            return []
        }

        let deduplication = HashBasedDeduplication()
        let allFiles = try collectJSONLFiles(from: projectsPath)

        // Filter to only files modified today (use file mod date as proxy)
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()  // Reuse single formatter
        let todayFiles = allFiles.filter { file in
            if let date = formatter.date(from: file.earliestTimestamp) {
                return date >= todayStart
            }
            return false
        }

        #if DEBUG
        print("[UsageRepository] Today's files: \(todayFiles.count) of \(allFiles.count) total")
        #endif

        let entries = await processFiles(todayFiles, deduplication: deduplication)
        return entries
    }

    /// Get today's stats only - fast path for initial load
    public func getTodayUsageStats() async throws -> UsageStats {
        let entries = try await getTodayUsageEntries()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        return aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)
    }

    // MARK: - Private Methods
    
    private func collectJSONLFiles(from projectsPath: String) throws -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        var filesToProcess: [(path: String, projectDir: String, earliestTimestamp: String)] = []

        let projectDirs = try fileSystem.contentsOfDirectory(atPath: projectsPath)

        for projectDir in projectDirs {
            // Skip non-Claude-Code directories (e.g., RPLY app sessions from temp folders)
            if shouldSkipDirectory(projectDir) {
                continue
            }

            let projectPath = projectsPath + "/" + projectDir
            
            let files: [String]
            do {
                files = try fileSystem.contentsOfDirectory(atPath: projectPath)
            } catch {
                logger.warning("Failed to read directory \(projectPath): \(error.localizedDescription)")
                continue
            }
            
            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            
            for file in jsonlFiles {
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
    
    private func sortFilesByTimestamp(_ files: [(path: String, projectDir: String, earliestTimestamp: String)]) -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        return files.sorted { $0.earliestTimestamp < $1.earliestTimestamp }
    }
    
    private func processFiles(_ files: [(path: String, projectDir: String, earliestTimestamp: String)], deduplication: DeduplicationStrategy) async -> [UsageEntry] {
        // Use parallel processing for better performance with large datasets
        if files.count > 5 {
            return await processFilesInParallel(files, deduplication: deduplication)
        } else {
            return processFilesSequentially(files, deduplication: deduplication)
        }
    }
    
    private func processFilesSequentially(_ files: [(path: String, projectDir: String, earliestTimestamp: String)], deduplication: DeduplicationStrategy) -> [UsageEntry] {
        var allEntries: [UsageEntry] = []

        for (filePath, projectDir, _) in files {
            let entries = processJSONLFile(at: filePath, projectDir: projectDir, deduplication: deduplication)
            allEntries.append(contentsOf: entries)
        }

        return allEntries
    }
    
    private func processFilesInParallel(_ files: [(path: String, projectDir: String, earliestTimestamp: String)], deduplication: DeduplicationStrategy) async -> [UsageEntry] {
        // Use structured concurrency for thread-safe parallel processing
        return await withTaskGroup(of: [UsageEntry].self) { group in
            for (filePath, projectDir, _) in files {
                group.addTask {
                    await self.processJSONLFile(
                        at: filePath,
                        projectDir: projectDir,
                        deduplication: deduplication
                    )
                }
            }

            var allEntries: [UsageEntry] = []
            for await entries in group {
                allEntries.append(contentsOf: entries)
            }
            return allEntries
        }
    }
    
    
    /// Process files in batches to manage memory for very large datasets
    private func processFilesInBatches(_ files: [(path: String, projectDir: String, earliestTimestamp: String)], batchSize: Int, deduplication: DeduplicationStrategy) async -> [UsageEntry] {
        var allEntries: [UsageEntry] = []
        let totalBatches = (files.count + batchSize - 1) / batchSize

        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, files.count)
            let batch = Array(files[startIndex..<endIndex])

            // Process batch in parallel
            let batchEntries = await processFilesInParallel(batch, deduplication: deduplication)
            allEntries.append(contentsOf: batchEntries)
        }

        return allEntries
    }
    
    private func processJSONLFile(at path: String, projectDir: String, deduplication: DeduplicationStrategy) -> [UsageEntry] {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return []
        }

        let decodedProjectPath = pathDecoder.decode(projectDir)
        var entries: [UsageEntry] = []

        // Extract line ranges using memchr for SIMD-optimized scanning
        let lineRanges = extractLineRanges(from: fileData)

        for range in lineRanges {
            let lineData = fileData[range]

            // Quick validation: must be JSON object
            guard lineData.count > 2,
                  lineData.first == 0x7B,  // '{'
                  lineData.last == 0x7D    // '}'
            else { continue }

            guard let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let messageId = parser.extractMessageId(from: json)
            let requestId = parser.extractRequestId(from: json)

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

        // Convert to [UInt8] to use Array's cleaner withUnsafeBufferPointer
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

    /// Create UsageEntry from pre-parsed JSON - avoids double parsing
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

        // Skip entries without meaningful token usage
        if inputTokens == 0 && outputTokens == 0 && cacheWriteTokens == 0 && cacheReadTokens == 0 {
            return nil
        }

        // Calculate cost if not provided
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

        let timestamp = json["timestamp"] as? String ?? ""

        return UsageEntry(
            project: projectPath,
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheWriteTokens: cacheWriteTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: json["sessionId"] as? String
        )
    }
    
    private func getEarliestTimestamp(from path: String) -> String? {
        // Use file modification date for fast sorting - no file content reading needed
        // This is much faster than reading file contents and still provides good ordering
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path),
           let modDate = attributes[.modificationDate] as? Date {
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: modDate)
        }
        // Default to current time for mock/test paths - ensures files are still processed
        return ISO8601DateFormatter().string(from: Date())
    }
    
    private func countUniqueSessions(from files: [(path: String, projectDir: String, earliestTimestamp: String)]) -> Int {
        var sessionIds = Set<String>()
        
        for (filePath, _, _) in files {
            // Extract session ID from filename (remove .jsonl extension)
            let filename = URL(fileURLWithPath: filePath).lastPathComponent
            if filename.hasSuffix(".jsonl") {
                let sessionId = String(filename.dropLast(6))
                sessionIds.insert(sessionId)
            }
        }
        
        return sessionIds.count
    }

    /// Check if a directory should be skipped (non-Claude-Code data)
    /// Filters out RPLY app sessions and other non-usage directories
    private func shouldSkipDirectory(_ directoryName: String) -> Bool {
        // Skip temp folder sessions (RPLY app stores sessions in /private/var/folders/...)
        if directoryName.hasPrefix("-private-var-folders-") {
            return true
        }

        // Skip directories containing claude-kit-sessions (RPLY app session marker)
        if directoryName.contains("claude-kit-sessions") {
            return true
        }

        // Skip hidden directories
        if directoryName.hasPrefix(".") {
            return true
        }

        return false
    }

    private func createEmptyStats() -> UsageStats {
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
}
