import Foundation

// MARK: - Configuration

public struct LiveMonitorConfig {
    public let claudePaths: [String]
    public let sessionDurationHours: Double
    public let tokenLimit: Int?
    public let refreshInterval: TimeInterval
    public let order: SortOrder
    
    public enum SortOrder {
        case ascending
        case descending
    }
    
    public init(claudePaths: [String], sessionDurationHours: Double = 5,
                tokenLimit: Int? = nil, refreshInterval: TimeInterval = 1.0,
                order: SortOrder = .descending) {
        self.claudePaths = claudePaths
        self.sessionDurationHours = sessionDurationHours
        self.tokenLimit = tokenLimit
        self.refreshInterval = refreshInterval
        self.order = order
    }
}

// MARK: - Live Monitor

/// LiveMonitor manages the reading and processing of Claude usage files with thread-safe access.
/// 
/// Thread Safety Implementation:
/// - Uses a concurrent queue with barriers for reader-writer lock pattern
/// - Reads use queue.sync for concurrent access
/// - Writes use queue.sync(flags: .barrier) for exclusive access
/// 
/// TODO: Consider migrating to Swift actors for better alignment with modern concurrency patterns
public class LiveMonitor {
    private let config: LiveMonitorConfig
    private var lastFileTimestamps: [String: Date] = [:]
    private var processedHashes: Set<String> = Set()
    private var allEntries: [UsageEntry] = []
    private var maxTokensFromPreviousSessions: Int = 0
    private let parser = JSONLParser()
    
    /// Concurrent queue for thread-safe access to mutable state
    private let queue = DispatchQueue(label: "com.claudecodemonitor.livemonitor", attributes: .concurrent)
    
    public init(config: LiveMonitorConfig) {
        self.config = config
    }
    
    public func getActiveBlock() -> SessionBlock? {
        let files = findUsageFiles()
        
        if files.isEmpty {
            return nil
        }
        
        // Check for new or modified files
        var filesToRead: [String] = []
        for file in files {
            if let timestamp = getFileModificationTime(file) {
                // First, check if we should read (non-blocking read)
                let shouldRead = queue.sync { () -> Bool in
                    let lastTimestamp = self.lastFileTimestamps[file]
                    return lastTimestamp == nil || timestamp > lastTimestamp!
                }
                
                if shouldRead {
                    filesToRead.append(file)
                    // Update timestamp with barrier (write operation)
                    queue.sync(flags: .barrier) {
                        self.lastFileTimestamps[file] = timestamp
                    }
                }
            }
        }
        
        // Load new entries
        if !filesToRead.isEmpty {
            loadEntriesFromFiles(filesToRead)
        }
        
        // Identify session blocks
        let currentEntries = queue.sync { allEntries }
        let blocks = identifySessionBlocks(entries: currentEntries)
        
        // Update max tokens from previous completed sessions
        queue.sync(flags: .barrier) {
            self.maxTokensFromPreviousSessions = 0
            for block in blocks {
                if !block.isActive && !block.isGap {
                    let blockTokens = block.tokenCounts.total
                    if blockTokens > self.maxTokensFromPreviousSessions {
                        self.maxTokensFromPreviousSessions = blockTokens
                    }
                }
            }
        }
        
        // Find all active blocks
        let activeBlocks = blocks.filter { $0.isActive }
        
        if activeBlocks.isEmpty {
            return nil
        }
        
        // If multiple active blocks, choose the one with the most recent activity
        let bestBlock = activeBlocks.max { block1, block2 in
            let lastTime1 = block1.actualEndTime ?? block1.startTime
            let lastTime2 = block2.actualEndTime ?? block2.startTime
            return lastTime1 < lastTime2
        }
        
        // Return the active block without project filtering (matches ccusage behavior)
        return bestBlock
    }
    
    public func getAutoTokenLimit() -> Int? {
        _ = getActiveBlock() // Ensure we've loaded data
        return queue.sync { 
            maxTokensFromPreviousSessions > 0 ? maxTokensFromPreviousSessions : nil
        }
    }
    
