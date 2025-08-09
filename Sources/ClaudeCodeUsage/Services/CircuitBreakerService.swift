//
//  CircuitBreakerService.swift
//  ClaudeCodeUsage
//
//  Circuit breaker pattern for fault tolerance
//

import Foundation

/// Circuit breaker states
public enum CircuitBreakerState {
    case closed     // Normal operation
    case open       // Failing, reject requests
    case halfOpen   // Testing if service recovered
}

/// Circuit breaker configuration
public struct CircuitBreakerConfiguration {
    let failureThreshold: Int
    let successThreshold: Int
    let timeout: TimeInterval
    let resetTimeout: TimeInterval
    
    public static let `default` = CircuitBreakerConfiguration(
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 10.0,
        resetTimeout: 60.0
    )
    
    public init(
        failureThreshold: Int = 5,
        successThreshold: Int = 2,
        timeout: TimeInterval = 10.0,
        resetTimeout: TimeInterval = 60.0
    ) {
        self.failureThreshold = failureThreshold
        self.successThreshold = successThreshold
        self.timeout = timeout
        self.resetTimeout = resetTimeout
    }
}

/// Circuit breaker implementation
public actor CircuitBreaker {
    private let configuration: CircuitBreakerConfiguration
    private var state: CircuitBreakerState = .closed
    private var failureCount: Int = 0
    private var successCount: Int = 0
    private var lastFailureTime: Date?
    private var nextAttemptTime: Date?
    
    public init(configuration: CircuitBreakerConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Execute operation through circuit breaker
    public func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        // Check current state
        switch state {
        case .open:
            if let nextAttempt = nextAttemptTime, Date() < nextAttempt {
                throw CircuitBreakerError.circuitOpen
            } else {
                // Try half-open state
                await transitionTo(.halfOpen)
            }
        case .halfOpen:
            // Allow limited requests through
            break
        case .closed:
            // Normal operation
            break
        }
        
        do {
            let result = try await operation()
            await recordSuccess()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }
    
    private func recordSuccess() {
        switch state {
        case .halfOpen:
            successCount += 1
            if successCount >= configuration.successThreshold {
                transitionTo(.closed)
                failureCount = 0
                successCount = 0
                #if DEBUG
                print("[CircuitBreaker] Circuit closed after successful recovery")
                #endif
            }
        case .closed:
            failureCount = 0 // Reset on success
        case .open:
            break
        }
    }
    
    private func recordFailure() {
        lastFailureTime = Date()
        
        switch state {
        case .closed:
            failureCount += 1
            if failureCount >= configuration.failureThreshold {
                transitionTo(.open)
                nextAttemptTime = Date().addingTimeInterval(configuration.resetTimeout)
                #if DEBUG
                print("[CircuitBreaker] Circuit opened after \(failureCount) failures")
                #endif
            }
        case .halfOpen:
            transitionTo(.open)
            nextAttemptTime = Date().addingTimeInterval(configuration.resetTimeout)
            successCount = 0
            #if DEBUG
            print("[CircuitBreaker] Circuit reopened after failure in half-open state")
            #endif
        case .open:
            break
        }
    }
    
    private func transitionTo(_ newState: CircuitBreakerState) {
        state = newState
        #if DEBUG
        print("[CircuitBreaker] State transition to: \(newState)")
        #endif
    }
    
    public func reset() {
        state = .closed
        failureCount = 0
        successCount = 0
        lastFailureTime = nil
        nextAttemptTime = nil
    }
    
    public func getState() -> CircuitBreakerState {
        state
    }
}

/// Circuit breaker errors
public enum CircuitBreakerError: LocalizedError {
    case circuitOpen
    
    public var errorDescription: String? {
        switch self {
        case .circuitOpen:
            return "Circuit breaker is open. Service is temporarily unavailable."
        }
    }
}

/// Async file system with circuit breaker protection
public actor AsyncCircuitBreakerFileSystem: AsyncFileSystemProtocol {
    private let fileSystem: AsyncFileSystemProtocol
    private let circuitBreaker: CircuitBreaker
    
    public init(fileSystem: AsyncFileSystemProtocol, configuration: CircuitBreakerConfiguration = .default) {
        self.fileSystem = fileSystem
        self.circuitBreaker = CircuitBreaker(configuration: configuration)
    }
    
    public func fileExists(atPath path: String) async -> Bool {
        // Non-throwing operation, pass through directly
        await fileSystem.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) async throws -> [String] {
        try await circuitBreaker.execute {
            try await self.fileSystem.contentsOfDirectory(atPath: path)
        }
    }
    
    public func readFile(atPath path: String) async throws -> String {
        try await circuitBreaker.execute {
            try await self.fileSystem.readFile(atPath: path)
        }
    }
}

/// Legacy file system with circuit breaker protection (deprecated)
/// Migrate to AsyncCircuitBreakerFileSystem for better performance
/// This synchronous wrapper passthrough without circuit breaker protection
@available(*, deprecated, message: "Use AsyncCircuitBreakerFileSystem - sync circuit breaker no longer supported")
public class CircuitBreakerFileSystem: FileSystemProtocol {
    private let fileSystem: FileSystemProtocol
    
    public init(fileSystem: FileSystemProtocol, configuration: CircuitBreakerConfiguration = .default) {
        self.fileSystem = fileSystem
        // Configuration ignored - no sync circuit breaker available
        print("[Warning] CircuitBreakerFileSystem is deprecated. Circuit breaker protection not applied to sync operations.")
    }
    
    public func fileExists(atPath path: String) -> Bool {
        fileSystem.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        // Passthrough without circuit breaker protection
        return try fileSystem.contentsOfDirectory(atPath: path)
    }
    
    public func readFile(atPath path: String) throws -> String {
        // Passthrough without circuit breaker protection  
        return try fileSystem.readFile(atPath: path)
    }
}