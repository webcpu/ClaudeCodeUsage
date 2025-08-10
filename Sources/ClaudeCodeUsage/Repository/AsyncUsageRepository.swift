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
        let files = try await discoverFiles()
        
        if files.isEmpty {
            return createEmptyStats()
        }
        
        // Process files as async stream
        let deduplication = HashBasedDeduplication()
        let entries = try await processFilesAsStream(files, deduplication: deduplication)
        
        // Aggregate statistics
        return aggregateStats(from: entries, sessionCount: countUniqueSessions(from: files))
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
        let files = try await discoverFiles()
        
        if files.isEmpty {
            return []
        }
        
        let deduplication = HashBasedDeduplication()
        var entries: [UsageEntry] = []
        
        // Stream processing with optional limit
        for try await entry in createFileProcessingStream(files, deduplication: deduplication) {
            entries.append(entry)
            if let limit = limit, entries.count >= limit {
                break
            }
        }
        
        return entries
    }
    
    // MARK: - AsyncSequence File Processing
    
    /// Create an async stream for processing files
    private func createFileProcessingStream(
        _ files: [(path: String, projectDir: String, earliestTimestamp: String)],
        deduplication: DeduplicationStrategy
    ) -> AsyncThrowingStream<UsageEntry, Error> {
        AsyncThrowingStream { continuation in
            // Use structured concurrency with proper cancellation handling
            let task = Task {
                await withTaskCancellationHandler {
                    do {
                        try await withThrowingTaskGroup(of: [UsageEntry].self) { group in
                            var activeTaskCount = 0
                            var fileIterator = files.makeIterator()
                            
                            // Process files with controlled concurrency
                            repeat {
                                // Check for cancellation
                                try Task.checkCancellation()
                                
                                if let file = fileIterator.next(), activeTaskCount < maxConcurrency {
                                    group.addTask {
                                        try await self.processJSONLFile(
                                            at: file.path,
                                            projectDir: file.projectDir,
                                            deduplication: deduplication
                                        )
                                    }
                                    activeTaskCount += 1
                                }
                                
                                if let entries = try await group.next() {
                                    activeTaskCount -= 1
                                    for entry in entries {
                                        continuation.yield(entry)
                                    }
                                }
                            } while activeTaskCount > 0
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                } onCancel: {
                    // Clean up on cancellation
                    continuation.finish(throwing: CancellationError())
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
    ) async throws -> [UsageEntry] {
        var allEntries: [UsageEntry] = []
        
        try await withThrowingTaskGroup(of: [UsageEntry].self) { group in
            // Limit concurrent operations
            let batchSize = min(maxConcurrency, files.count)
            var fileIndex = 0
            
            // Start initial batch
            for _ in 0..<batchSize where fileIndex < files.count {
                let file = files[fileIndex]
                group.addTask {
                    try await self.processJSONLFile(
                        at: file.path,
                        projectDir: file.projectDir,
                        deduplication: deduplication
                    )
                }
                fileIndex += 1
            }
            
            // Process results and add new tasks
            for try await entries in group {
                allEntries.append(contentsOf: entries)
                
                // Add next file if available
                if fileIndex < files.count {
                    let file = files[fileIndex]
                    group.addTask {
                        try await self.processJSONLFile(
                            at: file.path,
                            projectDir: file.projectDir,
                            deduplication: deduplication
                        )
                    }
                    fileIndex += 1
                }
            }
        }
        
        return allEntries
    }
    
    /// Process a single JSONL file
    private func processJSONLFile(
        at path: String,
        projectDir: String,
        deduplication: DeduplicationStrategy
    ) async throws -> [UsageEntry] {
        let content = try await fileSystem.readFile(atPath: path)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = pathDecoder.decode(projectDir)
        
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            // Check deduplication - extract IDs directly from JSON
            let messageId = json["id"] as? String
            let requestId = json["requestId"] as? String
            
            guard deduplication.shouldInclude(messageId: messageId, requestId: requestId) else {
                continue
            }
            
            // Parse entry using the parser
            if let entry = try? parser.parseJSONLLine(line, projectPath: decodedProjectPath) {
                entries.append(entry)
            }
        }
        
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
        guard let content = try? await fileSystem.readFile(atPath: path) else {
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        var earliestTimestamp: String?
        
        for line in lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestamp = json["timestamp"] as? String else {
                continue
            }
            
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
