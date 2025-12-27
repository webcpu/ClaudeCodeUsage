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
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: endDate)
        let start = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end)!
        return (start: start, end: end)
    }

    /// Rolling date range with complete weeks, avoiding duplicate months
    public func rollingDateRangeWithCompleteWeeks(
        endingOn endDate: Date = Date(),
        numberOfDays: Int = 365
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: endDate)
        let initialStart = calendar.date(byAdding: .day, value: -(numberOfDays - 1), to: end)!
        let adjustedStart = MonthOps.adjustStartForSameMonth(start: initialStart, end: end, calendar: calendar)
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
        var months: [MonthInfo] = []
        var state = createInitialMonthTrackingState(for: startDate)

        enumerateWeeks(from: startDate, to: endDate) { weekIndex, weekStart in
            processWeekForMonthTransition(
                weekIndex: weekIndex,
                weekStart: weekStart,
                dateRange: startDate...endDate,
                state: &state,
                months: &months
            )
        }

        finalizeMonthLabels(state: state, months: &months)
        return months
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
    public func generateWeeksLayout(from startDate: Date, to endDate: Date) -> [[Date?]] {
        let firstWeek = findFirstCompleteWeekStart(for: startDate)
        return buildWeeksArray(from: firstWeek, to: endDate)
    }

    // MARK: - Month Label Generation (Mid Level)

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

    private func enumerateWeeks(
        from startDate: Date,
        to endDate: Date,
        handler: (Int, Date) -> Void
    ) {
        WeekOps.weekSequence(from: startDate, calendar: calendar)
            .prefix { $0 <= endDate }
            .enumerated()
            .forEach { handler($0.offset, $0.element) }
    }

    private func processWeekForMonthTransition(
        weekIndex: Int,
        weekStart: Date,
        dateRange: ClosedRange<Date>,
        state: inout MonthTrackingState,
        months: inout [MonthInfo]
    ) {
        state.weekIndex = weekIndex

        guard let firstVisibleDay = WeekOps.firstVisibleDay(in: weekStart, within: dateRange, calendar: calendar) else {
            return
        }

        let dayMonth = calendar.component(.month, from: firstVisibleDay)
        let dayYear = calendar.component(.year, from: firstVisibleDay)

        if MonthOps.hasMonthChanged(from: (state.currentMonth, state.currentYear), to: (dayMonth, dayYear)) {
            appendCompletedMonth(state: state, to: &months)
            state.currentMonth = dayMonth
            state.currentYear = dayYear
            state.monthStartWeek = weekIndex
        }
    }

    private func finalizeMonthLabels(state: MonthTrackingState, months: inout [MonthInfo]) {
        let finalWeekIndex = state.weekIndex + 1
        guard finalWeekIndex > state.monthStartWeek else { return }

        let monthAbbrev = MonthOps.abbreviatedName(for: state.currentMonth, calendar: calendar)
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
        let weekStartDate = WeekOps.weekStart(for: startDate, calendar: calendar)

        if WeekOps.isPartialWeek(weekStart: weekStartDate, rangeStart: startDate, calendar: calendar) {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartDate)!
        }
        return weekStartDate
    }

    private func buildWeeksArray(from weekStart: Date, to endDate: Date) -> [[Date?]] {
        Array(
            WeekOps.weekSequence(from: weekStart, calendar: calendar)
                .prefix { $0 <= endDate }
                .map { WeekOps.weekDays(from: $0, calendar: calendar) }
        )
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
