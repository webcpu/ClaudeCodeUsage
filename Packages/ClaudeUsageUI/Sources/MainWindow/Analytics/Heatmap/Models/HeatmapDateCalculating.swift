//
//  HeatmapDateCalculating.swift
//  Protocol for heatmap date calculations (DIP)
//

import Foundation

/// Protocol for heatmap date calculation operations.
/// Enables dependency injection and testability.
public protocol HeatmapDateCalculating: Sendable {
    /// Generate weeks layout for heatmap grid
    func generateWeeksLayout(from startDate: Date, to endDate: Date) -> [[Date?]]

    /// Format date as ID string (yyyy-MM-dd)
    func formatDateAsID(_ date: Date) -> String

    /// Calendar properties for a date
    func calendarProperties(for date: Date) -> (dayOfYear: Int, weekOfYear: Int, dayOfWeek: Int)

    /// Generate sequence of dates between two dates
    func dateSequence(from startDate: Date, to endDate: Date) -> [Date]

    /// Validate date range for heatmap display
    func validateDateRange(startDate: Date, endDate: Date) -> [String]

    /// Generate month labels for date range
    func generateMonthLabels(from startDate: Date, to endDate: Date) -> [HeatmapDateCalculator.MonthInfo]

    /// Rolling date range with complete weeks
    func rollingDateRangeWithCompleteWeeks(endingOn endDate: Date, numberOfDays: Int) -> (start: Date, end: Date)?
}

// MARK: - Default Implementation

extension HeatmapDateCalculator: HeatmapDateCalculating {}
