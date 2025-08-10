//
//  ResilientUsageRepository.swift
//  ClaudeCodeUsage
//
//  Resilient repository with circuit breaker and retry capabilities
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "ResilientRepository")

/// Async repository with built-in resilience features
public actor ResilientUsageRepository {
    private let fileSystem: AsyncFileSystemProtocol
    private let parser: UsageDataParserProtocol
    private let pathDecoder: ProjectPathDecoderProtocol
    private let aggregator: StatisticsAggregatorProtocol
    private let deduplication: DeduplicationStrategy
    private let circuitBreaker: CircuitBreaker
    public let basePath: String
    
    /// Initialize with resilience configuration
    public init(
        basePath: String = NSHomeDirectory() + "/.claude",
        circuitBreakerConfig: CircuitBreakerConfiguration = .default
    ) {
        let baseFileSystem = AsyncFileSystemAdapter(FileSystemService())
        self.fileSystem = AsyncCircuitBreakerFileSystem(
            fileSystem: baseFileSystem,
            configuration: circuitBreakerConfig
        )
        self.parser = JSONLUsageParser()
        self.pathDecoder = ProjectPathDecoder()
        self.aggregator = StatisticsAggregator()
        self.deduplication = HashBasedDeduplication()
        self.circuitBreaker = CircuitBreaker(configuration: circuitBreakerConfig)
        self.basePath = basePath
    }
    
    /// Get usage statistics with resilience
    public func getUsageStats() async throws -> UsageStats {
        try await circuitBreaker.execute {
            try await self.loadUsageStatsInternal()
        }
    }
    
    /// Get usage entries with resilience
    public func getUsageEntries(limit: Int? = nil) async throws -> [UsageEntry] {
        try await circuitBreaker.execute {
            try await self.loadUsageEntriesInternal(limit: limit)
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadUsageStatsInternal() async throws -> UsageStats {
        let projectsPath = basePath + "/projects"
        
        // Check if projects directory exists
        guard await fileSystem.fileExists(atPath: projectsPath) else {
            logger.info("Projects directory not found at \(projectsPath)")
            return createEmptyStats()
        }
        
        // Reset deduplication for fresh operation
        deduplication.reset()
        
        // Collect and process all JSONL files
        let filesToProcess = try await collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        
        logger.info("Processing \(sortedFiles.count) files for statistics")
        
        // Process files concurrently
        let entries = try await processFilesConcurrently(sortedFiles)
        
        logger.info("Loaded \(entries.count) entries from \(sortedFiles.count) files")
        
        // Calculate session count
        let sessionCount = countUniqueSessions(from: sortedFiles)
        
        // Aggregate statistics
        return aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)
    }
    
    private func loadUsageEntriesInternal(limit: Int?) async throws -> [UsageEntry] {
        let projectsPath = basePath + "/projects"
        
        guard await fileSystem.fileExists(atPath: projectsPath) else {
            logger.info("Projects directory not found at \(projectsPath)")
            return []
        }
        
        // Reset deduplication for fresh operation
        deduplication.reset()
        
        let filesToProcess = try await collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        var entries = try await processFilesConcurrently(sortedFiles)
        
        // Sort by timestamp (newest first)
        entries.sort { $0.timestamp > $1.timestamp }
        
        if let limit = limit {
            return Array(entries.prefix(limit))
        }
        return entries
    }
    
    private func collectJSONLFiles(from projectsPath: String) async throws -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        var filesToProcess: [(path: String, projectDir: String, earliestTimestamp: String)] = []
        
        let projectDirs = try await fileSystem.contentsOfDirectory(atPath: projectsPath)
        
        for projectDir in projectDirs {
            let projectPath = projectsPath + "/" + projectDir
            
            let files: [String]
            do {
                files = try await fileSystem.contentsOfDirectory(atPath: projectPath)
            } catch {
                logger.warning("Failed to read directory \(projectPath): \(error.localizedDescription)")
                continue
            }
            
            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            
            for file in jsonlFiles {
                let filePath = projectPath + "/" + file
                
                if let earliestTimestamp = await getEarliestTimestamp(from: filePath) {
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
    
    private func processFilesConcurrently(_ files: [(path: String, projectDir: String, earliestTimestamp: String)]) async throws -> [UsageEntry] {
        try await withThrowingTaskGroup(of: [UsageEntry].self) { group in
            for (filePath, projectDir, _) in files {
                group.addTask {
                    try await self.processJSONLFile(
                        at: filePath,
                        projectDir: projectDir
                    )
                }
            }
            
            var allEntries: [UsageEntry] = []
            for try await entries in group {
                allEntries.append(contentsOf: entries)
            }
            return allEntries
        }
    }
    
    private func processJSONLFile(at path: String, projectDir: String) async throws -> [UsageEntry] {
        let content = try await fileSystem.readFile(atPath: path)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = pathDecoder.decode(projectDir)
        
        for line in lines {
            guard let data = line.data(using: .utf8) else {
                logger.debug("Failed to convert line to data in file: \(path)")
                continue
            }
            
            let json: [String: Any]
            do {
                guard let parsedJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    logger.debug("Invalid JSON format in file: \(path)")
                    continue
                }
                json = parsedJson
            } catch {
                logger.debug("Failed to parse JSON in file \(path): \(error.localizedDescription)")
                continue
            }
            
            // Check deduplication
            let messageId = parser.extractMessageId(from: json)
            let requestId = parser.extractRequestId(from: json)
            
            guard deduplication.shouldInclude(messageId: messageId, requestId: requestId) else {
                continue
            }
            
            // Parse entry
            do {
                if let entry = try parser.parseJSONLLine(line, projectPath: decodedProjectPath) {
                    entries.append(entry)
                }
            } catch {
                logger.debug("Failed to parse entry in file \(path): \(error.localizedDescription)")
                // Continue processing other entries
            }
        }
        
        return entries
    }
    
    private func getEarliestTimestamp(from path: String) async -> String? {
        let content: String
        do {
            content = try await fileSystem.readFile(atPath: path)
        } catch {
            logger.debug("Failed to read file \(path) for timestamp: \(error.localizedDescription)")
            return nil
        }
        
        let lines = content.components(separatedBy: .newlines)
        var earliestTimestamp: String?
        
        for line in lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let timestamp = parser.extractTimestamp(from: json) else {
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
    
    private func sortFilesByTimestamp(_ files: [(path: String, projectDir: String, earliestTimestamp: String)]) -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        return files.sorted { $0.earliestTimestamp < $1.earliestTimestamp }
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

// MARK: - Async FileSystem Adapter

/// Adapter to convert sync FileSystemProtocol to async
private struct AsyncFileSystemAdapter: AsyncFileSystemProtocol {
    private let fileSystem: FileSystemProtocol
    
    init(_ fileSystem: FileSystemProtocol) {
        self.fileSystem = fileSystem
    }
    
    func fileExists(atPath path: String) async -> Bool {
        fileSystem.fileExists(atPath: path)
    }
    
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        try fileSystem.contentsOfDirectory(atPath: path)
    }
    
    func readFile(atPath path: String) async throws -> String {
        try fileSystem.readFile(atPath: path)
    }
}