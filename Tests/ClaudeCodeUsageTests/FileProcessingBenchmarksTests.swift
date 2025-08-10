//
//  FileProcessingBenchmarksTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for file processing benchmarks
//

import Foundation
import Testing
@testable import ClaudeCodeUsage

@Suite("File Processing Benchmarks")
struct FileProcessingBenchmarksTests {
    
    @Test("Run small dataset benchmark")
    func testSmallDatasetBenchmark() async throws {
        // Arrange
        let config = FileProcessingBenchmarks.Configuration()
        let benchmarks = FileProcessingBenchmarks(
            basePath: NSHomeDirectory() + "/.claude",
            performanceMetrics: PerformanceMetrics(),
            config: config
        )
        
        // Act
        let results = try await benchmarks.runAllBenchmarks()
        
        // Assert
        #expect(results.fileDiscovery != nil)
        #expect(results.jsonParsing != nil)
        #expect(results.deduplication != nil)
        #expect(results.aggregation != nil)
        #expect(results.concurrentProcessing != nil)
        #expect(results.memoryPressure != nil)
        
        // Print report for inspection
        let report = results.generateReport()
        print(report)
    }
    
    @Test("Benchmark report generation")
    func testBenchmarkReportGeneration() async throws {
        // Arrange
        let results = BenchmarkResults(
            fileDiscovery: BenchmarkMetric(
                name: "File Discovery",
                scenarios: [
                    ScenarioMetric(
                        name: "Small",
                        fileCount: 10,
                        duration: 0.05,
                        throughput: 200
                    )
                ],
                summary: "Avg throughput: 200 ops/s"
            ),
            jsonParsing: BenchmarkMetric(
                name: "JSON Parsing",
                scenarios: [
                    ScenarioMetric(
                        name: "1000 entries",
                        entryCount: 1000,
                        duration: 0.1,
                        throughput: 10000
                    )
                ],
                summary: "Avg throughput: 10000 ops/s"
            )
        )
        
        // Act
        let report = results.generateReport()
        
        // Assert
        #expect(report.contains("File Processing Performance Benchmarks"))
        #expect(report.contains("File Discovery"))
        #expect(report.contains("JSON Parsing"))
        #expect(report.contains("Avg throughput"))
    }
    
    @Test("Memory pressure tracking")
    func testMemoryPressureTracking() async throws {
        // Arrange
        let benchmarks = FileProcessingBenchmarks(
            basePath: NSHomeDirectory() + "/.claude",
            performanceMetrics: NullPerformanceMetrics()
        )
        
        // Act - Run only memory pressure benchmark
        let results = try await benchmarks.runAllBenchmarks()
        
        // Assert
        #expect(results.memoryPressure != nil)
        if let memoryMetric = results.memoryPressure {
            #expect(memoryMetric.scenarios.count > 0)
            
            // Check that memory metadata is present
            if let metadata = memoryMetric.scenarios.first?.metadata,
               let memoryDelta = metadata["memoryDelta"] as? Int64 {
                print("Memory delta: \(memoryDelta) bytes")
                #expect(memoryDelta >= 0) // Memory usage should be tracked
            }
        }
    }
    
    @Test("Concurrent processing benchmark")
    func testConcurrentProcessingBenchmark() async throws {
        // Arrange
        let benchmarks = FileProcessingBenchmarks(
            performanceMetrics: PerformanceMetrics()
        )
        
        // Act
        let results = try await benchmarks.runAllBenchmarks()
        
        // Assert
        #expect(results.concurrentProcessing != nil)
        
        if let concurrentMetric = results.concurrentProcessing {
            // Should have multiple concurrency levels tested
            #expect(concurrentMetric.scenarios.count >= 5)
            
            // Higher concurrency should generally have better throughput
            let sortedByThroughput = concurrentMetric.scenarios.sorted { $0.throughput > $1.throughput }
            let highestThroughput = sortedByThroughput.first
            
            if let highest = highestThroughput,
               let level = highest.metadata["concurrencyLevel"] as? Int {
                print("Optimal concurrency level: \(level) with throughput: \(highest.throughput) ops/s")
                #expect(level > 1) // Optimal should be greater than sequential
            }
        }
    }
    
    @Test("Deduplication performance with varying duplicate ratios")
    func testDeduplicationBenchmark() async throws {
        // Arrange
        let benchmarks = FileProcessingBenchmarks()
        
        // Act
        let results = try await benchmarks.runAllBenchmarks()
        
        // Assert
        #expect(results.deduplication != nil)
        
        if let dedupMetric = results.deduplication {
            // Should test multiple duplicate ratios
            #expect(dedupMetric.scenarios.count >= 4)
            
            // Performance should degrade with more duplicates
            for scenario in dedupMetric.scenarios {
                if let ratio = scenario.metadata["duplicateRatio"] as? Double {
                    print("Duplicate ratio: \(ratio * 100)%, Throughput: \(scenario.throughput) ops/s")
                }
            }
        }
    }
}