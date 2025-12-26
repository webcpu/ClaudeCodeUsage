//
//  FileProcessingBenchmarks.swift
//  ClaudeCodeUsage
//
//  Performance benchmarks for file processing operations
//

import Foundation

/// Comprehensive benchmarks for file processing performance
public actor FileProcessingBenchmarks {
    private let performanceMetrics: PerformanceMetricsProtocol
    private let repository: AsyncUsageRepository
    
    /// Benchmark configuration
    public struct Configuration {
        public let smallDatasetFiles: Int = 10
        public let mediumDatasetFiles: Int = 100
        public let largeDatasetFiles: Int = 1000
        public let entriesPerFile: Int = 100
        public let maxConcurrency: Int = ProcessInfo.processInfo.processorCount * 2
        
        public init() {}
    }
    
    private let config: Configuration
    
    public init(
        basePath: String = NSHomeDirectory() + "/.claude",
        performanceMetrics: PerformanceMetricsProtocol? = nil,
        config: Configuration = Configuration()
    ) {
        self.performanceMetrics = performanceMetrics ?? PerformanceMetrics()
        self.repository = AsyncUsageRepository(
            basePath: basePath,
            performanceMetrics: self.performanceMetrics,
            maxConcurrency: config.maxConcurrency
        )
        self.config = config
    }
    
    // MARK: - Benchmark Suite
    
    /// Run complete benchmark suite
    public func runAllBenchmarks() async throws -> BenchmarkResults {
        var results = BenchmarkResults()
        
        // File Discovery Benchmarks
        results.fileDiscovery = try await benchmarkFileDiscovery()
        
        // JSONL Parsing Benchmarks
        results.jsonParsing = try await benchmarkJSONLParsing()
        
        // Deduplication Benchmarks
        results.deduplication = try await benchmarkDeduplication()
        
        // Aggregation Benchmarks
        results.aggregation = try await benchmarkAggregation()
        
        // Concurrent Processing Benchmarks
        results.concurrentProcessing = try await benchmarkConcurrentProcessing()
        
        // Memory Pressure Test
        results.memoryPressure = try await benchmarkMemoryPressure()
        
        return results
    }
    
    // MARK: - Individual Benchmarks
    
    /// Benchmark file discovery performance
    private func benchmarkFileDiscovery() async throws -> BenchmarkMetric {
        let scenarios = [
            (name: "Small", count: config.smallDatasetFiles),
            (name: "Medium", count: config.mediumDatasetFiles),
            (name: "Large", count: config.largeDatasetFiles)
        ]
        
        var metrics: [ScenarioMetric] = []
        
        for scenario in scenarios {
            let result = await performanceMetrics.record(
                "FileDiscovery_\(scenario.name)",
                metadata: ["fileCount": scenario.count]
            ) {
                // Simulate file discovery
                return await self.simulateFileDiscovery(fileCount: scenario.count)
            }
            
            if let stats = await performanceMetrics.getStats(for: "FileDiscovery_\(scenario.name)") {
                metrics.append(ScenarioMetric(
                    name: scenario.name,
                    fileCount: scenario.count,
                    duration: stats.averageDuration,
                    throughput: Double(scenario.count) / stats.averageDuration
                ))
            }
        }
        
        return BenchmarkMetric(
            name: "File Discovery",
            scenarios: metrics,
            summary: generateSummary(for: metrics)
        )
    }
    
    /// Benchmark JSONL parsing performance
    private func benchmarkJSONLParsing() async throws -> BenchmarkMetric {
        let entryCounts = [1000, 10_000, 100_000]
        var metrics: [ScenarioMetric] = []
        
        for count in entryCounts {
            let jsonlContent = generateMockJSONL(entries: count)
            
            let duration = await measureTime {
                _ = self.parseJSONL(jsonlContent)
            }
            
            metrics.append(ScenarioMetric(
                name: "\(count) entries",
                entryCount: count,
                duration: duration,
                throughput: Double(count) / duration
            ))
        }
        
        return BenchmarkMetric(
            name: "JSONL Parsing",
            scenarios: metrics,
            summary: generateSummary(for: metrics)
        )
    }
    
    /// Benchmark deduplication strategies
    private func benchmarkDeduplication() async throws -> BenchmarkMetric {
        let duplicateRatios = [0.0, 0.25, 0.5, 0.75]
        var metrics: [ScenarioMetric] = []
        
        for ratio in duplicateRatios {
            let entries = generateEntriesWithDuplicates(
                count: 10_000,
                duplicateRatio: ratio
            )
            
            let duration = await measureTime {
                let deduplication = HashBasedDeduplication()
                _ = entries.filter { entry in
                    // Use sessionId and timestamp as unique identifiers
                    deduplication.shouldInclude(
                        messageId: entry.sessionId,
                        requestId: entry.timestamp
                    )
                }
            }
            
            metrics.append(ScenarioMetric(
                name: "\(Int(ratio * 100))% duplicates",
                entryCount: entries.count,
                duration: duration,
                throughput: Double(entries.count) / duration,
                metadata: ["duplicateRatio": ratio]
            ))
        }
        
        return BenchmarkMetric(
            name: "Deduplication",
            scenarios: metrics,
            summary: generateSummary(for: metrics)
        )
    }
    
    /// Benchmark statistics aggregation
    private func benchmarkAggregation() async throws -> BenchmarkMetric {
        let entryCounts = [1000, 10_000, 100_000]
        var metrics: [ScenarioMetric] = []
        
        for count in entryCounts {
            let entries = generateMockEntries(count: count)
            
            let duration = await measureTime {
                let aggregator = StatisticsAggregator()
                _ = aggregator.aggregateStatistics(
                    from: entries,
                    sessionCount: count / 100
                )
            }
            
            metrics.append(ScenarioMetric(
                name: "\(count) entries",
                entryCount: count,
                duration: duration,
                throughput: Double(count) / duration
            ))
        }
        
        return BenchmarkMetric(
            name: "Statistics Aggregation",
            scenarios: metrics,
            summary: generateSummary(for: metrics)
        )
    }
    
    /// Benchmark concurrent vs sequential processing
    private func benchmarkConcurrentProcessing() async throws -> BenchmarkMetric {
        let concurrencyLevels = [1, 2, 4, 8, 16]
        var metrics: [ScenarioMetric] = []
        
        for level in concurrencyLevels {
            let duration = await measureTime {
                await self.processFilesWithConcurrency(
                    fileCount: 100,
                    maxConcurrency: level
                )
            }
            
            metrics.append(ScenarioMetric(
                name: "Concurrency \(level)",
                fileCount: 100,
                duration: duration,
                throughput: 100.0 / duration,
                metadata: ["concurrencyLevel": level]
            ))
        }
        
        return BenchmarkMetric(
            name: "Concurrent Processing",
            scenarios: metrics,
            summary: generateSummary(for: metrics)
        )
    }
    
    /// Benchmark memory usage under pressure
    private func benchmarkMemoryPressure() async throws -> BenchmarkMetric {
        var metrics: [ScenarioMetric] = []
        
        // Test continuous processing with memory tracking
        let startMemory = getMemoryUsage()
        
        let duration = await measureTime {
            for _ in 0..<10 {
                let entries = self.generateMockEntries(count: 10_000)
                _ = entries.reduce(0) { $0 + $1.cost }
                await Task.yield() // Allow memory to be reclaimed
            }
        }
        
        let endMemory = getMemoryUsage()
        let memoryDelta = endMemory - startMemory
        
        metrics.append(ScenarioMetric(
            name: "Continuous Processing",
            entryCount: 100_000,
            duration: duration,
            throughput: 100_000 / duration,
            metadata: [
                "memoryStart": startMemory,
                "memoryEnd": endMemory,
                "memoryDelta": memoryDelta
            ]
        ))
        
        return BenchmarkMetric(
            name: "Memory Pressure",
            scenarios: metrics,
            summary: "Memory usage delta: \(formatBytes(memoryDelta))"
        )
    }
    
    // MARK: - Helper Methods
    
    private func measureTime(_ block: () async -> Void) async -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        await block()
        return CFAbsoluteTimeGetCurrent() - start
    }
    
    private func simulateFileDiscovery(fileCount: Int) async -> [String] {
        // Simulate file system operations
        var files: [String] = []
        for i in 0..<fileCount {
            files.append("/path/to/file\(i).jsonl")
            if i % 100 == 0 {
                await Task.yield()
            }
        }
        return files
    }
    
    private func parseJSONL(_ content: String) -> [UsageEntry] {
        let parser = JSONLUsageParser()
        var entries: [UsageEntry] = []
        
        for line in content.components(separatedBy: .newlines) {
            if let entry = try? parser.parseJSONLLine(line, projectPath: "test") {
                entries.append(entry)
            }
        }
        
        return entries
    }
    
    private func generateMockJSONL(entries: Int) -> String {
        var lines: [String] = []
        for i in 0..<entries {
            let json = """
            {"id":"msg_\(i)","requestId":"req_\(i)","timestamp":"\(Date().ISO8601Format())","model":"claude-3-5-sonnet-20241022","inputTokens":100,"outputTokens":50}
            """
            lines.append(json)
        }
        return lines.joined(separator: "\n")
    }
    
    private func generateMockEntries(count: Int) -> [UsageEntry] {
        (0..<count).map { i in
            UsageEntry(
                project: "test_project",
                timestamp: Date().ISO8601Format(),
                model: "claude-3-5-sonnet-20241022",
                inputTokens: 100,
                outputTokens: 50,
                cacheWriteTokens: 10,
                cacheReadTokens: 5,
                cost: 0.001,
                sessionId: "session_\(i)"
            )
        }
    }
    
    private func generateEntriesWithDuplicates(count: Int, duplicateRatio: Double) -> [UsageEntry] {
        let uniqueCount = Int(Double(count) * (1.0 - duplicateRatio))
        let duplicateCount = count - uniqueCount
        
        var entries = generateMockEntries(count: uniqueCount)
        
        // Add duplicates
        for i in 0..<duplicateCount {
            let original = entries[i % uniqueCount]
            entries.append(original)
        }
        
        return entries.shuffled()
    }
    
    private func processFilesWithConcurrency(fileCount: Int, maxConcurrency: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<min(maxConcurrency, fileCount) {
                group.addTask {
                    // Simulate file processing
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func generateSummary(for metrics: [ScenarioMetric]) -> String {
        guard !metrics.isEmpty else { return "No metrics collected" }
        
        let avgThroughput = metrics.map { $0.throughput }.reduce(0, +) / Double(metrics.count)
        let avgDuration = metrics.map { $0.duration }.reduce(0, +) / Double(metrics.count)
        
        return String(format: "Avg throughput: %.0f ops/s, Avg duration: %.3fs", avgThroughput, avgDuration)
    }
}

// MARK: - Result Types

/// Complete benchmark results
public struct BenchmarkResults {
    public var fileDiscovery: BenchmarkMetric?
    public var jsonParsing: BenchmarkMetric?
    public var deduplication: BenchmarkMetric?
    public var aggregation: BenchmarkMetric?
    public var concurrentProcessing: BenchmarkMetric?
    public var memoryPressure: BenchmarkMetric?
    
    public func generateReport() -> String {
        var report = """
        ========================================
        File Processing Performance Benchmarks
        ========================================
        
        """
        
        if let metric = fileDiscovery {
            report += formatMetric(metric)
        }
        
        if let metric = jsonParsing {
            report += formatMetric(metric)
        }
        
        if let metric = deduplication {
            report += formatMetric(metric)
        }
        
        if let metric = aggregation {
            report += formatMetric(metric)
        }
        
        if let metric = concurrentProcessing {
            report += formatMetric(metric)
        }
        
        if let metric = memoryPressure {
            report += formatMetric(metric)
        }
        
        return report
    }
    
    private func formatMetric(_ metric: BenchmarkMetric) -> String {
        var output = """
        
        \(metric.name)
        ----------------------------------------
        """
        
        for scenario in metric.scenarios {
            output += """
            
            \(scenario.name):
              Duration: \(String(format: "%.3f", scenario.duration))s
              Throughput: \(String(format: "%.0f", scenario.throughput)) ops/s
            """
            
            if let fileCount = scenario.fileCount {
                output += "\n  Files: \(fileCount)"
            }
            
            if let entryCount = scenario.entryCount {
                output += "\n  Entries: \(entryCount)"
            }
        }
        
        output += "\n\nSummary: \(metric.summary)\n"
        
        return output
    }
}

/// Individual benchmark metric
public struct BenchmarkMetric {
    public let name: String
    public let scenarios: [ScenarioMetric]
    public let summary: String
}

/// Scenario-specific metric
public struct ScenarioMetric {
    public let name: String
    public var fileCount: Int?
    public var entryCount: Int?
    public let duration: TimeInterval
    public let throughput: Double // operations per second
    public var metadata: [String: Any] = [:]
}