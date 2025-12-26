//
//  TestUtilities.swift
//  Testing utilities and supporting types for TDD tests
//

import Foundation

// MARK: - Retry Infrastructure

/// Exponential backoff retry policy
public struct ExponentialBackoff {
    public let maxRetries: Int
    public let baseDelay: TimeInterval
    
    public init(maxRetries: Int = 3, baseDelay: TimeInterval = 0.1) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }
    
    public func delay(for attempt: Int) -> TimeInterval {
        return baseDelay * pow(2.0, Double(attempt))
    }
}

// MARK: - Test Data Structures

/// Extended UsageEntry initializer for testing
extension UsageEntry {
    public init(
        id: String = UUID().uuidString,
        timestamp: Date,
        cost: Double,
        model: String = "test-model",
        inputTokens: Int = 100,
        outputTokens: Int = 50,
        cacheWriteTokens: Int = 0,
        cacheReadTokens: Int = 0,
        sessionId: String? = nil
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        self.init(
            project: "test-project",
            timestamp: formatter.string(from: timestamp),
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheWriteTokens: cacheWriteTokens,
            cacheReadTokens: cacheReadTokens,
            cost: cost,
            sessionId: sessionId
        )
    }
}

// MARK: - UsageEntry Extensions

extension UsageEntry {
    /// Safe method to sanitize extreme values for testing
    public func sanitized() -> UsageEntry {
        let maxCost = 999_999.99
        let maxTokens = 1_000_000_000
        
        let sanitizedCost = cost.isInfinite || cost.isNaN ? maxCost : min(cost, maxCost)
        let sanitizedInputTokens = min(inputTokens, maxTokens)
        let sanitizedOutputTokens = min(outputTokens, maxTokens)
        let sanitizedCacheWrite = min(cacheWriteTokens, maxTokens)
        let sanitizedCacheRead = min(cacheReadTokens, maxTokens)
        
        return UsageEntry(
            project: project,
            timestamp: timestamp,
            model: model,
            inputTokens: sanitizedInputTokens,
            outputTokens: sanitizedOutputTokens,
            cacheWriteTokens: sanitizedCacheWrite,
            cacheReadTokens: sanitizedCacheRead,
            cost: sanitizedCost,
            sessionId: sessionId
        )
    }
}

// MARK: - Supporting Types for Error Tests

/// Mock usage data parser for testing data corruption scenarios
public final class MockUsageDataParser {
    public var corruptFiles: [String] = []
    public var validFiles: [String: String] = [:]
    public var skippedFiles: [String] = []
    
    public init() {}
    
    public func parse(_ jsonString: String) -> UsageEntry? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(UsageEntry.self, from: data)
    }
}

/// Valid usage data helper for tests
public func validUsageData() -> String {
    return """
    {
        "project": "test-project",
        "timestamp": "2025-01-15T14:30:00Z",
        "model": "claude-3",
        "input_tokens": 100,
        "output_tokens": 50,
        "cache_write_tokens": 0,
        "cache_read_tokens": 0,
        "cost": 10.0,
        "session_id": "test-session"
    }
    """
}