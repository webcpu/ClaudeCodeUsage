//
//  HeatmapViewModel+DataGeneration.swift
//
//  Dataset generation and processing for heatmap visualization.
//

import Foundation
import ClaudeCodeUsageKit

// MARK: - Data Generation

extension HeatmapViewModel {

    /// Generate heatmap dataset from usage statistics
    /// - Parameter stats: Usage statistics to process
    func generateDataset(from stats: UsageStats) async {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()

            try await Task.sleep(nanoseconds: 10_000_000) // 10ms for testability

            let validDailyUsage = try validateDailyUsage(stats.byDate)
            let dateRange = try calculateValidDateRange()
            let dataset = await buildDataset(from: validDailyUsage, dateRange: dateRange)

            self.dataset = dataset
            recordDatasetGenerationTime(since: startTime)

        } catch {
            handleDatasetError(error)
        }
    }

    /// Build complete dataset from validated inputs
    func buildDataset(
        from dailyUsage: [DailyUsage],
        dateRange: (start: Date, end: Date)
    ) async -> HeatmapDataset {
        let weeks = await generateWeeksData(
            from: dateRange.start,
            to: dateRange.end,
            dailyUsage: dailyUsage
        )
        let monthLabels = generateMonthLabels(from: dateRange.start, to: dateRange.end)
        let maxCost = calculateMaxCost(from: dailyUsage)

        return HeatmapDataset(
            weeks: weeks,
            monthLabels: monthLabels,
            maxCost: maxCost,
            dateRange: dateRange.start...dateRange.end
        )
    }

    // MARK: - Week/Month Generation

    /// Generate weeks data for heatmap
    func generateWeeksData(
        from startDate: Date,
        to endDate: Date,
        dailyUsage: [DailyUsage]
    ) async -> [HeatmapWeek] {
        let costLookup = buildCostLookup(from: dailyUsage)
        let maxCost = calculateMaxCost(from: dailyUsage)
        let weeksLayout = dateCalculator.generateWeeksLayout(from: startDate, to: endDate)

        return buildWeeks(
            from: weeksLayout,
            costLookup: costLookup,
            maxCost: maxCost,
            dateRange: startDate...endDate
        )
    }

    /// Build weeks array from layout
    func buildWeeks(
        from weeksLayout: [[Date?]],
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapWeek] {
        weeksLayout.enumerated().map { weekIndex, weekDates in
            let weekDays = buildWeekDays(
                from: weekDates,
                weekIndex: weekIndex,
                costLookup: costLookup,
                maxCost: maxCost,
                dateRange: dateRange
            )
            return HeatmapWeek(weekNumber: weekIndex, days: weekDays)
        }
    }

    /// Build days array for a single week
    func buildWeekDays(
        from weekDates: [Date?],
        weekIndex: Int,
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapDay?] {
        weekDates.enumerated().map { dayIndex, dayDate in
            guard let dayDate, dateRange.contains(dayDate) else { return nil }
            return createHeatmapDay(
                for: dayDate,
                dayIndex: dayIndex,
                weekIndex: weekIndex,
                costLookup: costLookup,
                maxCost: maxCost
            )
        }
    }

    /// Generate month labels for heatmap header
    func generateMonthLabels(from startDate: Date, to endDate: Date) -> [HeatmapMonth] {
        let monthInfos = dateCalculator.generateMonthLabels(from: startDate, to: endDate)

        return monthInfos.map { info in
            HeatmapMonth(
                name: info.name,
                weekSpan: info.weekSpan,
                fullName: info.fullName,
                monthNumber: info.monthNumber,
                year: info.year
            )
        }
    }

    // MARK: - Calculations

    /// Validate daily usage dates
    func validateDailyUsage(_ dailyUsage: [DailyUsage]) throws -> [DailyUsage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        let invalidDates = DailyUsageValidator.findInvalidDates(in: dailyUsage, using: dateFormatter)

        guard invalidDates.isEmpty else {
            throw HeatmapError.invalidDateRange("Invalid date format(s): \(invalidDates.joined(separator: ", "))")
        }

        return dailyUsage
    }

    /// Calculate and validate date range
    func calculateValidDateRange() throws -> (start: Date, end: Date) {
        let dateRange = dateCalculator.rollingDateRangeWithCompleteWeeks(numberOfDays: 365)

        let validationErrors = dateCalculator.validateDateRange(
            startDate: dateRange.start,
            endDate: dateRange.end
        )

        guard validationErrors.isEmpty else {
            throw HeatmapError.invalidDateRange(validationErrors.joined(separator: ", "))
        }

        return dateRange
    }

    /// Build cost lookup dictionary for O(1) access
    func buildCostLookup(from dailyUsage: [DailyUsage]) -> [String: Double] {
        Dictionary(
            dailyUsage.map { ($0.date, $0.totalCost) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Calculate maximum cost from daily usage
    func calculateMaxCost(from dailyUsage: [DailyUsage]) -> Double {
        dailyUsage.map(\.totalCost).max() ?? 1.0
    }

    /// Create a HeatmapDay for a specific date
    func createHeatmapDay(
        for date: Date,
        dayIndex: Int,
        weekIndex: Int,
        costLookup: [String: Double],
        maxCost: Double
    ) -> HeatmapDay {
        let dateString = dateCalculator.formatDateAsID(date)
        let cost = costLookup[dateString] ?? 0.0
        let calendarProps = dateCalculator.calendarProperties(for: date)

        return HeatmapDay(
            date: date,
            cost: cost,
            dayOfYear: calendarProps.dayOfYear,
            weekOfYear: weekIndex,
            dayOfWeek: dayIndex,
            maxCost: maxCost
        )
    }
}
