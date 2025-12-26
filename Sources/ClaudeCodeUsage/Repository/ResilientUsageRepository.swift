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
        let entries = await processFilesConcurrently(sortedFiles)
        
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
        var entries = await processFilesConcurrently(sortedFiles)
        
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
            // Skip non-Claude-Code directories (e.g., RPLY app sessions)
            if Self.shouldSkipDirectory(projectDir) {
                continue
            }

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
    
    private func processFilesConcurrently(_ files: [(path: String, projectDir: String, earliestTimestamp: String)]) async -> [UsageEntry] {
        await withTaskGroup(of: [UsageEntry].self) { group in
            for (filePath, projectDir, _) in files {
                group.addTask {
                    await self.processJSONLFile(
                        at: filePath,
                        projectDir: projectDir
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
    
    private func processJSONLFile(at path: String, projectDir: String) async -> [UsageEntry] {
        // Resilient file read: if file fails (e.g., being written to), skip it
        let content: String
        do {
            content = try await fileSystem.readFile(atPath: path)
        } catch {
            logger.warning("Skipping file \(path): \(error.localizedDescription)")
            return []
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = pathDecoder.decode(projectDir)
        
        for line in lines {
            // Skip obviously incomplete lines (truncated during file write)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
                continue  // Silently skip incomplete JSON lines
            }

            guard let data = line.data(using: .utf8) else {
                continue  // Silently skip encoding issues
            }

            let json: [String: Any]
            do {
                guard let parsedJson = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue  // Silently skip non-object JSON
                }
                json = parsedJson
            } catch {
                // Only log if it looks complete but still fails (rare corruption)
                #if DEBUG
                logger.debug("Unexpected JSON parse error in \(path): \(error.localizedDescription)")
                #endif
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
    
    func readFirstLine(atPath path: String) async throws -> String? {
        try fileSystem.readFirstLine(atPath: path)
    }
}