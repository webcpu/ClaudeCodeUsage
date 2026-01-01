//
//  HeatmapDateCalculator.swift
//  Main calculator for heatmap date operations
//

import Foundation

/// Utility class for date calculations in heatmap generation
public final class HeatmapDateCalculator: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = HeatmapDateCalculator()
    private init() {}

    // MARK: - Cached Formatters

    private lazy var idFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()

    private lazy var displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale.current
        return formatter
    }()

    private lazy var calendar: Calendar = {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }()

    // MARK: - Public Types

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

    // MARK: - Public Interface (High Level)

    /// Rolling date range ending on given date
    public func rollingDateRange(
        endingOn endDate: Date = Date(),
        numberOfDays: Int = 365
    ) -> (start: Date, end: Date)? {
        let end = calendar.startOfDay(for: endDate)
        guard let start = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end) else {
            return nil
        }
        return (start: start, end: end)
    }

    /// Rolling date range with complete weeks, avoiding duplicate months
    public func rollingDateRangeWithCompleteWeeks(
        endingOn endDate: Date = Date(),
        numberOfDays: Int = 365
    ) -> (start: Date, end: Date)? {
        let end = calendar.startOfDay(for: endDate)
        guard let initialStart = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end) else {
            return nil
        }
        let adjustedStart = MonthOps.adjustStartForSameMonth(start: initialStart, end: end, calendar: calendar) ?? initialStart
        let finalStart = WeekOps.adjustToCompleteWeek(adjustedStart, calendar: calendar)
        return (start: finalStart, end: end)
    }

    /// Sunday of the week containing given date
    public func weekStart(for date: Date) -> Date {
        WeekOps.weekStart(for: date, calendar: calendar)
    }

    /// Number of weeks in date range
    public func weeksInRange(from startDate: Date, to endDate: Date) -> Int {
        let start = weekStart(for: startDate)
        let daysBetween = calendar.dateComponents([.day], from: start, to: endDate).day ?? 0
        return (daysBetween / DateConstants.daysPerWeek) + 1
    }

    /// Calendar properties for a date
    public func calendarProperties(for date: Date) -> (dayOfYear: Int, weekOfYear: Int, dayOfWeek: Int) {
        (
            dayOfYear: calendar.ordinality(of: .day, in: .year, for: date) ?? 0,
            weekOfYear: calendar.component(.weekOfYear, from: date),
            dayOfWeek: calendar.component(.weekday, from: date) - 1
        )
    }

    /// Check if date is today
    public func isToday(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) == calendar.startOfDay(for: Date())
    }

    /// Format date as ID string (yyyy-MM-dd)
    public func formatDateAsID(_ date: Date) -> String {
        idFormatter.string(from: date)
    }

    /// Format date for display (MMM d, yyyy)
    public func formatDateForDisplay(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }

    /// Generate month labels for date range
    public func generateMonthLabels(from startDate: Date, to endDate: Date) -> [MonthInfo] {
        let weeks = indexedWeeks(from: startDate, to: endDate)
        let initial = MonthAccumulator.initial(for: startDate, calendar: calendar)
        let dateRange = startDate...endDate

        let accumulated = weeks.reduce(initial) { acc, week in
            acc.processingWeek(week, dateRange: dateRange, calendar: calendar, createMonthInfo: createMonthInfo)
        }

        let months = accumulated.finalized(createMonthInfo: createMonthInfo)
        return appendEndDateMonthIfNeeded(months, endDate: endDate, lastWeekIndex: accumulated.lastWeekIndex)
    }

    /// Add end date's month if it differs from the last month in the list
    /// Handles year boundary: Dec 2025 → Jan 2026 in final week
    private func appendEndDateMonthIfNeeded(_ months: [MonthInfo], endDate: Date, lastWeekIndex: Int) -> [MonthInfo] {
        let endMonth = calendar.component(.month, from: endDate)
        let endYear = calendar.component(.year, from: endDate)

        guard let lastMonth = months.last,
              (lastMonth.monthNumber != endMonth || lastMonth.year != endYear) else {
            return months
        }

        let endMonthInfo = createMonthInfo(month: endMonth, year: endYear, firstWeek: lastWeekIndex, lastWeek: lastWeekIndex)
        return months + [endMonthInfo]
    }

    private func indexedWeeks(from startDate: Date, to endDate: Date) -> [(index: Int, start: Date)] {
        WeekOps.weekSequence(from: startDate, calendar: calendar)
            .prefix { $0 <= endDate }
            .enumerated()
            .map { (index: $0.offset, start: $0.element) }
    }

    /// Generate sequence of dates between two dates
    public func dateSequence(from startDate: Date, to endDate: Date) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        return Array(
            sequence(first: start) { self.calendar.date(byAdding: .day, value: 1, to: $0) }
                .prefix { $0 <= end }
        )
    }

    /// Generate weeks layout for heatmap
    /// Includes partial weeks at start/end to ensure all dates in range are visible
    public func generateWeeksLayout(from startDate: Date, to endDate: Date) -> [[Date?]] {
        let firstWeek = WeekOps.weekStart(for: startDate, calendar: calendar)
        return buildWeeksArray(from: firstWeek, to: endDate)
    }

    // MARK: - Month Accumulator (Pure Reduce Pattern)

    private struct MonthAccumulator {
        let months: [MonthInfo]
        let currentMonth: Int
        let currentYear: Int
        let monthStartWeek: Int
        let lastWeekIndex: Int

        static func initial(for startDate: Date, calendar: Calendar) -> MonthAccumulator {
            MonthAccumulator(
                months: [],
                currentMonth: calendar.component(.month, from: startDate),
                currentYear: calendar.component(.year, from: startDate),
                monthStartWeek: 0,
                lastWeekIndex: 0
            )
        }

        func processingWeek(
            _ week: (index: Int, start: Date),
            dateRange: ClosedRange<Date>,
            calendar: Calendar,
            createMonthInfo: (Int, Int, Int, Int) -> MonthInfo
        ) -> MonthAccumulator {
            guard let firstVisibleDay = WeekOps.firstVisibleDay(
                in: week.start,
                within: dateRange,
                calendar: calendar
            ) else {
                return updatingLastWeek(to: week.index)
            }

            let dayMonth = calendar.component(.month, from: firstVisibleDay)
            let dayYear = calendar.component(.year, from: firstVisibleDay)

            guard MonthOps.hasMonthChanged(from: (currentMonth, currentYear), to: (dayMonth, dayYear)) else {
                return updatingLastWeek(to: week.index)
            }

            return transitioningToMonth(dayMonth, year: dayYear, at: week.index, createMonthInfo: createMonthInfo)
        }

        func finalized(createMonthInfo: (Int, Int, Int, Int) -> MonthInfo) -> [MonthInfo] {
            let finalWeekIndex = lastWeekIndex + 1
            guard finalWeekIndex > monthStartWeek else { return months }

            let finalMonth = createMonthInfo(currentMonth, currentYear, monthStartWeek, lastWeekIndex)
            return appendingOrExtendingFirst(with: finalMonth)
        }

        private func updatingLastWeek(to index: Int) -> MonthAccumulator {
            MonthAccumulator(
                months: months,
                currentMonth: currentMonth,
                currentYear: currentYear,
                monthStartWeek: monthStartWeek,
                lastWeekIndex: index
            )
        }

        private func transitioningToMonth(
            _ newMonth: Int,
            year newYear: Int,
            at weekIndex: Int,
            createMonthInfo: (Int, Int, Int, Int) -> MonthInfo
        ) -> MonthAccumulator {
            let completedMonth = (months.isEmpty && weekIndex == 0)
                ? nil
                : createMonthInfo(currentMonth, currentYear, monthStartWeek, weekIndex - 1)

            return MonthAccumulator(
                months: completedMonth.map { months + [$0] } ?? months,
                currentMonth: newMonth,
                currentYear: newYear,
                monthStartWeek: weekIndex,
                lastWeekIndex: weekIndex
            )
        }

        private func appendingOrExtendingFirst(with finalMonth: MonthInfo) -> [MonthInfo] {
            // Only merge if same month AND same year (Jan 2025 ≠ Jan 2026)
            guard let firstMonth = months.first,
                  firstMonth.monthNumber == finalMonth.monthNumber,
                  firstMonth.year == finalMonth.year else {
                return months + [finalMonth]
            }

            let extended = MonthInfo(
                name: firstMonth.name,
                fullName: firstMonth.fullName,
                monthNumber: firstMonth.monthNumber,
                year: firstMonth.year,
                firstWeek: firstMonth.firstWeek,
                lastWeek: finalMonth.lastWeek
            )
            return [extended] + Array(months.dropFirst())
        }
    }

    // MARK: - Week Layout Generation (Mid Level)

    private func buildWeeksArray(from weekStart: Date, to endDate: Date) -> [[Date?]] {
        Array(
            WeekOps.weekSequence(from: weekStart, calendar: calendar)
                .prefix { $0 <= endDate }
                .map { WeekOps.weekDays(from: $0, calendar: calendar) }
        )
    }

    // MARK: - Month Info Construction (Low Level)

    private func createMonthInfo(month: Int, year: Int, firstWeek: Int, lastWeek: Int) -> MonthInfo {
        MonthInfo(
            name: MonthOps.abbreviatedName(for: month, calendar: calendar),
            fullName: MonthOps.fullName(for: month, calendar: calendar),
            monthNumber: month,
            year: year,
            firstWeek: firstWeek,
            lastWeek: lastWeek
        )
    }
}

// MARK: - Date Validation

public extension HeatmapDateCalculator {

    /// Validates that a date range is suitable for heatmap display
    func validateDateRange(startDate: Date, endDate: Date) -> [String] {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return DateRangeValidation.validate(start: startDate, end: endDate, calendar: cal)
    }

    /// Whether a date range is valid for heatmap display
    func isValidDateRange(startDate: Date, endDate: Date) -> Bool {
        validateDateRange(startDate: startDate, endDate: endDate).isEmpty
    }
}
