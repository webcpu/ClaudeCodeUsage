//
//  UsageRepository.swift
//  ClaudeCodeUsage
//
//  Repository for accessing usage data (Repository Pattern + Dependency Injection)
//

import Foundation

/// Repository for accessing and processing usage data
public class UsageRepository {
    private let fileSystem: FileSystemProtocol
    private let parser: UsageDataParserProtocol
    private let pathDecoder: ProjectPathDecoderProtocol
    private let aggregator: StatisticsAggregatorProtocol
    private let basePath: String
    
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
    public convenience init(basePath: String = NSHomeDirectory() + "/.claude") {
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
        
        // Create a new deduplication instance for this operation to avoid race conditions
        let deduplication = HashBasedDeduplication()
        
        // Collect and process all JSONL files
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        let entries = try processFiles(sortedFiles, deduplication: deduplication)
        
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
        
        // Create a new deduplication instance for this operation to avoid race conditions
        let deduplication = HashBasedDeduplication()
        
        let filesToProcess = try collectJSONLFiles(from: projectsPath)
        let sortedFiles = sortFilesByTimestamp(filesToProcess)
        var entries = try processFiles(sortedFiles, deduplication: deduplication)
        
        // Sort by timestamp (newest first)
        entries.sort { $0.timestamp > $1.timestamp }
        
        if let limit = limit {
            return Array(entries.prefix(limit))
        }
        return entries
    }
    
    // MARK: - Private Methods
    
    private func collectJSONLFiles(from projectsPath: String) throws -> [(path: String, projectDir: String, earliestTimestamp: String)] {
        var filesToProcess: [(path: String, projectDir: String, earliestTimestamp: String)] = []
        
        let projectDirs = try fileSystem.contentsOfDirectory(atPath: projectsPath)
        
        for projectDir in projectDirs {
            let projectPath = projectsPath + "/" + projectDir
            
            guard let files = try? fileSystem.contentsOfDirectory(atPath: projectPath) else {
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
    
    private func processFiles(_ files: [(path: String, projectDir: String, earliestTimestamp: String)], deduplication: DeduplicationStrategy) throws -> [UsageEntry] {
        var allEntries: [UsageEntry] = []
        
        for (filePath, projectDir, _) in files {
            let entries = try processJSONLFile(at: filePath, projectDir: projectDir, deduplication: deduplication)
            allEntries.append(contentsOf: entries)
        }
        
        return allEntries
    }
    
    private func processJSONLFile(at path: String, projectDir: String, deduplication: DeduplicationStrategy) throws -> [UsageEntry] {
        let content = try fileSystem.readFile(atPath: path)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        var entries: [UsageEntry] = []
        let decodedProjectPath = pathDecoder.decode(projectDir)
        
        for line in lines {
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
            
            // Parse entry
            if let entry = try? parser.parseJSONLLine(line, projectPath: decodedProjectPath) {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func getEarliestTimestamp(from path: String) -> String? {
        guard let content = try? fileSystem.readFile(atPath: path) else {
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