//
//  AsyncUsageRepository.swift
//  ClaudeCodeUsage
//
//  Modern async/await implementation with AsyncSequence for file processing
//

import Foundation

/// Async stream-based usage repository with sequential execution
/// Uses actor isolation for thread safety while ensuring methods execute sequentially
public actor AsyncUsageRepository: UsageRepositoryProtocol {
    private let basePath: String
    private let fileSystem: AsyncFileSystemProtocol
    private let pathDecoder: ProjectPathDecoderProtocol
    private let parser: UsageDataParserProtocol
    private let aggregator: StatisticsAggregatorProtocol
    private let maxConcurrency: Int
    internal let performanceMetrics: PerformanceMetricsProtocol?
    
    public init(
        basePath: String,
        fileSystem: AsyncFileSystemProtocol? = nil,
        pathDecoder: ProjectPathDecoderProtocol? = nil,
        parser: UsageDataParserProtocol? = nil,
        aggregator: StatisticsAggregatorProtocol? = nil,
        performanceMetrics: PerformanceMetricsProtocol? = nil,
        maxConcurrency: Int = ProcessInfo.processInfo.processorCount * 2
    ) {
        self.basePath = basePath
        self.fileSystem = fileSystem ?? AsyncFileSystem()
        self.pathDecoder = pathDecoder ?? ProjectPathDecoder()
        self.parser = parser ?? JSONLUsageParser()
        self.aggregator = aggregator ?? StatisticsAggregator()
        self.performanceMetrics = performanceMetrics
        self.maxConcurrency = maxConcurrency
    }
    
    // MARK: - Public API
    
    public func getUsageStats() async throws -> UsageStats {
        let startTime = Date()
        let files = try await discoverFiles()
        
        #if DEBUG
        print("[AsyncUsageRepository] Discovered \(files.count) files in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
        #endif
        
        if files.isEmpty {
            return createEmptyStats()
        }
        
        // Process files as async stream
        let processingStart = Date()
        let deduplication = HashBasedDeduplication()
        let entries = await processFilesAsStream(files, deduplication: deduplication)
        
        #if DEBUG
        print("[AsyncUsageRepository] Processed \(entries.count) entries in \(String(format: "%.3f", Date().timeIntervalSince(processingStart)))s")
        #endif
        
        // Aggregate statistics
        let aggregateStart = Date()
        let stats = aggregateStats(from: entries, sessionCount: countUniqueSessions(from: files))
        
        #if DEBUG
        let totalDuration = Date().timeIntervalSince(startTime)
        print("[AsyncUsageRepository] getUsageStats total: \(String(format: "%.3f", totalDuration))s (aggregate: \(String(format: "%.3f", Date().timeIntervalSince(aggregateStart)))s)")
        #endif
        
        return stats
    }
    
    public func loadEntriesForDate(_ date: Date) async throws -> [UsageEntry] {
        let allEntries = try await getUsageEntries()
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: targetDay)!
        
        return allEntries.filter { entry in
            guard let entryDate = entry.date else { return false }
            return entryDate >= targetDay && entryDate < nextDay
        }
    }
    
    public func getUsageEntries(limit: Int? = nil) async throws -> [UsageEntry] {
        let startTime = Date()
        let files = try await discoverFiles()
        
        #if DEBUG
        print("[AsyncUsageRepository] getUsageEntries: Discovered \(files.count) files in \(String(format: "%.3f", Date().timeIntervalSince(startTime)))s")
        #endif
        
        if files.isEmpty {
            return []
        }
        
        let processingStart = Date()
        let deduplication = HashBasedDeduplication()
        var entries: [UsageEntry] = []
        
        // Stream processing with optional limit
        for await entry in createFileProcessingStream(files, deduplication: deduplication) {
            entries.append(entry)
            if let limit = limit, entries.count >= limit {
                break
            }
        }
        
        #if DEBUG
        let totalDuration = Date().timeIntervalSince(startTime)
        print("[AsyncUsageRepository] getUsageEntries total: \(String(format: "%.3f", totalDuration))s - \(entries.count) entries (processing: \(String(format: "%.3f", Date().timeIntervalSince(processingStart)))s)")
        #endif
        
        return entries
    }
    
    // MARK: - AsyncSequence File Processing
    
    /// Create an async stream for processing files
    private func createFileProcessingStream(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: DeduplicationStrategy
    ) -> AsyncStream<UsageEntry> {
        AsyncStream { continuation in
            // Use structured concurrency with proper cancellation handling
            let task = Task {
                await withTaskCancellationHandler {
                    await withTaskGroup(of: [UsageEntry].self) { group in
                        var activeTaskCount = 0
                        var fileIterator = files.makeIterator()

                        // Process files with controlled concurrency
                        repeat {
                            // Check for cancellation
                            if Task.isCancelled { break }

                            if let file = fileIterator.next(), activeTaskCount < maxConcurrency {
                                group.addTask {
                                    await self.processJSONLFile(
                                        at: file.path,
                                        projectDir: file.projectDir,
                                        deduplication: deduplication
                                    )
                                }
                                activeTaskCount += 1
                            }

                            if let entries = await group.next() {
                                activeTaskCount -= 1
                                for entry in entries {
                                    continuation.yield(entry)
                                }
                            }
                        } while activeTaskCount > 0
                    }
                    continuation.finish()
                } onCancel: {
                    // Clean up on cancellation
                    continuation.finish()
                }
            }

            // Register termination handler to cancel task
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    /// Process files and return all entries
    private func processFilesAsStream(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: DeduplicationStrategy
    ) async -> [UsageEntry] {
        var allEntries: [UsageEntry] = []

        #if DEBUG
        print("[AsyncRepository] Processing \(files.count) files with maxConcurrency: \(maxConcurrency)")
        let streamStart = Date()
        #endif

        await withTaskGroup(of: [UsageEntry].self) { group in
            // Limit concurrent operations
            let batchSize = min(maxConcurrency, files.count)
            var fileIndex = 0

            #if DEBUG
            print("[AsyncRepository] Initial batch size: \(batchSize)")
            #endif

            // Start initial batch
            for _ in 0..<batchSize where fileIndex < files.count {
                let file = files[fileIndex]
                group.addTask {
                    await self.processJSONLFile(
                        at: file.path,
                        projectDir: file.projectDir,
                        deduplication: deduplication
                    )
                }
                fileIndex += 1
            }

            // Process results and add new tasks
            for await entries in group {
                allEntries.append(contentsOf: entries)

                // Add next file if available
                if fileIndex < files.count {
                    let file = files[fileIndex]
                    group.addTask {
                        await self.processJSONLFile(
                            at: file.path,
                            projectDir: file.projectDir,
                            deduplication: deduplication
                        )
                    }
                    fileIndex += 1
                }
            }
        }

        #if DEBUG
        let streamTime = Date().timeIntervalSince(streamStart)
        print("[AsyncRepository] Processed all files in \(String(format: "%.3f", streamTime))s - total entries: \(allEntries.count)")
        #endif

        return allEntries
    }
    
    /// Process a single JSONL file
    private func processJSONLFile(
        at path: String,
        projectDir: String,
        deduplication: DeduplicationStrategy
    ) async -> [UsageEntry] {
        #if DEBUG
        let fileStart = Date()
        #endif

        // Resilient file read: if file fails (e.g., being written to), skip it
        let content: String
        do {
            content = try await fileSystem.readFile(atPath: path)
        } catch {
            #if DEBUG
            print("[AsyncRepository] Skipping file \(path): \(error.localizedDescription)")
            #endif
            return []
        }
        
        #if DEBUG
        let readTime = Date().timeIntervalSince(fileStart)
        #endif
        
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = pathDecoder.decode(projectDir)
        
        #if DEBUG
        let parseStart = Date()
        #endif
        
        for line in lines {
            // Skip obviously incomplete lines (truncated during file write)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
                continue
            }

            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            // Check deduplication
            let messageId = parser.extractMessageId(from: json)
            let requestId = parser.extractRequestId(from: json)
            
            guard deduplication.shouldInclude(messageId: messageId, requestId: requestId) else {
                continue
            }
            
            // Parse entry using the parser
            if let entry = try? parser.parseJSONLLine(line, projectPath: decodedProjectPath) {
                entries.append(entry)
            }
        }
        
        #if DEBUG
        let parseTime = Date().timeIntervalSince(parseStart)
        let totalTime = Date().timeIntervalSince(fileStart)
        if totalTime > 0.1 {  // Only log slow files
            let fileName = URL(fileURLWithPath: path).lastPathComponent
            print("[AsyncRepository] Slow file: \(fileName) - read: \(String(format: "%.3f", readTime))s, parse: \(String(format: "%.3f", parseTime))s, lines: \(lines.count), entries: \(entries.count)")
        }
        #endif
        
        return entries
    }
    
    // MARK: - File Discovery
    
    private func discoverFiles() async throws -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        let projectsPath = "\(basePath)/projects"
        
        guard await fileSystem.fileExists(atPath: projectsPath) else {
            return []
        }
        
        let projectDirs = try await fileSystem.contentsOfDirectory(atPath: projectsPath)
        var files: [(path: String, projectDir: String, earliestTimestamp: String)] = []
        
        // Use TaskGroup for concurrent directory scanning
        try await withThrowingTaskGroup(of: [(path: String, projectDir: String, earliestTimestamp: String)].self) { group in
            for projectDir in projectDirs {
                // Skip non-Claude-Code directories (e.g., RPLY app sessions)
                if Self.shouldSkipDirectory(projectDir) {
                    continue
                }

                group.addTask {
                    let projectPath = "\(projectsPath)/\(projectDir)"
                    let projectFiles = try await self.fileSystem.contentsOfDirectory(atPath: projectPath)
                    
                    var result: [(path: String, projectDir: String, earliestTimestamp: String)] = []
                    for file in projectFiles where file.hasSuffix(".jsonl") {
                        let filePath = "\(projectPath)/\(file)"
                        if let timestamp = await self.getEarliestTimestamp(from: filePath) {
                            result.append((path: filePath, projectDir: projectDir, earliestTimestamp: timestamp))
                        }
                    }
                    return result
                }
            }
            
            for try await projectFiles in group {
                files.append(contentsOf: projectFiles)
            }
        }
        
        // Sort by timestamp
        return files.sorted { $0.earliestTimestamp < $1.earliestTimestamp }
    }
    
    private func getEarliestTimestamp(from path: String) async -> String? {
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
    
    // MARK: - Statistics Aggregation
    
    private func aggregateStats(from entries: [UsageEntry], sessionCount: Int) -> UsageStats {
        return aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)
    }
    
    private func countUniqueSessions(from files: [(path: String, projectDir: String, earliestTimestamp: String)]) -> Int {
        var sessionIds = Set<String>()
        
        for (filePath, _, _) in files {
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
    private static func shouldSkipDirectory(_ directoryName: String) -> Bool {
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
