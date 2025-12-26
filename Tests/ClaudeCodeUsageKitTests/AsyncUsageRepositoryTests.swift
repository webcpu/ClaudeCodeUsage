//
//  AsyncUsageRepositoryTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for AsyncUsageRepository with AsyncSequence
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit

@Suite("AsyncUsageRepository Tests")
struct AsyncUsageRepositoryTests {
    
    @Test("Should load usage stats from async file system")
    func testLoadUsageStats() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupMockProjectData()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem,
            pathDecoder: ProjectPathDecoder(),
            parser: JSONLUsageParser(),
            aggregator: StatisticsAggregator()
        )
        
        // When
        let stats = try await repository.getUsageStats()
        
        // Then
        #expect(stats.totalCost > 0)
        #expect(stats.totalTokens > 0)
        #expect(stats.totalSessions > 0)
    }
    
    @Test("Should return empty stats when no data exists")
    func testEmptyStats() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        // When
        let stats = try await repository.getUsageStats()
        
        // Then
        #expect(stats.totalCost == 0)
        #expect(stats.totalTokens == 0)
        #expect(stats.totalSessions == 0)
        #expect(stats.byDate.isEmpty)
    }
    
    @Test("Should load entries for specific date")
    func testLoadEntriesForDate() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupMockProjectData()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        let targetDate = Date()
        
        // When
        let entries = try await repository.loadEntriesForDate(targetDate)
        
        // Then
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: targetDate)
        
        for entry in entries {
            if let entryDate = entry.date {
                let entryDay = calendar.startOfDay(for: entryDate)
                #expect(entryDay == targetDay)
            }
        }
    }
    
    @Test("Should limit entries when specified")
    func testGetUsageEntriesWithLimit() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupLargeDataset()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        let limit = 10
        
        // When
        let entries = try await repository.getUsageEntries(limit: limit)
        
        // Then
        #expect(entries.count <= limit)
    }
    
    @Test("Should handle concurrent file processing")
    func testConcurrentFileProcessing() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupMultipleProjects()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem,
            maxConcurrency: 4
        )
        
        // When
        let stats = try await repository.getUsageStats()
        
        // Then
        #expect(stats.byProject.count == 3)
        #expect(stats.totalSessions > 0)
    }
    
    @Test("Should deduplicate entries correctly")
    func testDeduplication() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupDuplicateData()
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        // When
        let stats = try await repository.getUsageStats()
        
        // Then
        // Should have deduplicated the entries
        #expect(stats.totalCost > 0)
        // Note: totalSessions counts unique session files (session1.jsonl, session2.jsonl), 
        // not the session IDs within the JSON data
        #expect(stats.totalSessions == 2) // Two different session files
    }
    
    @Test("Should handle file system errors gracefully")
    func testFileSystemError() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        // Setup a project structure first so contentsOfDirectory can throw an error
        await mockFileSystem.setupProjectsFolder()
        await mockFileSystem.setThrowError(true)
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem
        )
        
        // When/Then
        await #expect(throws: (any Error).self) {
            _ = try await repository.getUsageStats()
        }
    }
    
    @Test("Should stream process large datasets efficiently")
    func testStreamProcessing() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setupLargeDataset(fileCount: 100)
        
        let repository = AsyncUsageRepository(
            basePath: "/test",
            fileSystem: mockFileSystem,
            maxConcurrency: 8
        )
        
        // When
        let startTime = Date()
        let stats = try await repository.getUsageStats()
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        #expect(stats.totalSessions == 100)
        #expect(duration < 5.0) // Should complete quickly even with many files
    }
}

// MARK: - Mock Async File System

private actor MockAsyncFileSystem: AsyncFileSystemProtocol {
    var mockFiles: [String: String] = [:]
    private var shouldThrowError = false
    
    func setThrowError(_ value: Bool) {
        shouldThrowError = value
    }
    
    func fileExists(atPath path: String) async -> Bool {
        return mockFiles.keys.contains(path) ||
               mockFiles.keys.contains { $0.hasPrefix(path + "/") }
    }
    
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        if shouldThrowError {
            throw MockError.directoryNotFound
        }
        
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let files = mockFiles.keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { filePath in
                let remaining = filePath.replacingOccurrences(of: prefix, with: "")
                return remaining.components(separatedBy: "/").first
            }
        
        return Array(Set(files))
    }
    
    func readFile(atPath path: String) async throws -> String {
        if shouldThrowError {
            throw MockError.fileNotFound
        }

        guard let content = mockFiles[path] else {
            throw MockError.fileNotFound
        }

        // Simulate async delay
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms

        return content
    }

    func readFirstLine(atPath path: String) async throws -> String? {
        if shouldThrowError {
            throw MockError.fileNotFound
        }

        guard let content = mockFiles[path] else {
            throw MockError.fileNotFound
        }

        return content.components(separatedBy: .newlines).first
    }

    func setupMockProjectData() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let jsonLine = """
        {"timestamp":"\(timestamp)","message":{"id":"msg_123","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":10,"cache_read_input_tokens":5}},"sessionId":"session1","requestId":"req_456"}
        """
        
        mockFiles["/test/projects"] = ""
        mockFiles["/test/projects/project1"] = ""
        mockFiles["/test/projects/project1/session1.jsonl"] = jsonLine
    }
    
    func setupLargeDataset(fileCount: Int = 50) {
        mockFiles["/test/projects"] = ""
        
        for i in 0..<fileCount {
            let projectDir = "project\(i % 5)"
            let sessionFile = "session\(i).jsonl"
            let timestamp = ISO8601DateFormatter().string(from: Date())
            
            let jsonLine = """
            {"timestamp":"\(timestamp)","message":{"id":"msg_\(i)","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"sessionId":"session\(i)","requestId":"req_\(i)"}
            """
            
            mockFiles["/test/projects/\(projectDir)"] = ""
            mockFiles["/test/projects/\(projectDir)/\(sessionFile)"] = jsonLine
        }
    }
    
    func setupMultipleProjects() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let jsonLine = """
        {"timestamp":"\(timestamp)","message":{"id":"msg_1","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"sessionId":"session1","requestId":"req_1"}
        """
        
        mockFiles["/test/projects"] = ""
        mockFiles["/test/projects/project1"] = ""
        mockFiles["/test/projects/project1/session1.jsonl"] = jsonLine
        mockFiles["/test/projects/project2"] = ""
        mockFiles["/test/projects/project2/session2.jsonl"] = jsonLine
        mockFiles["/test/projects/project3"] = ""
        mockFiles["/test/projects/project3/session3.jsonl"] = jsonLine
    }
    
    func setupDuplicateData() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let jsonLine = """
        {"timestamp":"\(timestamp)","message":{"id":"msg_123","model":"claude-3-5-sonnet-20241022","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"sessionId":"session1","requestId":"req_456"}
        """
        
        mockFiles["/test/projects"] = ""
        mockFiles["/test/projects/project1"] = ""
        // Same content in multiple files - should be deduplicated
        mockFiles["/test/projects/project1/session1.jsonl"] = jsonLine + "\n" + jsonLine
        mockFiles["/test/projects/project1/session2.jsonl"] = jsonLine
    }
    
    func setupProjectsFolder() {
        mockFiles["/test/projects"] = ""
        mockFiles["/test/projects/project1"] = ""
    }
    
    private enum MockError: Error {
        case fileNotFound
        case directoryNotFound
    }
}