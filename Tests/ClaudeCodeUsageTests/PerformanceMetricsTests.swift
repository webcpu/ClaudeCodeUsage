//
//  PerformanceMetricsTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for PerformanceMetrics collection and analysis
//

import Testing
import Foundation
@testable import ClaudeCodeUsage

@Suite("PerformanceMetrics Tests")
struct PerformanceMetricsTests {
    
    @Test("Should record async operation metrics")
    func testRecordAsyncMetrics() async throws {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "TestOperation"
        
        // When
        let result = try await metrics.record(operationName) {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return 42
        }
        
        // Then
        #expect(result == 42)
        
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 1)
        #expect(stats!.averageDuration >= 0.01) // At least 10ms
    }
    
    @Test("Should record sync operation metrics")
    func testRecordSyncMetrics() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "SyncOperation"
        
        // When
        let result = await metrics.recordSync(operationName) {
            Thread.sleep(forTimeInterval: 0.01) // 10ms
            return "test"
        }
        
        // Then
        #expect(result == "test")
        
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 1)
        #expect(stats!.averageDuration >= 0.01)
    }
    
    @Test("Should calculate statistics correctly")
    func testStatisticsCalculation() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "StatsTest"
        
        // When - Record multiple operations with varying durations
        for i in 1...10 {
            _ = await metrics.recordSync(operationName) {
                Thread.sleep(forTimeInterval: Double(i) * 0.001) // 1ms to 10ms
                return i
            }
        }
        
        // Then
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 10)
        #expect(stats!.minDuration >= 0.001)
        #expect(stats!.maxDuration >= 0.010)
        #expect(stats!.averageDuration > stats!.minDuration)
        #expect(stats!.averageDuration < stats!.maxDuration)
        #expect(stats!.p50Duration > 0)
        #expect(stats!.p95Duration >= stats!.p50Duration)
        #expect(stats!.p99Duration >= stats!.p95Duration)
    }
    
    @Test("Should handle disabled metrics")
    func testDisabledMetrics() async {
        // Given
        let metrics = PerformanceMetrics(enabled: false)
        let operationName = "DisabledTest"
        
        // When
        let result = await metrics.record(operationName) {
            return "no metrics"
        }
        
        // Then
        #expect(result == "no metrics")
        
        let stats = await metrics.getStats(for: operationName)
        #expect(stats == nil)
    }
    
    @Test("Should limit stored metrics per operation")
    func testMetricsLimit() async {
        // Given
        let maxMetrics = 10
        let metrics = PerformanceMetrics(maxMetricsPerOperation: maxMetrics, enabled: true)
        let operationName = "LimitTest"
        
        // When - Record more than the limit
        for i in 1...20 {
            _ = await metrics.recordSync(operationName) { i }
        }
        
        // Then
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == maxMetrics)
    }
    
    @Test("Should handle errors in recorded operations")
    func testErrorHandling() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "ErrorTest"
        
        enum TestError: Error {
            case expected
        }
        
        // When/Then
        await #expect(throws: TestError.self) {
            try await metrics.record(operationName) {
                throw TestError.expected
            }
        }
        
        // Metrics should still be recorded even when operation throws
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 1)
    }
    
    @Test("Should clear metrics")
    func testClearMetrics() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operation1 = "Op1"
        let operation2 = "Op2"
        
        _ = await metrics.recordSync(operation1) { 1 }
        _ = await metrics.recordSync(operation2) { 2 }
        
        // When - Clear specific operation
        await metrics.clearMetrics(for: operation1)
        
        // Then
        let stats1 = await metrics.getStats(for: operation1)
        let stats2 = await metrics.getStats(for: operation2)
        #expect(stats1 == nil)
        #expect(stats2 != nil)
        
        // When - Clear all
        await metrics.clearMetrics()
        
        // Then
        let allStats = await metrics.getAllStats()
        #expect(allStats.isEmpty)
    }
    
    @Test("Should export metrics as JSON")
    func testExportMetrics() async throws {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        
        _ = await metrics.recordSync("Operation1") { 1 }
        _ = await metrics.recordSync("Operation2") { 2 }
        
        // When
        let jsonData = await metrics.exportMetrics()
        
        // Then
        #expect(jsonData != nil)
        
        if let data = jsonData {
            let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            #expect(json != nil)
            #expect(json!.count == 2)
            
            for stat in json! {
                #expect(stat["operation"] != nil)
                #expect(stat["count"] != nil)
                #expect(stat["averageDuration"] != nil)
            }
        }
    }
    
    @Test("Should generate performance report")
    func testGenerateReport() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        
        // Record some slow operations
        _ = await metrics.recordSync("SlowOp") {
            Thread.sleep(forTimeInterval: 1.1) // > 1 second
            return true
        }
        
        _ = await metrics.recordSync("FastOp") {
            return true
        }
        
        // When
        let report = await metrics.generateReport()
        
        // Then
        #expect(report.contains("Performance Metrics Report"))
        #expect(report.contains("SlowOp"))
        #expect(report.contains("FastOp"))
        #expect(report.contains("⚠️ Slow Operations"))
    }
    
    @Test("Should format durations correctly")
    func testDurationFormatting() {
        // Given
        let microseconds = MetricData(
            operation: "test",
            duration: 0.0001,
            timestamp: Date(),
            metadata: [:]
        )
        
        let milliseconds = MetricData(
            operation: "test",
            duration: 0.05,
            timestamp: Date(),
            metadata: [:]
        )
        
        let seconds = MetricData(
            operation: "test",
            duration: 2.5,
            timestamp: Date(),
            metadata: [:]
        )
        
        // Then
        #expect(microseconds.formattedDuration.contains("µs"))
        #expect(milliseconds.formattedDuration.contains("ms"))
        #expect(seconds.formattedDuration.contains("s"))
    }
    
    @Test("Should handle concurrent access safely")
    func testConcurrentAccess() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "ConcurrentTest"
        
        // When - Multiple concurrent operations
        await withTaskGroup(of: Int.self) { group in
            for i in 1...100 {
                group.addTask {
                    await metrics.recordSync(operationName) { i }
                }
            }
        }
        
        // Then
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 100)
    }
    
    @Test("Should track metadata correctly")
    func testMetadataTracking() async {
        // Given
        let metrics = PerformanceMetrics(enabled: true)
        let operationName = "MetadataTest"
        let metadata: [String: Any] = ["key": "value", "count": 42]
        
        // When
        _ = await metrics.record(operationName, metadata: metadata) {
            return true
        }
        
        // Then - Metadata is stored but not exposed in stats
        // This test verifies the API accepts metadata without errors
        let stats = await metrics.getStats(for: operationName)
        #expect(stats != nil)
        #expect(stats!.count == 1)
    }
}

