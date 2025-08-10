import Foundation

// MARK: - Actor-based Live Monitor

/// LiveMonitorActor is a thread-safe, actor-based implementation for monitoring Claude usage files.
/// This implementation uses Swift's modern concurrency features for better performance and safety.
public actor LiveMonitorActor {
    private let config: LiveMonitorConfig
    private var lastFileTimestamps: [String: Date] = [:]
    private var processedHashes: Set<String> = Set()
    private var allEntries: [UsageEntry] = []
    private var maxTokensFromPreviousSessions: Int = 0
    
    // Parser is stateless and can be nonisolated
    private nonisolated let parser = JSONLParser()
    
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
                let lastTimestamp = lastFileTimestamps[file]
                if lastTimestamp == nil || timestamp > lastTimestamp! {
                    filesToRead.append(file)
                    lastFileTimestamps[file] = timestamp
                }
            }
        }
        
        // Load new entries
        if !filesToRead.isEmpty {
            loadEntriesFromFiles(filesToRead)
        }
        
        // Identify session blocks
        let blocks = identifySessionBlocks(entries: allEntries)
        
        // Update max tokens from previous completed sessions
        maxTokensFromPreviousSessions = 0
        for block in blocks {
            if !block.isActive && !block.isGap {
                let blockTokens = block.tokenCounts.total
                if blockTokens > maxTokensFromPreviousSessions {
                    maxTokensFromPreviousSessions = blockTokens
                }
            }
        }
        
        // Find all active blocks
        let activeBlocks = blocks.filter { $0.isActive }
        
        // Return nil if no active blocks
        guard !activeBlocks.isEmpty else {
            return nil
        }
        
        // Find the best active block
        var bestBlock: SessionBlock?
        for block in activeBlocks {
            if bestBlock == nil || block.startTime > bestBlock!.startTime {
                bestBlock = block
            }
        }
        
        // Return the active block without project filtering (matches ccusage behavior)
        return bestBlock
    }
    
    public func getAutoTokenLimit() -> Int? {
        _ = getActiveBlock() // Ensure we've loaded data
        return maxTokensFromPreviousSessions > 0 ? maxTokensFromPreviousSessions : nil
    }
    
    public func clearCache() {
        lastFileTimestamps.removeAll()
        processedHashes.removeAll()
        allEntries.removeAll()
        maxTokensFromPreviousSessions = 0
    }
    
    // MARK: - Private Methods
    
    private func findUsageFiles() -> [String] {
        var allFiles: [String] = []
        let fileManager = FileManager.default
        
        for basePath in config.claudePaths {
            let projectsPath = basePath.appending("/projects")
            
            do {
                let projectDirs = try fileManager.contentsOfDirectory(atPath: projectsPath)
                for projectDir in projectDirs {
                    let projectPath = projectsPath.appending("/\(projectDir)")
                    let projectFiles = try fileManager.contentsOfDirectory(atPath: projectPath)
                    for file in projectFiles where file.hasSuffix(".json") {
                        allFiles.append(projectPath.appending("/\(file)"))
                    }
                }
            } catch {
                // Silently ignore errors (directory might not exist)
            }
        }
        
        return allFiles
    }
    
    private nonisolated func getFileModificationTime(_ path: String) -> Date? {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
    
    private func loadEntriesFromFiles(_ files: [String]) {
        for file in files {
            let newEntries = parser.parseFile(at: file, processedHashes: &processedHashes)
            allEntries.append(contentsOf: newEntries)
        }
        
        // Sort entries by timestamp
        allEntries.sort { $0.timestamp < $1.timestamp }
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
                
                // Start new block if session duration exceeded or large gap
                if timeSinceBlockStart > sessionDurationSeconds || timeSinceLastEntry > 1800 {
                    // Finalize current block
                    if !currentBlockEntries.isEmpty {
                        let block = createSessionBlock(
                            entries: currentBlockEntries,
                            startTime: blockStart,
                            sessionDuration: sessionDurationSeconds,
                            now: now
                        )
                        blocks.append(block)
                    }
                    
                    // Start new block
                    currentBlockStart = entryTime
                    currentBlockEntries = [entry]
                } else {
                    currentBlockEntries.append(entry)
                }
            } else {
                // First entry
                currentBlockStart = entryTime
                currentBlockEntries = [entry]
            }
        }
        
        // Finalize last block
        if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
            let block = createSessionBlock(
                entries: currentBlockEntries,
                startTime: blockStart,
                sessionDuration: sessionDurationSeconds,
                now: now
            )
            blocks.append(block)
        }
        
        return blocks
    }
    
    private func createSessionBlock(
        entries: [UsageEntry],
        startTime: Date,
        sessionDuration: TimeInterval,
        now: Date
    ) -> SessionBlock {
        let endTime = startTime.addingTimeInterval(sessionDuration)
        let isActive = now.timeIntervalSince(entries.last!.timestamp) < 300 // Active if last entry within 5 minutes
        
        // Calculate token counts
        var totalInput = 0
        var totalOutput = 0
        var totalCacheCreation = 0
        var totalCacheRead = 0
        var costs: [String: Double] = [:]
        var models = Set<String>()
        
        for entry in entries {
            models.insert(entry.model)
            
            let usage = entry.usage
            totalInput += usage.inputTokens
            totalOutput += usage.outputTokens
            totalCacheCreation += usage.cacheCreationInputTokens
            totalCacheRead += usage.cacheReadInputTokens
            
            let modelCost = costs[entry.model] ?? 0
            costs[entry.model] = modelCost + entry.costUSD
        }
        
        let tokenCounts = TokenCounts(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            cacheCreationInputTokens: totalCacheCreation,
            cacheReadInputTokens: totalCacheRead
        )
        
        // Calculate total cost
        let totalCost = costs.values.reduce(0, +)
        
        // Calculate burn rate
        let elapsed = isActive ? now.timeIntervalSince(startTime) : endTime.timeIntervalSince(startTime)
        let tokensPerSecond = elapsed > 0 ? Double(tokenCounts.total) / elapsed : 0
        let tokensPerMinute = Int(tokensPerSecond * 60)
        let costPerHour = elapsed > 0 ? (totalCost / elapsed) * 3600 : 0
        
        let burnRate = BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
        
        // Calculate projected usage
        let remainingTime = max(0, endTime.timeIntervalSince(now))
        let remainingMinutes = remainingTime / 60
        let projectedTokens = Int(tokensPerSecond * remainingTime)
        let projectedCost = costPerHour * (remainingTime / 3600)
        
        let projectedUsage = ProjectedUsage(
            totalTokens: tokenCounts.total + projectedTokens,
            totalCost: totalCost + projectedCost,
            remainingMinutes: remainingMinutes
        )
        
        // Get the last usage limit reset time from entries
        let usageLimitResetTime = entries.compactMap { $0.usageLimitResetTime }.last
        
        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: isActive ? nil : entries.last?.timestamp,
            isActive: isActive,
            isGap: false,
            entries: config.order == .ascending ? entries : entries.reversed(),
            tokenCounts: tokenCounts,
            costUSD: totalCost,
            models: Array(models),
            usageLimitResetTime: usageLimitResetTime,
            burnRate: burnRate,
            projectedUsage: projectedUsage
        )
    }
}