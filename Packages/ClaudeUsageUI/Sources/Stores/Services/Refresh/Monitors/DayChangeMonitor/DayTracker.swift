//
//  DayTracker.swift
//  Tracks the current day for detecting day changes
//

import Foundation

/// Encapsulates day tracking logic for detecting midnight crossings.
@MainActor
struct DayTracker {
    private(set) var lastKnownDay: String

    init(clock: any ClockProtocol) {
        self.lastKnownDay = Self.formatDay(clock.now)
    }

    /// Determines refresh reason for calendar day change notification.
    /// Always returns .dayChange since the system told us the day changed.
    mutating func refreshReasonForDayChange(clock: any ClockProtocol) -> RefreshReason {
        lastKnownDay = Self.formatDay(clock.now)
        return .dayChange
    }

    /// Determines refresh reason for system clock change.
    /// Returns .dayChange only if the day actually changed.
    mutating func refreshReasonForClockChange(clock: any ClockProtocol) -> RefreshReason? {
        let currentDay = Self.formatDay(clock.now)
        guard currentDay != lastKnownDay else { return nil }
        lastKnownDay = currentDay
        return .dayChange
    }

    /// Determines refresh reason for wake from sleep.
    /// Returns .dayChange if day changed, otherwise .wakeFromSleep.
    mutating func refreshReasonForWake(clock: any ClockProtocol) -> RefreshReason {
        let currentDay = Self.formatDay(clock.now)
        if currentDay != lastKnownDay {
            lastKnownDay = currentDay
            return .dayChange
        }
        return .wakeFromSleep
    }

    // MARK: - Private

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func formatDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
