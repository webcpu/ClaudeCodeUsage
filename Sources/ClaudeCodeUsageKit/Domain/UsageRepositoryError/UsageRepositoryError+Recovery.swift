//
//  UsageRepositoryError+Recovery.swift
//
//  Error recovery strategies and execution.
//

import Foundation

// MARK: - Error Recovery Strategy

/// Error recovery strategies
public enum ErrorRecoveryStrategy: Sendable {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case skip
    case fallback(handler: @Sendable () async throws -> Void)
    case abort

    /// Execute recovery strategy
    public func execute<T: Sendable>(
        operation: @Sendable () async throws -> T,
        onError: @Sendable (Error) -> Void = { _ in }
    ) async throws -> T? {
        switch self {
        case .retry(let maxAttempts, let delay):
            return try await executeWithRetry(
                maxAttempts: maxAttempts,
                delay: delay,
                operation: operation,
                onError: onError
            )

        case .skip:
            return try await executeWithSkip(operation: operation, onError: onError)

        case .fallback(let handler):
            return try await executeWithFallback(
                handler: handler,
                operation: operation,
                onError: onError
            )

        case .abort:
            return try await operation()
        }
    }

    // MARK: - Strategy Execution Helpers

    private func executeWithRetry<T: Sendable>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: @Sendable () async throws -> T,
        onError: @Sendable (Error) -> Void
    ) async throws -> T {
        let attempts = (1...maxAttempts).map { $0 }
        var lastError: Error?

        for attempt in attempts {
            let result = await captureResult(operation)
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                lastError = error
                onError(error)
                await sleepIfNotLastAttempt(attempt: attempt, maxAttempts: maxAttempts, delay: delay)
            }
        }

        throw lastError ?? timeoutError(maxAttempts: maxAttempts, delay: delay)
    }

    private func captureResult<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func sleepIfNotLastAttempt(attempt: Int, maxAttempts: Int, delay: TimeInterval) async {
        guard attempt < maxAttempts else { return }
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private func timeoutError(maxAttempts: Int, delay: TimeInterval) -> UsageRepositoryError {
        .timeout(operation: "retry", duration: Double(maxAttempts) * delay)
    }

    private func executeWithSkip<T: Sendable>(
        operation: @Sendable () async throws -> T,
        onError: @Sendable (Error) -> Void
    ) async throws -> T? {
        let result = await captureResult(operation)
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            onError(error)
            return nil
        }
    }

    private func executeWithFallback<T: Sendable>(
        handler: @Sendable () async throws -> Void,
        operation: @Sendable () async throws -> T,
        onError: @Sendable (Error) -> Void
    ) async throws -> T? {
        let result = await captureResult(operation)
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            onError(error)
            try await handler()
            return nil
        }
    }
}

// MARK: - Retry Executor

enum RetryExecutor {
    static func execute<T>(
        operation: @escaping @Sendable () async throws -> T,
        maxRetryCount: Int,
        initialDelay: TimeInterval
    ) async throws -> T {
        let delays = exponentialDelays(initialDelay: initialDelay, count: maxRetryCount)
        return try await executeWithDelays(operation: operation, delays: delays)
    }

    private static func exponentialDelays(initialDelay: TimeInterval, count: Int) -> [TimeInterval] {
        (0..<count).map { attempt in
            initialDelay * pow(2.0, Double(attempt))
        }
    }

    private static func executeWithDelays<T>(
        operation: @escaping @Sendable () async throws -> T,
        delays: [TimeInterval]
    ) async throws -> T {
        var lastError: Error?

        for (index, delay) in delays.enumerated() {
            let result = await attemptExecution(operation: operation)

            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                lastError = error
                let isLastAttempt = index == delays.count - 1
                if !isLastAttempt {
                    try await sleep(for: delay)
                }
            }
        }

        throw lastError ?? timeoutError(delays: delays)
    }

    private static func attemptExecution<T>(
        operation: @escaping @Sendable () async throws -> T
    ) async -> Result<T, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private static func sleep(for delay: TimeInterval) async throws {
        try await Task<Never, Never>.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    private static func timeoutError(delays: [TimeInterval]) -> UsageRepositoryError {
        .timeout(
            operation: "retry",
            duration: delays.reduce(0, +)
        )
    }
}
