//
//  WeekOperations.swift
//  Pure functions for week-based date calculations
//

import Foundation

enum WeekOps {

    /// Find Sunday of the week containing the given date
    static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysToSunday = weekday - 1
        return calendar.date(byAdding: .day, value: -daysToSunday, to: startOfDay)!
    }

    /// Check if week start is before range start (partial week)
    static func isPartialWeek(weekStart: Date, rangeStart: Date, calendar: Calendar) -> Bool {
        guard weekStart < rangeStart else { return false }
        let daysBefore = calendar.dateComponents([.day], from: weekStart, to: rangeStart).day ?? 0
        return daysBefore > 0
    }

    /// Advance to next complete week if current is partial
    static func adjustToCompleteWeek(_ date: Date, calendar: Calendar) -> Date {
        let weekStartDate = weekStart(for: date, calendar: calendar)
        if weekStartDate < date {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate)!
        }
        return weekStartDate
    }

    /// Generate sequence of week start dates
    static func weekSequence(from startDate: Date, calendar: Calendar) -> UnfoldFirstSequence<Date> {
        let firstWeek = weekStart(for: startDate, calendar: calendar)
        return sequence(first: firstWeek) { current in
            calendar.date(byAdding: .weekOfYear, value: 1, to: current)
        }
    }

    /// Build array of 7 dates for a week
    static func weekDays(from weekStart: Date, calendar: Calendar) -> [Date?] {
        (0..<DateConstants.daysPerWeek).map { dayIndex in
            calendar.date(byAdding: .day, value: dayIndex, to: weekStart)
        }
    }

    /// Find first day in week that falls within date range
    static func firstVisibleDay(in weekStart: Date, within dateRange: ClosedRange<Date>, calendar: Calendar) -> Date? {
        (0..<DateConstants.daysPerWeek)
            .lazy
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .first { dateRange.contains($0) }
    }
}
