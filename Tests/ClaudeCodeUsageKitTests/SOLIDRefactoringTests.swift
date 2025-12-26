//
//  SOLIDRefactoringTests.swift
//  ClaudeCodeUsage Tests
//
//  Unit tests for SOLID refactoring components
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit

@Suite("SOLID Refactoring Tests")
struct SOLIDRefactoringTests {
    
    // MARK: - FileSystem Tests
    
    @Test("Mock file system returns correct files")
    func mockFileSystemReturnsCorrectFiles() {
        // Given
        let mockFS = MockFileSystem(
            files: [
                "/test/file1.txt": "content1",
                "/test/file2.txt": "content2"
            ],
            directories: [
                "/test": ["file1.txt", "file2.txt"]
            ]
        )
        
        // When
        let exists = mockFS.fileExists(atPath: "/test/file1.txt")
        let content = try? mockFS.readFile(atPath: "/test/file1.txt")
        let dirContents = try? mockFS.contentsOfDirectory(atPath: "/test")
        
        // Then
        #expect(exists)
        #expect(content == "content1")
        #expect(dirContents?.count == 2)
    }
    
    @Test("Mock file system throws for missing files")
    func mockFileSystemThrowsForMissingFiles() {
        // Given
        let mockFS = MockFileSystem()
        
        // When/Then
        #expect(throws: (any Error).self) {
            try mockFS.readFile(atPath: "/nonexistent")
        }
        #expect(throws: (any Error).self) {
            try mockFS.contentsOfDirectory(atPath: "/nonexistent")
        }
    }
    
    // MARK: - Parser Tests
    
    @Test("JSONL parser extracts usage data")
    func jsonLParserExtractsUsageData() throws {
        // Given
        let parser = JSONLUsageParser()
        let jsonLine = """
        {"timestamp":"2025-08-06T10:00:00Z","message":{"model":"claude-opus-4","usage":{"input_tokens":100,"output_tokens":200,"cache_creation_input_tokens":10,"cache_read_input_tokens":5}},"sessionId":"test123","requestId":"req123"}
        """
        
        // When
        let entry = try parser.parseJSONLLine(jsonLine, projectPath: "/test/project")
        
        // Then
        #expect(entry != nil)
        #expect(entry?.inputTokens == 100)
        #expect(entry?.outputTokens == 200)
        #expect(entry?.cacheWriteTokens == 10)
        #expect(entry?.cacheReadTokens == 5)
        #expect(entry?.model == "claude-opus-4")
    }
    
    @Test("Parser skips entries without tokens")
    func parserSkipsEntriesWithoutTokens() throws {
        // Given
        let parser = JSONLUsageParser()
        let jsonLine = """
        {"timestamp":"2025-08-06T10:00:00Z","message":{"model":"claude-opus-4","usage":{"input_tokens":0,"output_tokens":0}},"sessionId":"test123"}
        """
        
        // When
        let entry = try parser.parseJSONLLine(jsonLine, projectPath: "/test/project")
        
        // Then
        #expect(entry == nil)
    }
    
    @Test("Parser extracts identifiers")
    func parserExtractsIdentifiers() {
        // Given
        let parser = JSONLUsageParser()
        let json: [String: Any] = [
            "message": ["id": "msg123"],
            "requestId": "req456",
            "timestamp": "2025-08-06T10:00:00Z"
        ]
        
        // When
        let messageId = parser.extractMessageId(from: json)
        let requestId = parser.extractRequestId(from: json)
        let timestamp = parser.extractTimestamp(from: json)
        
        // Then
        #expect(messageId == "msg123")
        #expect(requestId == "req456")
        #expect(timestamp == "2025-08-06T10:00:00Z")
    }
    
    // MARK: - Deduplication Tests
    
    @Test("Hash-based deduplication prevents duplicates")
    func hashBasedDeduplicationPreventsDuplicates() {
        // Given
        let dedup = HashBasedDeduplication()
        
        // When
        let first = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        let duplicate = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        let different = dedup.shouldInclude(messageId: "msg2", requestId: "req2")
        
        // Then
        #expect(first)
        #expect(!duplicate)
        #expect(different)
    }
    
    @Test("Deduplication reset")
    func deduplicationReset() {
        // Given
        let dedup = HashBasedDeduplication()
        _ = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        
        // When
        dedup.reset()
        let afterReset = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        
        // Then
        #expect(afterReset)
    }
    
    @Test("No deduplication allows all")
    func noDeduplicationAllowsAll() {
        // Given
        let dedup = NoDeduplication()
        
        // When
        let first = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        let duplicate = dedup.shouldInclude(messageId: "msg1", requestId: "req1")
        
        // Then
        #expect(first)
        #expect(duplicate)
    }
    
    // MARK: - Path Decoder Tests
    
    @Test("Project path decoder handles leading dash")
    func projectPathDecoderHandlesLeadingDash() {
        // Given
        let decoder = ProjectPathDecoder()
        
        // When
        let decoded = decoder.decode("-Users-liang-Downloads")
        
        // Then
        #expect(decoded == "/Users/liang/Downloads")
    }
    
    @Test("Project path decoder handles no leading dash")
    func projectPathDecoderHandlesNoLeadingDash() {
        // Given
        let decoder = ProjectPathDecoder()
        
        // When
        let decoded = decoder.decode("Users-liang-Downloads")
        
        // Then
        #expect(decoded == "Users/liang/Downloads")
    }
    
    // MARK: - Statistics Aggregator Tests
    
    @Test("Statistics aggregator calculates totals")
    func statisticsAggregatorCalculatesTotals() {
        // Given
        let aggregator = StatisticsAggregator()
        let entries = [
            UsageEntry(
                project: "/test/project1",
                timestamp: "2025-08-06T10:00:00Z",
                model: "claude-opus-4",
                inputTokens: 100,
                outputTokens: 200,
                cacheWriteTokens: 10,
                cacheReadTokens: 5,
                cost: 1.5,
                sessionId: "session1"
            ),
            UsageEntry(
                project: "/test/project1",
                timestamp: "2025-08-06T11:00:00Z",
                model: "claude-opus-4",
                inputTokens: 150,
                outputTokens: 250,
                cacheWriteTokens: 15,
                cacheReadTokens: 8,
                cost: 2.0,
                sessionId: "session2"
            )
        ]
        
        // When
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: 2)
        
        // Then
        #expect(stats.totalCost == 3.5)
        #expect(stats.totalInputTokens == 250)
        #expect(stats.totalOutputTokens == 450)
        #expect(stats.totalCacheCreationTokens == 25)
        #expect(stats.totalCacheReadTokens == 13)
        #expect(stats.totalSessions == 2)
    }
    
    @Test("Statistics aggregator groups by model")
    func statisticsAggregatorGroupsByModel() {
        // Given
        let aggregator = StatisticsAggregator()
        let entries = [
            UsageEntry(
                project: "/test",
                timestamp: "2025-08-06T10:00:00Z",
                model: "claude-opus-4",
                inputTokens: 100,
                outputTokens: 200,
                cacheWriteTokens: 0,
                cacheReadTokens: 0,
                cost: 1.0,
                sessionId: "s1"
            ),
            UsageEntry(
                project: "/test",
                timestamp: "2025-08-06T11:00:00Z",
                model: "claude-sonnet-3.5",
                inputTokens: 50,
                outputTokens: 100,
                cacheWriteTokens: 0,
                cacheReadTokens: 0,
                cost: 0.5,
                sessionId: "s2"
            )
        ]
        
        // When
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: 2)
        
        // Then
        #expect(stats.byModel.count == 2)
        #expect(stats.byModel.contains { $0.model == "claude-opus-4" })
        #expect(stats.byModel.contains { $0.model == "claude-sonnet-3.5" })
    }
    
    // MARK: - Repository Integration Tests
    
    @Test("Repository with mock components")
    func repositoryWithMockComponents() async throws {
        // Given
        let mockFS = MockFileSystem(
            files: [
                "/test/.claude/projects/project1/session1.jsonl": """
                {"timestamp":"2025-08-06T10:00:00Z","message":{"id":"msg1","model":"claude-opus-4","usage":{"input_tokens":100,"output_tokens":200}},"requestId":"req1","sessionId":"session1"}
                {"timestamp":"2025-08-06T11:00:00Z","message":{"id":"msg2","model":"claude-opus-4","usage":{"input_tokens":150,"output_tokens":250}},"requestId":"req2","sessionId":"session1"}
                """
            ],
            directories: [
                "/test/.claude/projects": ["project1"],
                "/test/.claude/projects/project1": ["session1.jsonl"]
            ]
        )
        
        let repository = UsageRepository(
            fileSystem: mockFS,
            parser: JSONLUsageParser(),
            pathDecoder: ProjectPathDecoder(),
            aggregator: StatisticsAggregator(),
            basePath: "/test/.claude"
        )
        
        // When
        let stats = try await repository.getUsageStats()
        
        // Then
        #expect(stats.totalInputTokens == 250)
        #expect(stats.totalOutputTokens == 450)
        #expect(stats.totalSessions == 1)
    }
    
    // MARK: - Filter Service Tests
    
    @Test("Filter service filters date range")
    func filterServiceFiltersDateRange() {
        // Given
        let stats = UsageStats(
            totalCost: 100,
            totalTokens: 1000,
            totalInputTokens: 400,
            totalOutputTokens: 600,
            totalCacheCreationTokens: 0,
            totalCacheReadTokens: 0,
            totalSessions: 3,
            byModel: [],
            byDate: [
                DailyUsage(date: "2025-08-01", totalCost: 10, totalTokens: 100, modelsUsed: ["model1"]),
                DailyUsage(date: "2025-08-02", totalCost: 20, totalTokens: 200, modelsUsed: ["model1"]),
                DailyUsage(date: "2025-08-03", totalCost: 30, totalTokens: 300, modelsUsed: ["model1"]),
                DailyUsage(date: "2025-08-04", totalCost: 40, totalTokens: 400, modelsUsed: ["model1"])
            ],
            byProject: []
        )
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = formatter.date(from: "2025-08-02")!
        let endDate = formatter.date(from: "2025-08-03")!
        
        // When
        let filtered = FilterService.filterByDateRange(stats, start: startDate, end: endDate)
        
        // Then
        #expect(filtered.byDate.count == 2)
        #expect(filtered.totalCost == 50) // 20 + 30
        #expect(filtered.totalTokens == 500) // 200 + 300
    }
    
    // MARK: - Sorting Service Tests
    
    @Test("Sorting service sorts projects")
    func sortingServiceSortsProjects() {
        // Given
        let projects = [
            ProjectUsage(projectPath: "/p1", projectName: "p1", totalCost: 30, totalTokens: 300, sessionCount: 1, lastUsed: ""),
            ProjectUsage(projectPath: "/p2", projectName: "p2", totalCost: 10, totalTokens: 100, sessionCount: 1, lastUsed: ""),
            ProjectUsage(projectPath: "/p3", projectName: "p3", totalCost: 20, totalTokens: 200, sessionCount: 1, lastUsed: "")
        ]
        
        // When
        let ascending = SortingService.sortProjects(projects, order: .ascending)
        let descending = SortingService.sortProjects(projects, order: .descending)
        
        // Then
        #expect(ascending[0].totalCost == 10)
        #expect(ascending[1].totalCost == 20)
        #expect(ascending[2].totalCost == 30)
        
        #expect(descending[0].totalCost == 30)
        #expect(descending[1].totalCost == 20)
        #expect(descending[2].totalCost == 10)
    }
}