//
//  TypedErrors.swift
//  Swift 6 Typed Errors for better error handling
//

import Foundation

// MARK: - Base Error Protocol

/// Base protocol for all typed errors in the application
public protocol ClaudeUsageError: Error, Sendable {
    var errorDescription: String { get }
    var recoverySuggestion: String? { get }
}

// MARK: - Data Loading Errors

/// Errors that can occur when loading usage data
public enum DataLoadingError: ClaudeUsageError, Equatable {
    case fileNotFound(path: String)
    case invalidJSON(file: String, underlyingError: String)
    case permissionDenied(path: String)
    case corruptedData(reason: String)
    case networkUnavailable
    case rateLimited(retryAfter: TimeInterval)
    
    public var errorDescription: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .invalidJSON(let file, let error):
            return "Invalid JSON in file \(file): \(error)"
        case .permissionDenied(let path):
            return "Permission denied accessing: \(path)"
        case .corruptedData(let reason):
            return "Data corruption detected: \(reason)"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Ensure Claude desktop app is installed and has been used"
        case .invalidJSON:
            return "Try removing the corrupted file and refreshing"
        case .permissionDenied:
            return "Check file permissions or run with appropriate access"
        case .corruptedData:
            return "Clear cache and reload data"
        case .networkUnavailable:
            return "Check your internet connection"
        case .rateLimited(let retryAfter):
            return "Wait \(Int(retryAfter)) seconds before retrying"
        }
    }
}

// MARK: - Repository Errors

/// Errors specific to repository operations
public enum TypedRepositoryError: ClaudeUsageError, Equatable {
    case invalidDateRange(start: Date, end: Date)
    case noDataAvailable
    case aggregationFailed(reason: String)
    case cacheExpired
    case concurrentModification
    
    public var errorDescription: String {
        switch self {
        case .invalidDateRange(let start, let end):
            return "Invalid date range: \(start) to \(end)"
        case .noDataAvailable:
            return "No usage data available"
        case .aggregationFailed(let reason):
            return "Failed to aggregate data: \(reason)"
        case .cacheExpired:
            return "Cache has expired"
        case .concurrentModification:
            return "Data was modified by another process"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidDateRange:
            return "Ensure start date is before end date"
        case .noDataAvailable:
            return "Start using Claude to generate usage data"
        case .aggregationFailed:
            return "Try refreshing the data"
        case .cacheExpired:
            return "Refresh to load latest data"
        case .concurrentModification:
            return "Retry the operation"
        }
    }
}

// MARK: - Session Monitoring Errors

/// Errors related to live session monitoring
public enum SessionMonitorError: ClaudeUsageError, Equatable {
    case monitorNotStarted
    case sessionTimeout
    case invalidSessionData(reason: String)
    case tokenLimitExceeded(limit: Int, used: Int)
    
    public var errorDescription: String {
        switch self {
        case .monitorNotStarted:
            return "Session monitor is not running"
        case .sessionTimeout:
            return "Session has timed out"
        case .invalidSessionData(let reason):
            return "Invalid session data: \(reason)"
        case .tokenLimitExceeded(let limit, let used):
            return "Token limit exceeded: \(used)/\(limit)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .monitorNotStarted:
            return "Start the session monitor first"
        case .sessionTimeout:
            return "Start a new session"
        case .invalidSessionData:
            return "Check session data format"
        case .tokenLimitExceeded:
            return "Consider increasing token limit or starting a new session"
        }
    }
}

// MARK: - Configuration Errors

/// Errors related to app configuration
public enum ConfigurationError: ClaudeUsageError, Equatable {
    case missingRequiredField(field: String)
    case invalidValue(field: String, value: String)
    case incompatibleVersion(required: String, current: String)
    case environmentVariableNotSet(name: String)
    
    public var errorDescription: String {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required configuration field: \(field)"
        case .invalidValue(let field, let value):
            return "Invalid value '\(value)' for field: \(field)"
        case .incompatibleVersion(let required, let current):
            return "Incompatible version. Required: \(required), Current: \(current)"
        case .environmentVariableNotSet(let name):
            return "Environment variable not set: \(name)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Add \(field) to your configuration"
        case .invalidValue(let field, _):
            return "Check the documentation for valid \(field) values"
        case .incompatibleVersion(let required, _):
            return "Update to version \(required) or later"
        case .environmentVariableNotSet(let name):
            return "Set the \(name) environment variable"
        }
    }
}

// MARK: - UI Errors

/// Errors that occur in UI components
public enum UIError: ClaudeUsageError, Equatable {
    case chartDataUnavailable
    case viewModelNotInitialized
    case invalidChartRange(start: Date, end: Date)
    case renderingFailed(reason: String)
    
    public var errorDescription: String {
        switch self {
        case .chartDataUnavailable:
            return "Chart data is not available"
        case .viewModelNotInitialized:
            return "View model is not initialized"
        case .invalidChartRange(let start, let end):
            return "Invalid chart range: \(start) to \(end)"
        case .renderingFailed(let reason):
            return "Failed to render UI: \(reason)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .chartDataUnavailable:
            return "Wait for data to load or refresh"
        case .viewModelNotInitialized:
            return "Ensure proper initialization sequence"
        case .invalidChartRange:
            return "Select a valid date range"
        case .renderingFailed:
            return "Try refreshing the view"
        }
    }
}

// MARK: - Composite Error

/// A composite error that can contain multiple errors
public struct CompositeError: ClaudeUsageError {
    public let errors: [any ClaudeUsageError]
    
    public init(errors: [any ClaudeUsageError]) {
        self.errors = errors
    }
    
    public var errorDescription: String {
        if errors.count == 1 {
            return errors[0].errorDescription
        }
        return "Multiple errors occurred: \(errors.map(\.errorDescription).joined(separator: "; "))"
    }
    
    public var recoverySuggestion: String? {
        let suggestions = errors.compactMap(\.recoverySuggestion)
        guard !suggestions.isEmpty else { return nil }
        
        if suggestions.count == 1 {
            return suggestions[0]
        }
        return suggestions.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }
}

// MARK: - Error Extensions

extension ClaudeUsageError {
    /// Convert to NSError for Objective-C compatibility
    public func toNSError() -> NSError {
        NSError(
            domain: "com.claudeusage.error",
            code: 0,
            userInfo: [
                NSLocalizedDescriptionKey: errorDescription,
                NSLocalizedRecoverySuggestionErrorKey: recoverySuggestion ?? ""
            ]
        )
    }
    
    /// Check if error is recoverable
    public var isRecoverable: Bool {
        recoverySuggestion != nil
    }
}

// MARK: - Result Type Aliases

/// Convenient type aliases for Result types with typed errors
public typealias DataLoadingResult<T> = Result<T, DataLoadingError>
public typealias TypedRepositoryResult<T> = Result<T, TypedRepositoryError>
public typealias SessionResult<T> = Result<T, SessionMonitorError>
public typealias ConfigurationResult<T> = Result<T, ConfigurationError>
public typealias UIResult<T> = Result<T, UIError>