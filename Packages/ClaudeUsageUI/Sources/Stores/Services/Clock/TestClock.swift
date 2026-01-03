//
//  TestClock.swift
//  Controllable clock for testing time-dependent code
//

import Foundation
import ClaudeUsageCore

// MARK: - Test Clock

/// Controllable clock for testing time-dependent code
@MainActor
final class TestClock: ClockProtocol {
    private(set) var currentTime: Date
    private var sleepRecords: [(duration: TimeInterval, timestamp: Date)] = []

    init(startTime: Date = Date()) {
        self.currentTime = startTime
    }

    var now: Date {
        currentTime
    }

    func sleep(for duration: Duration) async throws {
        try await sleep(for: duration.asTimeInterval)
    }

    func sleep(for seconds: TimeInterval) async throws {
        sleepRecords.append((duration: seconds, timestamp: currentTime))
        advance(by: seconds)
        await Task.yield()
    }

    // MARK: - Test Control Methods

    /// Advance time by the specified interval
    func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }

    /// Set the current time to a specific date
    func setTime(to date: Date) {
        currentTime = date
    }

    /// Advance to just before midnight
    func advanceToAlmostMidnight() {
        if let almostMidnight = TimeBuilder.almostMidnight(on: currentTime) {
            currentTime = almostMidnight
        }
    }

    /// Advance to the next day
    func advanceToNextDay() {
        if let nextDayStart = TimeBuilder.startOfNextDay(after: currentTime) {
            currentTime = nextDayStart
        }
    }

    /// Get all sleep records for verification
    var sleepHistory: [(duration: TimeInterval, timestamp: Date)] {
        sleepRecords
    }

    /// Clear sleep history
    func clearHistory() {
        sleepRecords.removeAll()
    }
}

// MARK: - Duration Extension

private extension Duration {
    var asTimeInterval: TimeInterval {
        let seconds = components.seconds
        let attoseconds = components.attoseconds
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }
}

// MARK: - Time Builder

private enum TimeBuilder {
    static func almostMidnight(on date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)
    }

    static func startOfNextDay(after date: Date) -> Date? {
        let calendar = Calendar.current
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month, .day], from: nextDay)
        components.hour = 0
        components.minute = 0
        components.second = 1
        return calendar.date(from: components)
    }
}
