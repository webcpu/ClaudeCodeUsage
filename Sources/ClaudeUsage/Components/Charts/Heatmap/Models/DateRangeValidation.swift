//
//  DateRangeValidation.swift
//  Date range validation and utilities
//

import Foundation

// MARK: - Validation Rules

enum DateRangeValidation {

    /// All validation rules as closures that return optional error message
    static func rules(calendar: Calendar) -> [(Date, Date) -> String?] {
        [
            { start, end in
                start > end ? "Start date cannot be after end date" : nil
            },
            { start, end in
                let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                return days > DateConstants.maxDaysForPerformance
                    ? "Date range too large (maximum \(DateConstants.maxDaysForPerformance) days for performance)"
                    : nil
            },
            { start, end in
                let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                return days < DateConstants.minDaysRequired
                    ? "Date range too small (minimum \(DateConstants.minDaysRequired) day)"
                    : nil
            },
            { start, _ in
                let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: Date())!
                return start > oneYearFromNow ? "Start date is too far in the future" : nil
            }
        ]
    }

    /// Validate date range and return all errors
    static func validate(start: Date, end: Date, calendar: Calendar) -> [String] {
        rules(calendar: calendar).compactMap { $0(start, end) }
    }
}

// MARK: - Date Range Extensions

public extension ClosedRange where Bound == Date {

    /// Whether the range contains today
    var containsToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return self.contains(today)
    }

    /// Number of days in the range
    var dayCount: Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: lowerBound)
        let endDay = calendar.startOfDay(for: upperBound)
        let components = calendar.dateComponents([.day], from: startDay, to: endDay)
        return (components.day ?? 0) + 1
    }

    /// Array of all dates in the range
    var allDates: [Date] {
        HeatmapDateCalculator.shared.dateSequence(from: lowerBound, to: upperBound)
    }
}
