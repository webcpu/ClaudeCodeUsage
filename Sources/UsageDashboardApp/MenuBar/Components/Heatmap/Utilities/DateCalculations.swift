//
//  DateCalculations.swift
//  Date utility functions for heatmap calculations
//
//  Provides optimized date calculations and formatting for heatmap generation
//  with proper error handling and edge case management.
//

import Foundation

// MARK: - Date Range Validation (Pure Functions)

private enum DateRangeValidation {
    /// Maximum days allowed for performance
    static let maxDays = 400

    /// Minimum days required
    static let minDays = 1

    /// All validation rules as closures that return optional error message
    static func rules(calendar: Calendar) -> [(Date, Date) -> String?] {
        [
            // Start date after end date
            { start, end in
                start > end ? "Start date cannot be after end date" : nil
            },
            // Range too large
            { start, end in
                let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                return days > maxDays ? "Date range too large (maximum \(maxDays) days for performance)" : nil
            },
            // Range too small
            { start, end in
                let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
                return days < minDays ? "Date range too small (minimum \(minDays) day)" : nil
            },
            // Start date too far in future
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

// MARK: - Date Calculation Utilities

/// Utility class for date calculations in heatmap generation
public final class HeatmapDateCalculator {
    
    // MARK: - Singleton
    
    public static let shared = HeatmapDateCalculator()
    private init() {}
    
    // MARK: - Cached Formatters
    
    /// Cached date formatter for ID generation (yyyy-MM-dd)
    private lazy var idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Cached date formatter for display (MMM d, yyyy)
    private lazy var displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()
    
    /// Cached calendar instance
    private lazy var calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()
    
    // MARK: - Date Range Calculations
    
    /// Calculates the rolling date range for a given number of days ending on the specified date
    /// - Parameters:
    ///   - endDate: The end date of the range (typically today)
    ///   - numberOfDays: Number of days to include in the range (default: 365)
    /// - Returns: Tuple containing start and end dates
    public func rollingDateRange(
        endingOn endDate: Date = Date(),
        numberOfDays: Int = 365
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: endDate)
        let start = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end)!
        return (start: start, end: end)
    }
    
    /// Calculates the rolling date range with complete weeks only for heatmap display
    /// - Parameters:
    ///   - endDate: The end date of the range (typically today)
    ///   - numberOfDays: Target number of days to include (will be adjusted to complete weeks)
    /// - Returns: Tuple containing adjusted start and end dates for complete weeks
    public func rollingDateRangeWithCompleteWeeks(
        endingOn endDate: Date = Date(),
        numberOfDays: Int = 365
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: endDate)
        let initialStart = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end)!
        
        // Find the week start for the initial start date
        let weekStartDate = weekStart(for: initialStart)
        
