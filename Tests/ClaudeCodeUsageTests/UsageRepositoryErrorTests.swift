//
//  UsageRepositoryErrorTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for comprehensive error handling
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit

@Suite("UsageRepositoryError Tests")
struct UsageRepositoryErrorTests {
    
    // MARK: - Error Description Tests
    
    @Test("Should provide descriptive error messages")
    func testErrorDescriptions() {
        // Given
        let errors: [UsageRepositoryError] = [
            .invalidPath("/invalid/path"),
            .directoryNotFound(path: "/missing"),
            .fileReadFailed(path: "/file.txt", underlyingError: NSError(domain: "test", code: 1)),
            .parsingFailed(file: "data.json", line: 42, reason: "invalid JSON"),
            .batchProcessingFailed(batch: 3, filesProcessed: 10, error: NSError(domain: "test", code: 2)),
            .permissionDenied(path: "/private"),
            .quotaExceeded(limit: 100, attempted: 150),
            .corruptedData(file: "corrupt.json", details: "unexpected EOF"),
            .timeout(operation: "fetch", duration: 30.5)
        ]
        
        // Then
        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(!description!.isEmpty)
        }
    }
    
    @Test("Should provide recovery suggestions")
    func testRecoverySuggestions() {
        // Given
        let errors: [UsageRepositoryError] = [
            .invalidPath("/path"),
            .fileReadFailed(path: "/file", underlyingError: NSError(domain: "test", code: 1)),
            .parsingFailed(file: "file", line: nil, reason: "error"),
            .batchProcessingFailed(batch: 1, filesProcessed: 5, error: NSError(domain: "test", code: 2)),
            .quotaExceeded(limit: 10, attempted: 20),
            .networkError(NSError(domain: "network", code: 3)),
            .timeout(operation: "op", duration: 10)
        ]
        
        // Then
        for error in errors {
            let suggestion = error.recoverySuggestion
            #expect(suggestion != nil)
            #expect(!suggestion!.isEmpty)
        }
    }
    
    @Test("Should identify recoverable errors")
    func testRecoverableErrors() {
        // Given
        let recoverableErrors: [UsageRepositoryError] = [
            .networkError(NSError(domain: "test", code: 1)),
            .timeout(operation: "test", duration: 5),
            .batchProcessingFailed(batch: 1, filesProcessed: 0, error: NSError(domain: "test", code: 2)),
            .fileReadFailed(path: "/file", underlyingError: NSError(domain: "test", code: 3)),
            .quotaExceeded(limit: 100, attempted: 200)
        ]
        
        let nonRecoverableErrors: [UsageRepositoryError] = [
            .invalidPath("/path"),
            .directoryNotFound(path: "/missing"),
            .permissionDenied(path: "/private")
        ]
        
        // Then
        for error in recoverableErrors {
            #expect(error.isRecoverable == true)
        }
        
        for error in nonRecoverableErrors {
            #expect(error.isRecoverable == false)
        }
    }
    
    @Test("Should suggest retry delays")
    func testRetryDelays() {
        // Given
        let errorsWithDelay: [(UsageRepositoryError, TimeInterval?)] = [
            (.networkError(NSError(domain: "test", code: 1)), 2.0),
            (.timeout(operation: "test", duration: 10), 5.0),
            (.batchProcessingFailed(batch: 1, filesProcessed: 0, error: NSError(domain: "test", code: 2)), 1.0),
            (.invalidPath("/path"), nil),
            (.permissionDenied(path: "/private"), nil)
        ]
        
        // Then
        for (error, expectedDelay) in errorsWithDelay {
            #expect(error.suggestedRetryDelay == expectedDelay)
        }
    }
    
    // MARK: - Error Context Tests
    
    @Test("Should create error context correctly")
    func testErrorContext() {
        // Given
        let context = ErrorContext(
            file: "/path/to/file.swift",
            function: "testFunction()",
            line: 42,
            additionalInfo: ["key": "value", "count": 10]
        )
        
        // Then
        #expect(context.file == "file.swift")
        #expect(context.function == "testFunction()")
        #expect(context.line == 42)
        #expect(context.additionalInfo["key"] as? String == "value")
        #expect(context.additionalInfo["count"] as? Int == 10)
        
        let description = context.description
        #expect(description.contains("file.swift"))
        #expect(description.contains("42"))
        #expect(description.contains("testFunction"))
    }
    
    @Test("Should create enhanced error with context")
    func testEnhancedError() {
        // Given
        let baseError = UsageRepositoryError.invalidPath("/test")
        let context = ErrorContext(file: "test.swift", function: "test()", line: 10)
        let enhancedError = EnhancedError(baseError, context: context)
        
        // Then
        #expect(enhancedError.errorDescription != nil)
        #expect(enhancedError.failureReason != nil)
        #expect(enhancedError.failureReason!.contains("test.swift"))
    }
    
    // MARK: - Error Recovery Strategy Tests
    
    @Test("Should execute retry strategy")
    func testRetryStrategy() async throws {
        // Given
        var attemptCount = 0
        let strategy = ErrorRecoveryStrategy.retry(maxAttempts: 3, delay: 0.01)
        
        // When - Operation that fails twice then succeeds
        let result = try await strategy.execute(
            operation: {
                attemptCount += 1
                if attemptCount < 3 {
                    throw TestError.temporary
                }
                return 42
            },
            onError: { _ in }
        )
        
        // Then
        #expect(result == 42)
        #expect(attemptCount == 3)
    }
    
    @Test("Should fail after max retry attempts")
    func testRetryStrategyFailure() async {
        // Given
        let strategy = ErrorRecoveryStrategy.retry(maxAttempts: 2, delay: 0.01)
        var errorCount = 0
        
        // When/Then
        await #expect(throws: TestError.self) {
            _ = try await strategy.execute(
                operation: {
                    throw TestError.permanent
                },
                onError: { _ in
                    errorCount += 1
                }
            )
        }
        
        #expect(errorCount == 2)
    }
    
    @Test("Should execute skip strategy")
    func testSkipStrategy() async throws {
        // Given
        let strategy = ErrorRecoveryStrategy.skip
        var errorHandled = false
        
        // When
        let result = try await strategy.execute(
            operation: {
                throw TestError.temporary
            },
            onError: { _ in
                errorHandled = true
            }
        )
        
        // Then
        #expect(result == nil)
        #expect(errorHandled == true)
    }
    
    @Test("Should execute fallback strategy")
    func testFallbackStrategy() async throws {
        // Given
        var fallbackExecuted = false
        let strategy = ErrorRecoveryStrategy.fallback {
            fallbackExecuted = true
        }
        
        // When
        let result = try await strategy.execute(
            operation: {
                throw TestError.temporary
            },
            onError: { _ in }
        )
        
        // Then
        #expect(result == nil)
        #expect(fallbackExecuted == true)
    }
    
    @Test("Should abort on error with abort strategy")
    func testAbortStrategy() async {
        // Given
        let strategy = ErrorRecoveryStrategy.abort
        
        // When/Then
        await #expect(throws: TestError.self) {
            _ = try await strategy.execute(
                operation: {
                    throw TestError.permanent
                },
                onError: { _ in }
            )
        }
    }
    
    // MARK: - Error Aggregator Tests
    
    @Test("Should aggregate errors")
    func testErrorAggregator() async {
        // Given
        let aggregator = ErrorAggregator(maxErrors: 5)
        
        // When
        await aggregator.record(TestError.temporary)
        await aggregator.record(TestError.permanent)
        await aggregator.record(UsageRepositoryError.invalidPath("/test"))
        
        // Then
        let errors = await aggregator.getErrors()
        #expect(errors.count == 3)
        #expect(await aggregator.hasErrors() == true)
    }
    
    @Test("Should limit aggregated errors")
    func testErrorAggregatorLimit() async {
        // Given
        let aggregator = ErrorAggregator(maxErrors: 3)
        
        // When - Add more than max
        for i in 1...5 {
            await aggregator.record(TestError.numbered(i))
        }
        
        // Then
        let errors = await aggregator.getErrors()
        #expect(errors.count == 3)
    }
    
    @Test("Should generate error summary")
    func testErrorSummary() async {
        // Given
        let aggregator = ErrorAggregator()
        
        await aggregator.record(TestError.temporary)
        await aggregator.record(TestError.temporary)
        await aggregator.record(TestError.permanent)
        await aggregator.record(UsageRepositoryError.invalidPath("/test"))
        
        // When
        let summary = await aggregator.getSummary()
        
        // Then
        #expect(summary.contains("Error Summary"))
        #expect(summary.contains("4 total"))
        #expect(summary.contains("TestError"))
        #expect(summary.contains("UsageRepositoryError"))
    }
    
    @Test("Should clear aggregated errors")
    func testClearErrors() async {
        // Given
        let aggregator = ErrorAggregator()
        await aggregator.record(TestError.temporary)
        
        // When
        await aggregator.clear()
        
        // Then
        #expect(await aggregator.hasErrors() == false)
        #expect(await aggregator.getErrors().isEmpty)
    }
    
    // MARK: - Task Retry Extension Tests
    
    @Test("Should retry task with exponential backoff")
    func testTaskRetrying() async throws {
        // Given
        var attemptCount = 0
        
        // When
        let result = try await Task.retrying(
            maxRetryCount: 3,
            initialDelay: 0.01
        ) {
            attemptCount += 1
            if attemptCount < 2 {
                throw TestError.temporary
            }
            return "success"
        }
        
        // Then
        #expect(result == "success")
        #expect(attemptCount == 2)
    }
    
    @Test("Should fail task after max retries")
    func testTaskRetryingFailure() async {
        // Given
        var attemptCount = 0
        
        // When/Then
        await #expect(throws: TestError.self) {
            _ = try await Task.retrying(
                maxRetryCount: 2,
                initialDelay: 0.01
            ) {
                attemptCount += 1
                throw TestError.permanent
            }
        }
        
        #expect(attemptCount == 2)
    }
}

// MARK: - Test Helpers

private enum TestError: Error, Equatable {
    case temporary
    case permanent
    case numbered(Int)
}