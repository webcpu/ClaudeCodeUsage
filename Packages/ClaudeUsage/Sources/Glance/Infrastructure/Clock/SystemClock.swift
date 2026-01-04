//
//  SystemClock.swift
//  Production clock implementation using system time
//

import Foundation

// MARK: - System Clock

/// Real clock implementation using system time
@MainActor
public struct SystemClock: ClockProtocol {
    public init() {}

    public var now: Date {
        Date()
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    public func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
