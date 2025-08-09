//
//  DateCalculations.swift
//  Date utility functions for heatmap calculations
//
//  Provides optimized date calculations and formatting for heatmap generation
//  with proper error handling and edge case management.
//

import Foundation

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
        var weekStartDate = calendar.startOfDay(for: date)
        
        // Go back to the previous Sunday if needed (1 = Sunday in Calendar.current)
        while calendar.component(.weekday, from: weekStartDate) != 1 {
            weekStartDate = calendar.date(byAdding: .day, value: -1, to: weekStartDate)!
        }
        
        return weekStartDate
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
    
    // MARK: - Month Label Generation
    
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
        let weekStartDate = weekStart(for: startDate)
        var months: [MonthInfo] = []
        var currentWeekStart = weekStartDate
        var weekIndex = 0
        
        // Track current month state
        var currentMonth = calendar.component(.month, from: startDate)
        var currentYear = calendar.component(.year, from: startDate)
        var monthStartWeek = 0
        
        // Iterate through weeks
        while currentWeekStart <= endDate {
            // Check if we've entered a new month by examining the first visible day of the week
            for dayOffset in 0..<7 {
                let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)!
                
                // Only consider days within our visible range
                if dayDate >= startDate && dayDate <= endDate {
                    let dayMonth = calendar.component(.month, from: dayDate)
                    let dayYear = calendar.component(.year, from: dayDate)
                    
                    // If we've moved to a new month, close the previous month
                    if dayMonth != currentMonth || dayYear != currentYear {
                        if !months.isEmpty || weekIndex > 0 {
                            let monthName = calendar.monthSymbols[currentMonth - 1]
                            months.append(MonthInfo(
                                name: String(monthName.prefix(3)),
                                fullName: monthName,
                                monthNumber: currentMonth,
                                year: currentYear,
                                firstWeek: monthStartWeek,
                                lastWeek: weekIndex - 1
                            ))
                        }
                        
                        // Start tracking the new month
                        currentMonth = dayMonth
                        currentYear = dayYear
                        monthStartWeek = weekIndex
                    }
                    
                    break // Only need to check the first visible day
                }
            }
            
            weekIndex += 1
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        }
        
        // Close the final month
        if weekIndex > monthStartWeek {
            let monthName = calendar.monthSymbols[currentMonth - 1]
            let monthAbbrev = String(monthName.prefix(3))
            
            // Check if this month would duplicate the first month (common in rolling year views)
            // For rolling year views, we only check month name to avoid confusion with duplicate labels
            let isDuplicate = months.first?.name == monthAbbrev
            
            if !isDuplicate {
                months.append(MonthInfo(
                    name: monthAbbrev,
                    fullName: monthName,
                    monthNumber: currentMonth,
                    year: currentYear,
                    firstWeek: monthStartWeek,
                    lastWeek: weekIndex - 1
                ))
            }
        }
        
        return months
    }
    
    // MARK: - Date Sequence Generation
    
    /// Generates a sequence of dates between two dates
    /// - Parameters:
    ///   - startDate: The start date (inclusive)
    ///   - endDate: The end date (inclusive)
    /// - Returns: Array of dates
    public func dateSequence(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        while currentDate <= end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    /// Generates weeks of dates for heatmap layout, starting with the first complete week
    /// - Parameters:
    ///   - startDate: The start date of the range
    ///   - endDate: The end date of the range
    /// - Returns: Array of weeks, each containing 7 dates (some may be outside the range)
    public func generateWeeksLayout(from startDate: Date, to endDate: Date) -> [[Date?]] {
        let weekStartDate = weekStart(for: startDate)
        var weeks: [[Date?]] = []
        var currentWeekStart = weekStartDate
        
        // Check if the first week is partial (doesn't contain the full 7 days within our range)
        var isFirstWeekPartial = false
        if weekStartDate < startDate {
            // Count how many days of the first week are before our start date
            let daysBefore = calendar.dateComponents([.day], from: weekStartDate, to: startDate).day ?? 0
            isFirstWeekPartial = daysBefore > 0
        }
        
        // Skip the first week if it's partial
        if isFirstWeekPartial {
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        }
        
        while currentWeekStart <= endDate {
            var weekDays: [Date?] = Array(repeating: nil, count: 7)
            
            for dayIndex in 0..<7 {
                let dayDate = calendar.date(byAdding: .day, value: dayIndex, to: currentWeekStart)!
                
                // Include all dates, but mark those outside range appropriately
                weekDays[dayIndex] = dayDate
            }
            
            weeks.append(weekDays)
            currentWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        }
        
        return weeks
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
        var errors: [String] = []
        
        if startDate > endDate {
            errors.append("Start date cannot be after end date")
        }
        
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if daysBetween > 400 {
            errors.append("Date range too large (maximum 400 days for performance)")
        }
        
        if daysBetween < 1 {
            errors.append("Date range too small (minimum 1 day)")
        }
        
        // Check if dates are too far in the future
        let oneYearFromNow = calendar.date(byAdding: .year, value: 1, to: Date())!
        if startDate > oneYearFromNow {
            errors.append("Start date is too far in the future")
        }
        
        return errors
    }
    
    /// Whether a date range is valid for heatmap display
    func isValidDateRange(startDate: Date, endDate: Date) -> Bool {
        return validateDateRange(startDate: startDate, endDate: endDate).isEmpty
    }
}