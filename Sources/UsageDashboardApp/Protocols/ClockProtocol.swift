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
    
    /// Format date as string
    func format(date: Date, format: String) -> String
    
    /// Calculate time until next occurrence of specified time
    func timeUntil(hour: Int, minute: Int, second: Int) -> TimeInterval
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
    
    func format(date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    func timeUntil(hour: Int, minute: Int, second: Int) -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = second
        
        guard let targetTime = calendar.date(from: components) else {
            return 0
        }
        
        // If target time has passed today, get tomorrow's occurrence
        if targetTime <= now {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetTime) else {
                return 0
            }
            return tomorrow.timeIntervalSince(now)
        }
        
        return targetTime.timeIntervalSince(now)
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
        let seconds = duration.components.seconds
        let attoseconds = duration.components.attoseconds
        let totalSeconds = Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
        try await sleep(for: totalSeconds)
    }
    
    func sleep(for seconds: TimeInterval) async throws {
        sleepRecords.append((duration: seconds, timestamp: currentTime))
        advance(by: seconds)
        // Yield to allow other tasks to run
        await Task.yield()
    }
    
    func format(date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    func timeUntil(hour: Int, minute: Int, second: Int) -> TimeInterval {
        let calendar = Calendar.current
        
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = hour
        components.minute = minute
        components.second = second
        
        guard let targetTime = calendar.date(from: components) else {
            return 0
        }
        
        // If target time has passed today, get tomorrow's occurrence
        if targetTime <= currentTime {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: targetTime) else {
                return 0
            }
            return tomorrow.timeIntervalSince(currentTime)
        }
        
        return targetTime.timeIntervalSince(currentTime)
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
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        if let almostMidnight = calendar.date(from: components) {
            currentTime = almostMidnight
        }
    }
    
    /// Advance to the next day
    func advanceToNextDay() {
        let calendar = Calendar.current
        if let nextDay = calendar.date(byAdding: .day, value: 1, to: currentTime) {
            var components = calendar.dateComponents([.year, .month, .day], from: nextDay)
            components.hour = 0
            components.minute = 0
            components.second = 1
            
            if let nextDayStart = calendar.date(from: components) {
                currentTime = nextDayStart
            }
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