//
//  RetryService.swift
//  ClaudeCodeUsage
//
//  Retry mechanism for handling transient failures
//

import Foundation

/// Retry configuration
public struct RetryConfiguration {
    let maxAttempts: Int
    let initialDelay: TimeInterval
    let maxDelay: TimeInterval
    let backoffMultiplier: Double
    let jitterRange: ClosedRange<Double>
    
    public static let `default` = RetryConfiguration(
        maxAttempts: 3,
        initialDelay: 0.1,
        maxDelay: 5.0,
        backoffMultiplier: 2.0,
        jitterRange: 0.8...1.2
    )
    
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 0.1,
        maxDelay: TimeInterval = 5.0,
        backoffMultiplier: Double = 2.0,
        jitterRange: ClosedRange<Double> = 0.8...1.2
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.jitterRange = jitterRange
    }
}

/// Protocol for retryable operations
public protocol RetryableOperation {
    associatedtype Result
    func execute() async throws -> Result
    func shouldRetry(error: Error, attempt: Int) -> Bool
}

/// Generic retry executor
public final class RetryExecutor {
    private let configuration: RetryConfiguration
    
    public init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Execute operation with retry logic
    public func execute<T>(_ operation: @escaping () async throws -> T, shouldRetry: ((Error, Int) -> Bool)? = nil) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                let shouldRetryDefault = shouldRetry?(error, attempt) ?? isRetryableError(error)
                
                if !shouldRetryDefault || attempt == configuration.maxAttempts {
                    throw error
                }
                
                // Calculate delay with exponential backoff and jitter
                let delay = calculateDelay(for: attempt)
                
                #if DEBUG
                print("[RetryExecutor] Attempt \(attempt) failed with error: \(error). Retrying in \(delay) seconds...")
                #endif
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NSError(domain: "RetryExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "All retry attempts failed"])
    }
    
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        let baseDelay = configuration.initialDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))
        let clampedDelay = min(baseDelay, configuration.maxDelay)
        let jitter = Double.random(in: configuration.jitterRange)
        return clampedDelay * jitter
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Check for common retryable errors
        let nsError = error as NSError
        
        // File system errors that might be transient
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoSuchFileError,
                 NSFileReadUnknownError,
                 NSFileReadTooLargeError:
                return true
            default:
                return false
            }
        }
        
        // POSIX errors that might be transient
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(EAGAIN), Int(EINTR), Int(EBUSY):
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

/// File system with retry capability
public class RetryableFileSystem: FileSystemProtocol {
    private let fileSystem: FileSystemProtocol
    private let retryExecutor: RetryExecutor
    
    public init(fileSystem: FileSystemProtocol, configuration: RetryConfiguration = .default) {
        self.fileSystem = fileSystem
        self.retryExecutor = RetryExecutor(configuration: configuration)
    }
    
    public func fileExists(atPath path: String) -> Bool {
        fileSystem.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fileSystem.contentsOfDirectory(atPath: path)
    }
    
    public func readFile(atPath path: String) throws -> String {
        // Use synchronous wrapper since protocol doesn't support async
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error>!
        
        Task {
            do {
                let content = try await retryExecutor.execute {
                    try self.fileSystem.readFile(atPath: path)
                }
                result = .success(content)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result! {
        case .success(let content):
            return content
        case .failure(let error):
            throw error
        }
    }
    
    public func readFileAsync(atPath path: String) async throws -> String {
        try await retryExecutor.execute {
            try self.fileSystem.readFile(atPath: path)
        }
    }
}