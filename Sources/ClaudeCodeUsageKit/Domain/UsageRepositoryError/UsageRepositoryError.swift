//
//  UsageRepositoryError.swift
//  ClaudeCodeUsage
//
//  Comprehensive error types for better error handling
//
//  Split into extensions for focused responsibilities:
//    - +Recovery: Recovery strategies and execution
//    - +Aggregator: Error aggregation for batch operations
//

import Foundation

// MARK: - Usage Repository Error

/// Comprehensive error types for UsageRepository operations
public enum UsageRepositoryError: LocalizedError {
    case invalidPath(String)
    case directoryNotFound(path: String)
    case fileReadFailed(path: String, underlyingError: Error)
    case parsingFailed(file: String, line: Int?, reason: String)
    case batchProcessingFailed(batch: Int, filesProcessed: Int, error: Error)
    case decodingFailed(path: String, error: Error)
    case permissionDenied(path: String)
    case quotaExceeded(limit: Int, attempted: Int)
    case corruptedData(file: String, details: String)
    case networkError(Error)
    case timeout(operation: String, duration: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid path: '\(path)'. Please ensure the path exists and is accessible."

        case .directoryNotFound(let path):
            return "Directory not found: '\(path)'. Check if Claude Code data exists at this location."

        case .fileReadFailed(let path, let error):
            return "Failed to read file at '\(path)': \(error.localizedDescription)"

        case .parsingFailed(let file, let line, let reason):
            if let line = line {
                return "Failed to parse '\(file)' at line \(line): \(reason)"
            } else {
                return "Failed to parse '\(file)': \(reason)"
            }

        case .batchProcessingFailed(let batch, let filesProcessed, let error):
            return "Batch \(batch) failed after processing \(filesProcessed) files: \(error.localizedDescription)"

        case .decodingFailed(let path, let error):
            return "Failed to decode data from '\(path)': \(error.localizedDescription)"

        case .permissionDenied(let path):
            return "Permission denied accessing '\(path)'. Please check file permissions."

        case .quotaExceeded(let limit, let attempted):
            return "Quota exceeded: attempted to process \(attempted) items (limit: \(limit))"

        case .corruptedData(let file, let details):
            return "Corrupted data in '\(file)': \(details)"

        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"

        case .timeout(let operation, let duration):
            return "Operation '\(operation)' timed out after \(String(format: "%.2f", duration)) seconds"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidPath, .directoryNotFound:
            return "Ensure Claude Code is installed and has been used at least once."

        case .fileReadFailed, .permissionDenied:
            return "Check file permissions and ensure the application has read access to the Claude Code data directory."

        case .parsingFailed, .decodingFailed, .corruptedData:
            return "The data file may be corrupted. Try removing the affected file and letting Claude Code regenerate it."

        case .batchProcessingFailed:
            return "Some files could not be processed. Try reducing the batch size or processing fewer files at once."

        case .quotaExceeded:
            return "Too many items to process. Try filtering the data or processing in smaller chunks."

        case .networkError:
            return "Check your internet connection and try again."

        case .timeout:
            return "The operation took too long. Try processing fewer items or check system resources."
        }
    }

    /// Whether this error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .networkError, .timeout, .batchProcessingFailed:
            return true
        case .invalidPath, .directoryNotFound, .permissionDenied:
            return false
        case .fileReadFailed, .parsingFailed, .decodingFailed, .corruptedData:
            return true // Can skip bad files and continue
        case .quotaExceeded:
            return true // Can process fewer items
        }
    }

    /// Suggested retry delay if recoverable
    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .networkError:
            return 2.0
        case .timeout:
            return 5.0
        case .batchProcessingFailed:
            return 1.0
        default:
            return nil
        }
    }
}

// MARK: - Error Context

/// Error context for detailed debugging
public struct ErrorContext: Sendable {
    public let file: String
    public let function: String
    public let line: Int
    public let additionalInfo: [String: String]

    public init(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        additionalInfo: [String: String] = [:]
    ) {
        self.file = URL(fileURLWithPath: file).lastPathComponent
        self.function = function
        self.line = line
        self.additionalInfo = additionalInfo
    }

    public var description: String {
        var desc = "[\(file):\(line)] in \(function)"
        if !additionalInfo.isEmpty {
            let info = additionalInfo.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            desc += " | \(info)"
        }
        return desc
    }
}

// MARK: - Enhanced Error

/// Enhanced error with context
public struct EnhancedError: LocalizedError, @unchecked Sendable {
    public let baseError: Error
    public let context: ErrorContext

    public init(_ error: Error, context: ErrorContext) {
        self.baseError = error
        self.context = context
    }

    public var errorDescription: String? {
        if let localizedError = baseError as? LocalizedError {
            return localizedError.errorDescription
        }
        return baseError.localizedDescription
    }

    public var failureReason: String? {
        context.description
    }
}

// MARK: - Result Extension

public extension Result {
    /// Convert Result to async throwing
    func asyncGet() async throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Task Extension

public extension Task where Failure == Error {
    /// Retry a task with exponential backoff
    static func retrying(
        maxRetryCount: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping @Sendable () async throws -> Success
    ) async throws -> Success {
        try await RetryExecutor.execute(
            operation: operation,
            maxRetryCount: maxRetryCount,
            initialDelay: initialDelay
        )
    }
}