        // If the week start is before our initial start date, we have a partial first week
        // In that case, move to the next complete week
        let adjustedStart: Date
        if weekStartDate < initialStart {
            adjustedStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate)!
        } else {
            adjustedStart = weekStartDate
        }
        
        return (start: adjustedStart, end: end)
    }
    
    /// Finds the Sunday of the week containing the given date
    /// - Parameter date: The date to find the week start for
    /// - Returns: The Sunday of that week
    public func weekStart(for date: Date) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysToSunday = weekday - 1  // Sunday = 1, so Monday = 2 means go back 1 day
        return calendar.date(byAdding: .day, value: -daysToSunday, to: startOfDay)!
    }
    
    /// Calculates the number of weeks needed to represent a date range
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Number of weeks needed
    public func weeksInRange(from startDate: Date, to endDate: Date) -> Int {
        let weekStart = weekStart(for: startDate)
        let daysBetween = calendar.dateComponents([.day], from: weekStart, to: endDate).day ?? 0
        return (daysBetween / 7) + 1
    }
    
    // MARK: - Calendar Property Calculations
    
    /// Calculates calendar properties for a date
    /// - Parameter date: The date to analyze
    /// - Returns: Tuple with day of year, week of year, and day of week
    public func calendarProperties(for date: Date) -> (dayOfYear: Int, weekOfYear: Int, dayOfWeek: Int) {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let dayOfWeek = (calendar.component(.weekday, from: date) - 1) // Convert to 0-6 (Sun-Sat)
        
        return (dayOfYear: dayOfYear, weekOfYear: weekOfYear, dayOfWeek: dayOfWeek)
    }
    
    /// Checks if a date is today
    /// - Parameter date: The date to check
    /// - Returns: True if the date is today
    public func isToday(_ date: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let dateStart = calendar.startOfDay(for: date)
        return dateStart == today
    }
    
    // MARK: - String Formatting
    
    /// Formats a date as an ID string (yyyy-MM-dd)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    public func formatDateAsID(_ date: Date) -> String {
        return idFormatter.string(from: date)
    }
    
    /// Formats a date for display (MMM d, yyyy)
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    public func formatDateForDisplay(_ date: Date) -> String {
        return displayFormatter.string(from: date)
    }
    
    // MARK: - Public Interface (High Level)

    /// Information about a month for labeling
    public struct MonthInfo {
        public let name: String
        public let fullName: String
        public let monthNumber: Int
        public let year: Int
        public let firstWeek: Int
        public let lastWeek: Int

        public var weekSpan: Range<Int> {
            firstWeek..<(lastWeek + 1)
        }
    }

    /// Generates month labels for a date range
    /// - Parameters:
    ///   - startDate: Start date of the range
    ///   - endDate: End date of the range
    /// - Returns: Array of month information for labeling
    public func generateMonthLabels(from startDate: Date, to endDate: Date) -> [MonthInfo] {
        var months: [MonthInfo] = []
        var state = createInitialMonthTrackingState(for: startDate)

        iterateThroughWeeks(from: startDate, to: endDate) { weekIndex, currentWeekStart in
            processWeekForMonthTransition(
                weekIndex: weekIndex,
                weekStart: currentWeekStart,
                dateRange: startDate...endDate,
                state: &state,
                months: &months
            )
        }

        finalizeMonthLabels(state: state, months: &months)
        return months
    }

    /// Generates a sequence of dates between two dates
    /// - Parameters:
    ///   - startDate: The start date (inclusive)
    ///   - endDate: The end date (inclusive)
    /// - Returns: Array of dates
    public func dateSequence(from startDate: Date, to endDate: Date) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        return sequence(first: start) { current in
            self.calendar.date(byAdding: .day, value: 1, to: current)
        }
        .prefix { $0 <= end }
        .map { $0 }
    }

    /// Generates weeks of dates for heatmap layout, starting with the first complete week
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Array of weeks, each containing 7 dates (some may be outside the range)
    public func generateWeeksLayout(from startDate: Date, to endDate: Date) -> [[Date?]] {
        let firstCompleteWeekStart = findFirstCompleteWeekStart(for: startDate)
        return buildWeeksArray(from: firstCompleteWeekStart, to: endDate)
    }

    // MARK: - Month Label Generation (Mid Level)

    /// State for tracking month transitions during iteration
    private struct MonthTrackingState {
        var currentMonth: Int
        var currentYear: Int
        var monthStartWeek: Int
        var weekIndex: Int
    }

    private func createInitialMonthTrackingState(for startDate: Date) -> MonthTrackingState {
        MonthTrackingState(
            currentMonth: calendar.component(.month, from: startDate),
            currentYear: calendar.component(.year, from: startDate),
            monthStartWeek: 0,
            weekIndex: 0
        )
    }

    private func iterateThroughWeeks(
        from startDate: Date,
        to endDate: Date,
        handler: (Int, Date) -> Void
    ) {
        var currentWeekStart = weekStart(for: startDate)
        var weekIndex = 0

        while currentWeekStart <= endDate {
            handler(weekIndex, currentWeekStart)
            weekIndex += 1
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        }
    }

    private func processWeekForMonthTransition(
        weekIndex: Int,
        weekStart: Date,
        dateRange: ClosedRange<Date>,
        state: inout MonthTrackingState,
        months: inout [MonthInfo]
    ) {
        state.weekIndex = weekIndex

        guard let firstVisibleDay = findFirstVisibleDay(in: weekStart, within: dateRange) else {
            return
        }

        let dayMonth = calendar.component(.month, from: firstVisibleDay)
        let dayYear = calendar.component(.year, from: firstVisibleDay)

        if hasMonthChanged(from: (state.currentMonth, state.currentYear), to: (dayMonth, dayYear)) {
            appendCompletedMonth(state: state, to: &months)
            state.currentMonth = dayMonth
            state.currentYear = dayYear
            state.monthStartWeek = weekIndex
        }
    }

    private func finalizeMonthLabels(state: MonthTrackingState, months: inout [MonthInfo]) {
        let finalWeekIndex = state.weekIndex + 1
        guard finalWeekIndex > state.monthStartWeek else { return }

        let monthAbbrev = abbreviatedMonthName(for: state.currentMonth)
        let isDuplicateOfFirst = months.first?.name == monthAbbrev &&
                                  months.first?.monthNumber == state.currentMonth

        if isDuplicateOfFirst {
            extendFirstMonthToIncludeFinalWeeks(finalWeekIndex: finalWeekIndex - 1, months: &months)
        } else {
            appendFinalMonth(state: state, lastWeek: finalWeekIndex - 1, to: &months)
        }
    }

    // MARK: - Week Layout Generation (Mid Level)

    private func findFirstCompleteWeekStart(for startDate: Date) -> Date {
        let weekStartDate = weekStart(for: startDate)

        if isPartialWeek(weekStart: weekStartDate, rangeStart: startDate) {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate)!
        }
        return weekStartDate
    }

    private func buildWeeksArray(from weekStart: Date, to endDate: Date) -> [[Date?]] {
        var weeks: [[Date?]] = []
        var currentWeekStart = weekStart

        while currentWeekStart <= endDate {
            weeks.append(buildWeekDays(from: currentWeekStart))
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        }

        return weeks
    }

    private func buildWeekDays(from weekStart: Date) -> [Date?] {
        (0..<7).map { dayIndex in
            calendar.date(byAdding: .day, value: dayIndex, to: weekStart)!
        }
    }

    // MARK: - Calendar Operations (Low Level)

    private func findFirstVisibleDay(in weekStart: Date, within dateRange: ClosedRange<Date>) -> Date? {
        for dayOffset in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            if dateRange.contains(dayDate) {
                return dayDate
            }
        }
        return nil
    }

    private func hasMonthChanged(
        from current: (month: Int, year: Int),
        to new: (month: Int, year: Int)
    ) -> Bool {
        new.month != current.month || new.year != current.year
    }

    private func isPartialWeek(weekStart: Date, rangeStart: Date) -> Bool {
        guard weekStart < rangeStart else { return false }
        let daysBefore = calendar.dateComponents([.day], from: weekStart, to: rangeStart).day ?? 0
        return daysBefore > 0
    }

    // MARK: - Month Info Construction (Low Level)

    private func appendCompletedMonth(state: MonthTrackingState, to months: inout [MonthInfo]) {
        guard !months.isEmpty || state.weekIndex > 0 else { return }

        months.append(createMonthInfo(
            month: state.currentMonth,
            year: state.currentYear,
            firstWeek: state.monthStartWeek,
            lastWeek: state.weekIndex - 1
        ))
    }

    private func appendFinalMonth(state: MonthTrackingState, lastWeek: Int, to months: inout [MonthInfo]) {
        months.append(createMonthInfo(
            month: state.currentMonth,
            year: state.currentYear,
            firstWeek: state.monthStartWeek,
            lastWeek: lastWeek
        ))
    }

    private func extendFirstMonthToIncludeFinalWeeks(finalWeekIndex: Int, months: inout [MonthInfo]) {
        guard let firstMonth = months.first else { return }

        months[0] = MonthInfo(
            name: firstMonth.name,
            fullName: firstMonth.fullName,
            monthNumber: firstMonth.monthNumber,
            year: firstMonth.year,
            firstWeek: firstMonth.firstWeek,
            lastWeek: finalWeekIndex
        )
    }

    private func createMonthInfo(month: Int, year: Int, firstWeek: Int, lastWeek: Int) -> MonthInfo {
        let monthName = calendar.monthSymbols[month - 1]
        return MonthInfo(
            name: String(monthName.prefix(3)),
            fullName: monthName,
            monthNumber: month,
            year: year,
            firstWeek: firstWeek,
            lastWeek: lastWeek
        )
    }

    // MARK: - Formatting (Low Level)

    private func abbreviatedMonthName(for month: Int) -> String {
        String(calendar.monthSymbols[month - 1].prefix(3))
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
        return (components.day ?? 0) + 1 // +1 to include both endpoints
    }
    
    /// Array of all dates in the range
    var allDates: [Date] {
        return HeatmapDateCalculator.shared.dateSequence(from: lowerBound, to: upperBound)
    }
}

// MARK: - Date Validation

public extension HeatmapDateCalculator {
    
    /// Validates that a date range is suitable for heatmap display
    /// - Parameters:
    ///   - startDate: The start date
    ///   - endDate: The end date
    /// - Returns: Array of validation errors, empty if valid
    func validateDateRange(startDate: Date, endDate: Date) -> [String] {
        DateRangeValidation.validate(start: startDate, end: endDate, calendar: calendar)
    }
    
    /// Whether a date range is valid for heatmap display
    func isValidDateRange(startDate: Date, endDate: Date) -> Bool {
        return validateDateRange(startDate: startDate, endDate: endDate).isEmpty
    }
}