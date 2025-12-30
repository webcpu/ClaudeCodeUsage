//
//  SystemClock.swift
//  Production clock implementation using system time
//

import Foundation

// MARK: - System Clock

/// Real clock implementation using system time
@MainActor
struct SystemClock: ClockProtocol {
    var now: Date {
        Date()
    }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }

    func sleep(for seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
