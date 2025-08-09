//
//  AsyncCircuitBreakerTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for AsyncCircuitBreakerFileSystem
//

import Testing
import Foundation
@testable import ClaudeCodeUsage

@Suite("AsyncCircuitBreakerFileSystem Tests")
struct AsyncCircuitBreakerTests {
    
    @Test("Should pass through successful operations when circuit is closed")
    func testCircuitClosedSuccess() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.addFile(path: "/test/file.txt", content: "test content")
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 1.0
            )
        )
        
        // When
        let exists = await circuitBreaker.fileExists(atPath: "/test/file.txt")
        let content = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        
        // Then
        #expect(exists == true)
        #expect(content == "test content")
    }
    
    @Test("Should open circuit after failure threshold")
    func testCircuitOpensAfterFailures() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setFailureCount(3)
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 0.1
            )
        )
        
        // When - Trigger failures to open circuit
        for _ in 0..<3 {
            _ = try? await circuitBreaker.readFile(atPath: "/failing/path")
        }
        
        // Then - Circuit should be open, rejecting requests
        await #expect(throws: CircuitBreakerError.self) {
            _ = try await circuitBreaker.readFile(atPath: "/any/path")
        }
    }
    
    @Test("Should transition to half-open after reset timeout")
    func testCircuitHalfOpenTransition() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setFailureCount(3)
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 0.1 // Short reset for testing
            )
        )
        
        // When - Open the circuit
        for _ in 0..<3 {
            _ = try? await circuitBreaker.readFile(atPath: "/failing/path")
        }
        
        // Wait for reset timeout
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Now it should allow a test request (half-open)
        await mockFileSystem.setFailureCount(0) // Stop failing
        await mockFileSystem.addFile(path: "/test/file.txt", content: "content")
        
        // Then - Should allow request in half-open state
        let content = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(content == "content")
    }
    
    @Test("Should close circuit after success threshold in half-open")
    func testCircuitClosesAfterRecovery() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setFailureCount(3)
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 0.1
            )
        )
        
        // Open the circuit
        for _ in 0..<3 {
            _ = try? await circuitBreaker.readFile(atPath: "/failing/path")
        }
        
        // Wait for reset timeout
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // When - Succeed multiple times to close circuit
        await mockFileSystem.setFailureCount(0)
        await mockFileSystem.addFile(path: "/test/file.txt", content: "content")
        
        for _ in 0..<2 {
            _ = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        }
        
        // Then - Circuit should be closed, allowing normal operation
        let content = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(content == "content")
    }
    
    @Test("Should handle directory operations through circuit breaker")
    func testDirectoryOperations() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.addFile(path: "/dir/file1.txt", content: "content1")
        await mockFileSystem.addFile(path: "/dir/file2.txt", content: "content2")
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem
        )
        
        // When
        let contents = try await circuitBreaker.contentsOfDirectory(atPath: "/dir")
        
        // Then
        #expect(contents.contains("file1.txt"))
        #expect(contents.contains("file2.txt"))
    }
    
    @Test("Should handle non-throwing operations")
    func testNonThrowingOperations() async {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.addFile(path: "/existing/file.txt", content: "exists")
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem
        )
        
        // When
        let exists = await circuitBreaker.fileExists(atPath: "/existing/file.txt")
        let notExists = await circuitBreaker.fileExists(atPath: "/missing/file.txt")
        
        // Then
        #expect(exists == true)
        #expect(notExists == false)
    }
    
    @Test("Should handle circuit breaker reset timeout behavior")
    func testCircuitResetTimeout() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.setFailureCount(3)
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 0.1 // Short timeout for testing
            )
        )
        
        // Open the circuit
        for _ in 0..<3 {
            _ = try? await circuitBreaker.readFile(atPath: "/failing/path")
        }
        
        // Verify circuit is open
        await #expect(throws: CircuitBreakerError.self) {
            _ = try await circuitBreaker.readFile(atPath: "/any/path")
        }
        
        // Wait for reset timeout to allow retry
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // When - After reset timeout, circuit should allow retry
        await mockFileSystem.setFailureCount(0)
        await mockFileSystem.addFile(path: "/test/file.txt", content: "content")
        
        // Then - Should successfully read after reset timeout
        let content = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(content == "content")
    }
    
    @Test("Should handle concurrent operations correctly")
    func testConcurrentOperations() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        for i in 0..<10 {
            await mockFileSystem.addFile(path: "/file\(i).txt", content: "content\(i)")
        }
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem
        )
        
        // When - Multiple concurrent reads
        let results = await withTaskGroup(of: String?.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try? await circuitBreaker.readFile(atPath: "/file\(i).txt")
                }
            }
            
            var results: [String] = []
            for await result in group {
                if let content = result {
                    results.append(content)
                }
            }
            return results
        }
        
        // Then
        #expect(results.count == 10)
        for i in 0..<10 {
            #expect(results.contains("content\(i)"))
        }
    }
    
    @Test("Should track circuit breaker state")
    func testCircuitStateTracking() async throws {
        // Given
        let mockFileSystem = MockAsyncFileSystem()
        await mockFileSystem.addFile(path: "/test/file.txt", content: "content")
        
        let circuitBreaker = AsyncCircuitBreakerFileSystem(
            fileSystem: mockFileSystem,
            configuration: CircuitBreakerConfiguration(
                failureThreshold: 3,
                successThreshold: 2,
                timeout: 10.0,
                resetTimeout: 0.1
            )
        )
        
        // Initially closed - verify by successful operation
        let testContent = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(testContent == "content")
        
        // Trigger failures to open the circuit
        await mockFileSystem.setFailureCount(3)
        for _ in 0..<3 {
            _ = try? await circuitBreaker.readFile(atPath: "/test/file.txt")
        }
        
        // Circuit should be open - verify by failure
        await #expect(throws: CircuitBreakerError.self) {
            _ = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        }
        
        // Wait for reset timeout
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Prepare for recovery
        await mockFileSystem.setFailureCount(0)
        
        // Circuit should allow retry after timeout
        let recoveredContent = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(recoveredContent == "content")
        
        // Verify circuit is working again
        let finalContent = try await circuitBreaker.readFile(atPath: "/test/file.txt")
        #expect(finalContent == "content")
    }
}

// MARK: - Mock Async File System

private actor MockAsyncFileSystem: AsyncFileSystemProtocol {
    private var files: [String: String] = [:]
    private var shouldFailNTimes: Int = 0
    private var failureCount: Int = 0
    
    func addFile(path: String, content: String) {
        files[path] = content
    }
    
    func setFailureCount(_ count: Int) {
        shouldFailNTimes = count
        failureCount = 0
    }
    
    func fileExists(atPath path: String) async -> Bool {
        return files.keys.contains(path) ||
               files.keys.contains { $0.hasPrefix(path + "/") }
    }
    
    func contentsOfDirectory(atPath path: String) async throws -> [String] {
        if shouldFailNTimes > 0 && failureCount < shouldFailNTimes {
            failureCount += 1
            throw MockError.operationFailed
        }
        
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let contents = files.keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { filePath in
                let remaining = filePath.replacingOccurrences(of: prefix, with: "")
                return remaining.components(separatedBy: "/").first
            }
        
        return Array(Set(contents))
    }
    
    func readFile(atPath path: String) async throws -> String {
        if shouldFailNTimes > 0 && failureCount < shouldFailNTimes {
            failureCount += 1
            throw MockError.operationFailed
        }
        
        guard let content = files[path] else {
            throw MockError.fileNotFound
        }
        
        return content
    }
    
    private enum MockError: Error {
        case fileNotFound
        case operationFailed
    }
}