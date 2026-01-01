//
//  HeatmapStore+DataGeneration.swift
//

import Foundation
import ClaudeUsageCore

// MARK: - Constants

private enum DataGenerationConstants {
    static let testabilityDelayNanoseconds: UInt64 = 10_000_000
    static let rollingDateRangeDays = 365
    static let defaultMaxCost = 1.0
    static let defaultCost = 0.0
    static let dateFormat = "yyyy-MM-dd"
}

// MARK: - High-Level Orchestration

extension HeatmapStore {

    func generateDataset(from stats: UsageStats) async {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            try await delayForTestability()
            let dataset = try await processStatsIntoDataset(stats)
            self.dataset = dataset
            recordDatasetGenerationTime(since: startTime)
        } catch {
            handleDatasetError(error)
        }
    }
}

// MARK: - Dataset Assembly

extension HeatmapStore {

    func buildDataset(
        from dailyUsage: [DailyUsage],
        dateRange: (start: Date, end: Date)
    ) async -> HeatmapDataset {
        let weeks = await generateWeeksData(
            from: dateRange.start,
            to: dateRange.end,
            dailyUsage: dailyUsage
        )

        return HeatmapDataset(
            weeks: weeks,
            monthLabels: generateMonthLabels(from: dateRange.start, to: dateRange.end),
            maxCost: calculateMaxCost(from: dailyUsage),
            dateRange: dateRange.start...dateRange.end
        )
    }

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

    func generateMonthLabels(from startDate: Date, to endDate: Date) -> [HeatmapMonth] {
        dateCalculator
            .generateMonthLabels(from: startDate, to: endDate)
            .map(makeHeatmapMonth)
    }
}

// MARK: - Week Building

extension HeatmapStore {

    func buildWeeks(
        from weeksLayout: [[Date?]],
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapWeek] {
        weeksLayout.enumerated().map { weekIndex, weekDates in
            HeatmapWeek(
                weekNumber: weekIndex,
                days: buildWeekDays(
                    from: weekDates,
                    weekIndex: weekIndex,
                    costLookup: costLookup,
                    maxCost: maxCost,
                    dateRange: dateRange
                )
            )
        }
    }

    func buildWeekDays(
        from weekDates: [Date?],
        weekIndex: Int,
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapDay?] {
        weekDates.enumerated().map { dayIndex, dayDate in
            guard let date = dayDate, dateRange.contains(date) else { return nil }
            return createHeatmapDay(
                for: date,
                dayIndex: dayIndex,
                weekIndex: weekIndex,
                costLookup: costLookup,
                maxCost: maxCost
            )
        }
    }

    func createHeatmapDay(
        for date: Date,
        dayIndex: Int,
        weekIndex: Int,
        costLookup: [String: Double],
        maxCost: Double
    ) -> HeatmapDay {
        let dateString = dateCalculator.formatDateAsID(date)
        let calendarProps = dateCalculator.calendarProperties(for: date)

        return HeatmapDay(
            date: date,
            cost: costLookup[dateString] ?? DataGenerationConstants.defaultCost,
            dayOfYear: calendarProps.dayOfYear,
            weekOfYear: weekIndex,
            dayOfWeek: dayIndex,
            maxCost: maxCost
        )
    }
}

// MARK: - Validation

extension HeatmapStore {

    func validateDailyUsage(_ dailyUsage: [DailyUsage]) throws -> [DailyUsage] {
        let invalidDates = findInvalidDates(in: dailyUsage)

        guard invalidDates.isEmpty else {
            throw HeatmapError.invalidDateRange(formatInvalidDatesMessage(invalidDates))
        }

        return dailyUsage
    }

    func calculateValidDateRange() throws -> (start: Date, end: Date) {
        guard let dateRange = dateCalculator.rollingDateRangeWithCompleteWeeks(
            numberOfDays: DataGenerationConstants.rollingDateRangeDays
        ) else {
            throw HeatmapError.invalidDateRange("Failed to calculate date range")
        }

        let validationErrors = dateCalculator.validateDateRange(
            startDate: dateRange.start,
            endDate: dateRange.end
        )

        guard validationErrors.isEmpty else {
            throw HeatmapError.invalidDateRange(validationErrors.joined(separator: ", "))
        }

        return dateRange
    }
}

// MARK: - Pure Functions

extension HeatmapStore {

    func buildCostLookup(from dailyUsage: [DailyUsage]) -> [String: Double] {
        Dictionary(
            dailyUsage.map { ($0.date, $0.totalCost) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func calculateMaxCost(from dailyUsage: [DailyUsage]) -> Double {
        dailyUsage
            .map(\.totalCost)
            .max() ?? DataGenerationConstants.defaultMaxCost
    }
}

// MARK: - Private Helpers

private extension HeatmapStore {

    func delayForTestability() async throws {
        try await Task.sleep(nanoseconds: DataGenerationConstants.testabilityDelayNanoseconds)
    }

    func processStatsIntoDataset(_ stats: UsageStats) async throws -> HeatmapDataset {
        let validDailyUsage = try validateDailyUsage(stats.byDate)
        let dateRange = try calculateValidDateRange()
        return await buildDataset(from: validDailyUsage, dateRange: dateRange)
    }

    func findInvalidDates(in dailyUsage: [DailyUsage]) -> [String] {
        let dateFormatter = makeDateFormatter()
        return DailyUsageValidator.findInvalidDates(in: dailyUsage, using: dateFormatter)
    }

    func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = DataGenerationConstants.dateFormat
        formatter.timeZone = TimeZone.current
        return formatter
    }

    func formatInvalidDatesMessage(_ dates: [String]) -> String {
        "Invalid date format(s): \(dates.joined(separator: ", "))"
    }
}

// MARK: - Model Factories

private extension HeatmapStore {

    func makeHeatmapMonth(from info: HeatmapDateCalculator.MonthInfo) -> HeatmapMonth {
        HeatmapMonth(
            name: info.name,
            weekSpan: info.weekSpan,
            fullName: info.fullName,
            monthNumber: info.monthNumber,
            year: info.year
        )
    }
}
