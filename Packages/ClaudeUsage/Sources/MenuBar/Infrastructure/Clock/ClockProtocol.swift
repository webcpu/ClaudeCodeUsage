//
//  ClockProtocol.swift
//  Protocol for time abstraction to improve testability
//

import Foundation

// MARK: - Clock Protocol

/// Protocol for abstracting time operations, enabling testable time-dependent code
@MainActor
public protocol ClockProtocol: Sendable {
    /// Current date and time
    var now: Date { get }

    /// Sleep for the specified duration
    func sleep(for duration: Duration) async throws

    /// Sleep for the specified time interval (legacy support)
    func sleep(for seconds: TimeInterval) async throws
}

// MARK: - Default Implementations

public extension ClockProtocol {
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