    public func clearCache() {
        queue.sync(flags: .barrier) {
            self.lastFileTimestamps.removeAll()
            self.processedHashes.removeAll()
            self.allEntries.removeAll()
            self.maxTokensFromPreviousSessions = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func findUsageFiles() -> [String] {
        var files: [String] = []
        let fileManager = FileManager.default
        
        for claudePath in config.claudePaths {
            let projectsPath = "\(claudePath)/projects"
            
            guard fileManager.fileExists(atPath: projectsPath) else {
                continue
            }
            
            if let enumerator = fileManager.enumerator(atPath: projectsPath) {
                while let path = enumerator.nextObject() as? String {
                    if path.hasSuffix(".jsonl") {
                        files.append("\(projectsPath)/\(path)")
                    }
                }
            }
        }
        
        return files
    }
    
    private func getFileModificationTime(_ path: String) -> Date? {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
    
    private func loadEntriesFromFiles(_ files: [String]) {
        queue.sync(flags: .barrier) {
            for file in files {
                let newEntries = self.parser.parseFile(at: file, processedHashes: &self.processedHashes)
                self.allEntries.append(contentsOf: newEntries)
            }
            
            // Sort entries by timestamp
            self.allEntries.sort { $0.timestamp < $1.timestamp }
        }
    }
    
    private func identifySessionBlocks(entries: [UsageEntry]) -> [SessionBlock] {
        guard !entries.isEmpty else {
            return []
        }
        
        let sessionDurationSeconds = config.sessionDurationHours * 60 * 60
        var blocks: [SessionBlock] = []
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        
        var currentBlockStart: Date?
        var currentBlockEntries: [UsageEntry] = []
        let now = Date()
        
        for entry in sortedEntries {
            let entryTime = entry.timestamp
            
            if let blockStart = currentBlockStart {
                let timeSinceBlockStart = entryTime.timeIntervalSince(blockStart)
                
                // Check for gap between entries
                let lastEntry = currentBlockEntries.last
                let timeSinceLastEntry = lastEntry != nil ? entryTime.timeIntervalSince(lastEntry!.timestamp) : 0
                
                if timeSinceBlockStart > sessionDurationSeconds || timeSinceLastEntry > sessionDurationSeconds {
                    // Close current block
                    if let block = createBlock(
                        startTime: blockStart,
                        entries: currentBlockEntries,
                        now: now,
                        sessionDurationSeconds: sessionDurationSeconds
                    ) {
                        blocks.append(block)
                    }
                    
                    // Start new block
                    currentBlockStart = floorToHour(entryTime)
                    currentBlockEntries = [entry]
                } else {
                    currentBlockEntries.append(entry)
                }
            } else {
                // First entry
                currentBlockStart = floorToHour(entryTime)
                currentBlockEntries = [entry]
            }
        }
        
        // Close the last block
        if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
            if let block = createBlock(
                startTime: blockStart,
                entries: currentBlockEntries,
                now: now,
                sessionDurationSeconds: sessionDurationSeconds
            ) {
                blocks.append(block)
            }
        }
        
        return blocks
    }
    
    private func createBlock(startTime: Date, entries: [UsageEntry], now: Date, sessionDurationSeconds: TimeInterval) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }
        
        let endTime = startTime.addingTimeInterval(sessionDurationSeconds)
        let actualEndTime = entries.last?.timestamp
        let isActive = actualEndTime != nil && 
                      now.timeIntervalSince(actualEndTime!) < sessionDurationSeconds && 
                      now < endTime
        
        // Aggregate token counts and costs
        var totalTokenCounts = TokenCounts(
            inputTokens: 0,
            outputTokens: 0,
            cacheCreationInputTokens: 0,
            cacheReadInputTokens: 0
        )
        
        var costUSD = 0.0
        var models = Set<String>()
        var usageLimitResetTime: Date?
        
        for entry in entries {
            totalTokenCounts = TokenCounts(
                inputTokens: totalTokenCounts.inputTokens + entry.usage.inputTokens,
                outputTokens: totalTokenCounts.outputTokens + entry.usage.outputTokens,
                cacheCreationInputTokens: totalTokenCounts.cacheCreationInputTokens + entry.usage.cacheCreationInputTokens,
                cacheReadInputTokens: totalTokenCounts.cacheReadInputTokens + entry.usage.cacheReadInputTokens
            )
            costUSD += entry.costUSD
            models.insert(entry.model)
            usageLimitResetTime = entry.usageLimitResetTime ?? usageLimitResetTime
        }
        
        // Calculate burn rate
        let elapsedMinutes = (actualEndTime ?? now).timeIntervalSince(startTime) / 60
        let tokensPerMinute = elapsedMinutes > 0 ? Int(Double(totalTokenCounts.total) / elapsedMinutes) : 0
        let costPerHour = elapsedMinutes > 0 ? (costUSD / elapsedMinutes) * 60 : 0
        
        let burnRate = BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
        
        // Calculate projected usage
        let remainingMinutes = endTime.timeIntervalSince(actualEndTime ?? now) / 60
        let projectedTokens = totalTokenCounts.total + Int(Double(tokensPerMinute) * remainingMinutes)
        let projectedCost = costUSD + (costPerHour * remainingMinutes / 60)
        
        let projectedUsage = ProjectedUsage(
            totalTokens: projectedTokens,
            totalCost: projectedCost,
            remainingMinutes: remainingMinutes
        )
        
        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: actualEndTime,
            isActive: isActive,
            isGap: false,
            entries: entries,
            tokenCounts: totalTokenCounts,
            costUSD: costUSD,
            models: Array(models),
            usageLimitResetTime: usageLimitResetTime,
            burnRate: burnRate,
            projectedUsage: projectedUsage
        )
    }
    
    private func floorToHour(_ date: Date) -> Date {
        let secondsSinceEpoch = date.timeIntervalSince1970
        let secondsInHour = 3600.0
        let flooredSeconds = floor(secondsSinceEpoch / secondsInHour) * secondsInHour
        return Date(timeIntervalSince1970: flooredSeconds)
    }
}