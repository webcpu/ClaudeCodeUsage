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

    /// Checks if the day changed and updates if so. Returns true if day changed.
    mutating func checkAndUpdateIfChanged(clock: any ClockProtocol) -> Bool {
        let currentDay = Self.formatDay(clock.now)
        guard currentDay != lastKnownDay else { return false }
        lastKnownDay = currentDay
        return true
    }

    /// Unconditionally updates to current day.
    mutating func updateToCurrentDay(clock: any ClockProtocol) {
        lastKnownDay = Self.formatDay(clock.now)
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
