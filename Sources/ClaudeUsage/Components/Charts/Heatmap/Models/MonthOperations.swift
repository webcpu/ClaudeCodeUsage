//
//  MonthOperations.swift
//  Pure functions for month-based date calculations
//

import Foundation

enum MonthOps {

    /// Check if month/year combination has changed
    static func hasMonthChanged(
        from current: (month: Int, year: Int),
        to new: (month: Int, year: Int)
    ) -> Bool {
        new.month != current.month || new.year != current.year
    }

    /// Get abbreviated month name (3 chars)
    static func abbreviatedName(for month: Int, calendar: Calendar) -> String {
        String(calendar.monthSymbols[month - 1].prefix(3))
    }

    /// Get full month name
    static func fullName(for month: Int, calendar: Calendar) -> String {
        calendar.monthSymbols[month - 1]
    }

    /// Adjust start date to next month if start and end are in same month
    static func adjustStartForSameMonth(start: Date, end: Date, calendar: Calendar) -> Date {
        let startMonth = calendar.component(.month, from: start)
        let endMonth = calendar.component(.month, from: end)

        guard startMonth == endMonth else { return start }

        var components = calendar.dateComponents([.year, .month], from: start)
        components.month! += 1
        components.day = 1
        return calendar.date(from: components)!
    }
}
