//
//  EndToEndIntegrationTests.swift
//  IntegrationTests
//
//  End-to-end integration tests for the full application flow
//

import Foundation
import Testing
@testable import ClaudeCodeUsage
@testable import UsageDashboardApp

@Suite("End-to-End Integration Tests")
struct EndToEndIntegrationTests {
    
    // MARK: - Repository to UI Flow
    
    @Test("Data flows from repository to UI correctly")
    @MainActor
    func testDataFlowIntegration() async throws {
        // Arrange
        let mockFileSystem = MockAsyncFileSystem()
        
        // Setup mock data
        mockFileSystem.mockFiles["/test/.claude/projects"] = []
        mockFileSystem.mockFiles["/test/.claude/projects/project1"] = ["session1.jsonl"]
        mockFileSystem.mockFiles["/test/.claude/projects/project1/session1.jsonl"] = """
        {"id":"msg_1","timestamp":"2025-08-10T10:00:00Z","model":"claude-3-5-sonnet-20241022","inputTokens":100,"outputTokens":50}
        {"id":"msg_2","timestamp":"2025-08-10T11:00:00Z","model":"claude-3-5-sonnet-20241022","inputTokens":200,"outputTokens":100}
        """
        
        // Create repository with mock file system
        let repository = AsyncUsageRepository(
            basePath: "/test/.claude",
            fileSystem: mockFileSystem,
            performanceMetrics: nil
        )
        
        // Act - Load data through repository
        let stats = try await repository.getUsageStats()
        
        // Assert - Verify data processed correctly
        #expect(stats.totalSessions == 1)
        #expect(stats.totalInputTokens == 300)
        #expect(stats.totalOutputTokens == 150)
        #expect(stats.totalTokens == 450)
        #expect(stats.totalCost > 0)
        
        // Verify model aggregation
        #expect(stats.byModel.count == 1)
        if let modelStats = stats.byModel.first {
            #expect(modelStats.model == "claude-3-5-sonnet-20241022")
            #expect(modelStats.inputTokens == 300)
            #expect(modelStats.outputTokens == 150)
        }
    }
    
    // MARK: - Memory Monitoring Integration
    
