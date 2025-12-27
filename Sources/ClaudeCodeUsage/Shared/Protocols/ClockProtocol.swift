//
//  ClockProtocol.swift
//  Protocol for time abstraction to improve testability
//

import Foundation

// MARK: - Clock Protocol
/// Protocol for abstracting time operations, enabling testable time-dependent code
@MainActor
protocol ClockProtocol: Sendable {
    /// Current date and time
    var now: Date { get }

    /// Sleep for the specified duration
    func sleep(for duration: Duration) async throws

    /// Sleep for the specified time interval (legacy support)
    func sleep(for seconds: TimeInterval) async throws
}

// MARK: - Default Implementations (Pure Functions)
extension ClockProtocol {
    /// Format date as string
    func format(date: Date, format: String) -> String {
        DateFormatting.formatted(date, using: format)
    }

    /// Calculate time until next occurrence of specified time
    func timeUntil(hour: Int, minute: Int, second: Int) -> TimeInterval {
        TimeCalculation.intervalUntilNextOccurrence(
            of: (hour: hour, minute: minute, second: second),
            from: now
        )
    }
}

// MARK: - Pure Date Formatting
private enum DateFormatting {
    static func formatted(_ date: Date, using format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

// MARK: - Pure Time Calculation
private enum TimeCalculation {
    static func intervalUntilNextOccurrence(
        of time: (hour: Int, minute: Int, second: Int),
        from referenceDate: Date
    ) -> TimeInterval {
        let calendar = Calendar.current

        guard let targetTime = buildTargetTime(time, on: referenceDate, using: calendar) else {
            return 0
        }

        return adjustedInterval(from: referenceDate, to: targetTime, using: calendar)
    }

    private static func buildTargetTime(
        _ time: (hour: Int, minute: Int, second: Int),
        on date: Date,
        using calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        return calendar.date(from: components)
    }

    private static func adjustedInterval(
        from referenceDate: Date,
        to targetTime: Date,
        using calendar: Calendar
    ) -> TimeInterval {
        if targetTime <= referenceDate {
            return tomorrowInterval(from: referenceDate, to: targetTime, using: calendar)
        }
        return targetTime.timeIntervalSince(referenceDate)
    }

    private static func tomorrowInterval(
        from referenceDate: Date,
        to targetTime: Date,
        using calendar: Calendar
    ) -> TimeInterval {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetTime) else {
            return 0
        }
        return tomorrow.timeIntervalSince(referenceDate)
    }
}

// MARK: - System Clock (Production)
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

// MARK: - Test Clock (Testing)
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

// MARK: - Clock Provider
/// Manages clock instance for dependency injection
@MainActor
struct ClockProvider {
    private static var _current: ClockProtocol?
    
    /// Current clock instance (defaults to SystemClock in production)
    static var current: ClockProtocol {
        get {
            _current ?? SystemClock()
        }
        set {
            _current = newValue
        }
    }
    
    /// Reset to default (SystemClock)
    static func reset() {
        _current = nil
    }
    
    /// Use test clock for testing
    static func useTestClock(_ clock: TestClock) {
        _current = clock
    }
}