// MARK: - Performance Test for AsyncUsageRepository Extension

@Suite("AsyncUsageRepository Performance Extension")
struct AsyncUsageRepositoryPerformanceTests {
    
    @Test("Should track repository performance metrics")
    func testRepositoryPerformanceTracking() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupTestData()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        // Clear any existing metrics
        await PerformanceMetrics.shared.clearMetrics()
        
        // When
        let stats = try await repository.getUsageStatsWithMetrics()
        
        // Then
        #expect(stats.totalCost > 0)
        
        let perfStats = await PerformanceMetrics.shared.getStats(for: "UsageRepository.getUsageStats")
        #expect(perfStats != nil)
        #expect(perfStats!.count == 1)
    }
}

// Mock file system for testing
private actor MockAsyncFileSystem: AsyncFileSystemProtocol {
    var mockFiles: [String: String] = [:]
    
    func fileExists(atPath path: String) async -> Bool {
        return mockFiles.keys.contains { $0.hasPrefix(path) }
    }
    
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        let prefix = path.hasSuffix("/") ? path : path + "/"
        return mockFiles.keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { $0.replacingOccurrences(of: prefix, with: "").components(separatedBy: "/").first }
            .uniqued()
    }
    
    func readFile(atPath path: String) async throws -> String {
        guard let content = mockFiles[path] else {
            throw NSError(domain: "MockFS", code: 404)
        }
        return content
    }

    func readFirstLine(atPath path: String) async throws -> String? {
        guard let content = mockFiles[path] else {
            throw NSError(domain: "MockFS", code: 404)
        }
        return content.components(separatedBy: .newlines).first
    }

    func setupTestData() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let jsonLine = """
        {"timestamp":"\(timestamp)","message":{"id":"msg_1","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":10,"cache_read_input_tokens":5}},"sessionId":"session1","requestId":"req_1"}
        """
        
        mockFiles["/test/projects"] = ""
        mockFiles["/test/projects/project1"] = ""
        mockFiles["/test/projects/project1/session1.jsonl"] = jsonLine
    }
}

// Helper extension
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        Array(Set(self))
    }
}