    @Test("Memory monitor integrates with app lifecycle")
    @MainActor
    func testMemoryMonitorIntegration() async throws {
        // Arrange
        let monitor = MemoryMonitor()
        var cleanupNotificationReceived = false
        
        let observer = NotificationCenter.default.addObserver(
            forName: .performMemoryCleanup,
            object: nil,
            queue: .main
        ) { _ in
            cleanupNotificationReceived = true
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Act - Start monitoring
        monitor.startMonitoring()
        monitor.updateInterval = 0.1
        
        // Wait for initial stats
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Assert - Monitor is working
        #expect(monitor.isMonitoring == true)
        #expect(monitor.currentStats != nil)
        
        // Simulate high memory pressure
        monitor.criticalThresholdMB = 1 // Very low to trigger
        await monitor.forceUpdate()
        
        // Wait for notification
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - Cleanup triggered
        #expect(cleanupNotificationReceived == true)
        
        // Cleanup
        monitor.stopMonitoring()
    }
    
    // MARK: - Concurrent Operations
    
    @Test("Concurrent repository operations maintain consistency")
    func testConcurrentRepositoryOperations() async throws {
        // Arrange
        let mockFileSystem = MockAsyncFileSystem()
        setupLargeDataset(mockFileSystem)
        
        let repository = AsyncUsageRepository(
            basePath: "/test/.claude",
            fileSystem: mockFileSystem,
            maxConcurrency: 4
        )
        
        // Act - Perform concurrent operations
        async let stats1 = repository.getUsageStats()
        async let entries1 = repository.getUsageEntries(limit: 10)
        async let todayEntries = repository.loadEntriesForDate(Date())
        
        // Wait for all operations
        let (stats, entries, today) = try await (stats1, entries1, todayEntries)
        
        // Assert - All operations completed successfully
        #expect(stats.totalSessions > 0)
        #expect(entries.count <= 10)
        #expect(today.count >= 0) // May be 0 if no entries today
        
        // Verify data consistency
        #expect(stats.totalTokens > 0)
        #expect(stats.byModel.count > 0)
    }
    
    // MARK: - Error Recovery
    
    @Test("System recovers from file system errors")
    func testErrorRecoveryIntegration() async throws {
        // Arrange
        let mockFileSystem = MockAsyncFileSystem()
        mockFileSystem.shouldThrowError = true
        
        let repository = AsyncUsageRepository(
            basePath: "/test/.claude",
            fileSystem: mockFileSystem
        )
        
        // Act & Assert - Should handle error gracefully
        do {
            _ = try await repository.getUsageStats()
            Issue.record("Should have thrown error")
        } catch {
            // Expected error
            #expect(error is FileSystemError)
        }
        
        // Now fix the file system
        mockFileSystem.shouldThrowError = false
        mockFileSystem.mockFiles["/test/.claude/projects"] = []
        
        // Should recover and work normally
        let stats = try await repository.getUsageStats()
        #expect(stats.totalSessions == 0) // Empty but valid
    }
    
    // MARK: - Performance Benchmarks Integration
    
    @Test("Benchmarks complete within reasonable time")
    func testBenchmarkIntegration() async throws {
        // Arrange
        let config = FileProcessingBenchmarks.Configuration()
        let benchmarks = FileProcessingBenchmarks(
            basePath: "/test/.claude",
            performanceMetrics: PerformanceMetrics(),
            config: config
        )
        
        // Act - Run minimal benchmark
        let startTime = Date()
        let results = try await benchmarks.runAllBenchmarks()
        let duration = Date().timeIntervalSince(startTime)
        
        // Assert - Benchmarks complete in reasonable time
        #expect(duration < 30.0) // Should complete within 30 seconds
        #expect(results.fileDiscovery != nil)
        #expect(results.jsonParsing != nil)
        
        // Generate report
        let report = results.generateReport()
        #expect(report.contains("File Processing Performance Benchmarks"))
    }
    
    // MARK: - ViewModels Integration
    
    @Test("ViewModels coordinate properly")
    @MainActor
    func testViewModelCoordination() async throws {
        // Arrange
        let container = MockDependencyContainer()
        let viewModel = UsageViewModel(container: container)
        
        // Setup mock data
        container.mockStats = UsageStats(
            totalCost: 10.0,
            totalTokens: 1000,
            totalInputTokens: 600,
            totalOutputTokens: 400,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 5,
            byModel: [],
            byDate: [],
            byProject: []
        )
        
        // Act - Load data
        await viewModel.loadData()
        
        // Wait for state update
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Assert - Data loaded correctly
        switch viewModel.state {
        case .loaded(let stats):
            #expect(stats.totalCost == 10.0)
            #expect(stats.totalTokens == 1000)
            #expect(stats.totalSessions == 5)
        default:
            Issue.record("Expected loaded state")
        }
        
        // Test refresh
        await viewModel.refresh()
        
        // Verify refresh worked
        #expect(viewModel.isLoading == false)
    }
    
    // MARK: - Code Coverage Integration
    
    @Test("Coverage tracking works with real scenarios")
    func testCoverageIntegration() async throws {
        // This test exercises various code paths to improve coverage
        
        // Test type aliases
        let _: ClaudeUsageEntry = UsageEntry(
            project: "test",
            timestamp: "2025-08-10T10:00:00Z",
            model: "claude-3-5-sonnet-20241022",
            inputTokens: 100,
            outputTokens: 50,
            cacheWriteTokens: 0,
            cacheReadTokens: 0,
            cost: 0.001,
            sessionId: "test"
        )
        
        // Test error types
        let fileError = FileSystemError.fileNotFound
        #expect(fileError.localizedDescription.contains("not found"))
        
        let repoError = RepositoryError.invalidData
        #expect(repoError.errorDescription != nil)
        
        // Test performance metrics
        let metrics = PerformanceMetrics()
        let result = await metrics.record("test", metadata: [:]) {
            return 42
        }
        #expect(result == 42)
        
        let stats = await metrics.getStats(for: "test")
        #expect(stats != nil)
    }
    
    // MARK: - Helper Methods
    
    private func setupLargeDataset(_ fileSystem: MockAsyncFileSystem) {
        fileSystem.mockFiles["/test/.claude/projects"] = ["project1", "project2"]
        
        for projectNum in 1...2 {
            let projectPath = "/test/.claude/projects/project\(projectNum)"
            fileSystem.mockFiles[projectPath] = []
            
            for sessionNum in 1...5 {
                let sessionFile = "session\(sessionNum).jsonl"
                fileSystem.mockFiles[projectPath]?.append(sessionFile)
                
                var lines: [String] = []
                for messageNum in 1...20 {
                    let timestamp = "2025-08-10T\(10 + messageNum % 14):00:00Z"
                    let line = """
                    {"id":"msg_\(messageNum)","timestamp":"\(timestamp)","model":"claude-3-5-sonnet-20241022","inputTokens":\(100 * messageNum),"outputTokens":\(50 * messageNum)}
                    """
                    lines.append(line)
                }
                
                let filePath = "\(projectPath)/\(sessionFile)"
                fileSystem.mockFiles[filePath] = lines.joined(separator: "\n")
            }
        }
    }
}

// MARK: - Mock Implementations

class MockAsyncFileSystem: AsyncFileSystemProtocol {
    var mockFiles: [String: Any] = [:]
    var shouldThrowError = false
    
    func fileExists(atPath path: String) async -> Bool {
        return mockFiles[path] != nil
    }
    
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        if shouldThrowError {
            throw FileSystemError.directoryNotFound
        }
        
        if let contents = mockFiles[path] as? [String] {
            return contents
        }
        return []
    }
    
    func readFile(atPath path: String) async throws -> String {
        if shouldThrowError {
            throw FileSystemError.fileNotFound
        }
        
        if let content = mockFiles[path] as? String {
            return content
        }
        throw FileSystemError.fileNotFound
    }
    
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        return [URL(fileURLWithPath: "/test")]
    }
}