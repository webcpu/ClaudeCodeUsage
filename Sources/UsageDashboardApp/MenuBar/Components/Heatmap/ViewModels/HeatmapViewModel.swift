//
//  HeatmapViewModel.swift
//  Business logic and state management for heatmap visualization
//
//  Provides MVVM architecture with proper separation of concerns,
//  optimized data processing, and reactive state management.
//

import SwiftUI
import Foundation
import Observation
import ClaudeCodeUsageKit

// MARK: - Tooltip Position Calculator (Pure Functions)

private enum TooltipPositionCalculator {
    /// Calculate tooltip position for a hovered day
    /// - Parameters:
    ///   - day: The day being hovered
    ///   - cellSize: Size of each cell in the grid
    ///   - squareSize: Size of the day square
    ///   - gridContentPadding: Horizontal padding applied to grid content
    /// - Returns: Position for the tooltip
    static func position(
        for day: HeatmapDay,
        cellSize: CGFloat,
        squareSize: CGFloat,
        gridContentPadding: CGFloat = 4
    ) -> CGPoint {
        let squareCenterX = CGFloat(day.weekOfYear) * cellSize + (cellSize / 2) + gridContentPadding
        let squareCenterY = CGFloat(day.dayOfWeek) * cellSize + (cellSize / 2)
        return CGPoint(
            x: squareCenterX,
            y: squareCenterY - squareSize - 20
        )
    }
}

// MARK: - Date Validation (Pure Functions)

private enum DailyUsageValidator {
    /// Validate daily usage dates and return invalid date strings
    /// - Parameters:
    ///   - dailyUsage: Array of daily usage records
    ///   - dateFormatter: Formatter to validate dates
    /// - Returns: Array of invalid date strings
    static func findInvalidDates(in dailyUsage: [DailyUsage], using dateFormatter: DateFormatter) -> [String] {
        dailyUsage
            .map(\.date)
            .filter { dateFormatter.date(from: $0) == nil }
    }
}

// MARK: - Heatmap View Model

/// View model managing heatmap data, state, and business logic
@Observable
@MainActor
public final class HeatmapViewModel {
    
    // MARK: - Observable Properties
    
    /// Current heatmap dataset
    public private(set) var dataset: HeatmapDataset?
    
    /// Currently hovered day
    public var hoveredDay: HeatmapDay?
    
    /// Tooltip position for hovered day
    public var tooltipPosition: CGPoint = .zero
    
    /// Loading state
    public private(set) var isLoading: Bool = false
    
    /// Error state
    public private(set) var error: HeatmapError?
    
    /// Configuration settings
    public var configuration: HeatmapConfiguration {
        didSet {
            // Regenerate dataset when configuration changes
            if let stats = currentStats, configuration != oldValue {
                Task {
                    await generateDataset(from: stats)
                }
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// Current usage stats
    private var currentStats: UsageStats?
    
    /// Date calculator utility
    private let dateCalculator = HeatmapDateCalculator.shared
    
    /// Color manager for optimized color calculations
    private let colorManager = HeatmapColorManager.shared
    
    // Note: Removed Combine cancellables as @Observable doesn't need them
    
    /// Performance metrics
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    /// - Parameter configuration: Heatmap configuration (defaults to standard)
    public init(configuration: HeatmapConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Interface (High Level)

    /// Update heatmap with new usage statistics
    /// - Parameter stats: Usage statistics to visualize
    public func updateStats(_ stats: UsageStats) async {
        isLoading = true
        error = nil
        currentStats = stats

        await generateDataset(from: stats)

        isLoading = false
    }

    /// Handle hover at specific location
    /// - Parameters:
    ///   - location: Cursor location in heatmap coordinate space
    ///   - gridBounds: Bounds of the heatmap grid
    public func handleHover(at location: CGPoint, in gridBounds: CGRect) {
        trackHoverPerformance {
            updateHoveredDay(at: location, in: gridBounds)
        }
    }

    /// End hover interaction
    public func endHover() {
        hoveredDay = nil
    }

    /// Get accessibility label for a specific day
    /// - Parameter day: The day to get accessibility info for
    /// - Returns: Accessibility label string
    public func accessibilityLabel(for day: HeatmapDay) -> String {
        let datePrefix = "Usage on"
        let costPrefix = "Cost:"
        return "\(datePrefix) \(day.dateString), \(costPrefix) \(day.costString)"
    }

    /// Get summary statistics for the current dataset
    public var summaryStats: SummaryStats? {
        guard let dataset = dataset else { return nil }

        return SummaryStats(
            totalCost: dataset.totalCost,
            daysWithUsage: dataset.daysWithUsage,
            totalDays: dataset.allDays.count,
            maxDailyCost: dataset.maxCost,
            averageDailyCost: dataset.totalCost / Double(max(1, dataset.allDays.count)),
            dateRange: dataset.dateRange
        )
    }

    // MARK: - Data Generation (Orchestration)

    /// Generate heatmap dataset from usage statistics
    /// - Parameter stats: Usage statistics to process
    private func generateDataset(from stats: UsageStats) async {
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
    private func buildDataset(
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

    // MARK: - Week/Month Generation (Mid Level)

    /// Generate weeks data for heatmap
    private func generateWeeksData(
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
    private func buildWeeks(
        from weeksLayout: [[Date?]],
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapWeek] {
        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(weeksLayout.count)

        for (weekIndex, weekDates) in weeksLayout.enumerated() {
            let weekDays = buildWeekDays(
                from: weekDates,
                weekIndex: weekIndex,
                costLookup: costLookup,
                maxCost: maxCost,
                dateRange: dateRange
            )
            weeks.append(HeatmapWeek(weekNumber: weekIndex, days: weekDays))
        }

        return weeks
    }

    /// Build days array for a single week
    private func buildWeekDays(
        from weekDates: [Date?],
        weekIndex: Int,
        costLookup: [String: Double],
        maxCost: Double,
        dateRange: ClosedRange<Date>
    ) -> [HeatmapDay?] {
        var weekDays: [HeatmapDay?] = Array(repeating: nil, count: 7)

        for (dayIndex, dayDate) in weekDates.enumerated() {
            guard let dayDate = dayDate, dateRange.contains(dayDate) else { continue }
            weekDays[dayIndex] = createHeatmapDay(
                for: dayDate,
                dayIndex: dayIndex,
                weekIndex: weekIndex,
                costLookup: costLookup,
                maxCost: maxCost
            )
        }

        return weekDays
    }

    /// Generate month labels for heatmap header
    private func generateMonthLabels(from startDate: Date, to endDate: Date) -> [HeatmapMonth] {
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

    // MARK: - Calculations (Low Level)

    /// Validate daily usage dates
    private func validateDailyUsage(_ dailyUsage: [DailyUsage]) throws -> [DailyUsage] {
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
    private func calculateValidDateRange() throws -> (start: Date, end: Date) {
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
    private func buildCostLookup(from dailyUsage: [DailyUsage]) -> [String: Double] {
        Dictionary(
            dailyUsage.map { ($0.date, $0.totalCost) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Calculate maximum cost from daily usage
    private func calculateMaxCost(from dailyUsage: [DailyUsage]) -> Double {
        dailyUsage.map(\.totalCost).max() ?? 1.0
    }

    /// Create a HeatmapDay for a specific date
    private func createHeatmapDay(
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

    /// Find day at specific location in heatmap grid
    private func findDayAtLocation(
        _ location: CGPoint,
        in gridBounds: CGRect,
        dataset: HeatmapDataset
    ) -> HeatmapDay? {
        let cellSize = configuration.cellSize
        let gridContentPadding: CGFloat = 4

        let weekIndex = Int((location.x - gridContentPadding) / cellSize)
        let dayIndex = Int(location.y / cellSize)

        guard weekIndex >= 0,
              weekIndex < dataset.weeks.count,
              dayIndex >= 0,
              dayIndex < 7 else {
            return nil
        }

        return dataset.weeks[weekIndex].days[dayIndex]
    }

    // MARK: - Hover Handling (Mid Level)

    /// Update hovered day based on location
    private func updateHoveredDay(at location: CGPoint, in gridBounds: CGRect) {
        guard let dataset = dataset else {
            hoveredDay = nil
            return
        }

        let day = findDayAtLocation(location, in: gridBounds, dataset: dataset)

        guard hoveredDay?.id != day?.id else { return }

        hoveredDay = day

        if let day = day {
            tooltipPosition = TooltipPositionCalculator.position(
                for: day,
                cellSize: configuration.cellSize,
                squareSize: configuration.squareSize
            )
        }
    }

    // MARK: - Performance Tracking (Low Level)

    /// Track hover event performance
    private func trackHoverPerformance(_ operation: () -> Void) {
        performanceMetrics.hoverEventCount += 1
        let startTime = CFAbsoluteTimeGetCurrent()

        operation()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.averageHoverTime = (performanceMetrics.averageHoverTime + duration) / 2
    }

    /// Record dataset generation time
    private func recordDatasetGenerationTime(since startTime: CFAbsoluteTime) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.datasetGenerationTime = duration
        print("Generated heatmap dataset in \(String(format: "%.3f", duration))s")
    }

    /// Handle dataset generation error
    private func handleDatasetError(_ error: Error) {
        self.error = error as? HeatmapError ?? .dataProcessingFailed(error.localizedDescription)
        self.dataset = nil
    }
}

// MARK: - Supporting Types

/// Heatmap-specific error types
public enum HeatmapError: Error, LocalizedError {
    case invalidDateRange(String)
    case dataProcessingFailed(String)
    case configurationInvalid(String)
    case performanceThresholdExceeded
    
    public var errorDescription: String? {
        switch self {
        case .invalidDateRange(let message):
            return "Invalid date range: \(message)"
        case .dataProcessingFailed(let message):
            return "Data processing failed: \(message)"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        case .performanceThresholdExceeded:
            return "Performance threshold exceeded - consider using a smaller date range"
        }
    }
}

/// Summary statistics for heatmap data
public struct SummaryStats {
    public let totalCost: Double
    public let daysWithUsage: Int
    public let totalDays: Int
    public let maxDailyCost: Double
    public let averageDailyCost: Double
    public let dateRange: ClosedRange<Date>
    
    /// Usage frequency as percentage
    public var usageFrequency: Double {
        guard totalDays > 0 else { return 0 }
        return Double(daysWithUsage) / Double(totalDays) * 100
    }
    
    /// Formatted date range string
    public var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: dateRange.lowerBound)) - \(formatter.string(from: dateRange.upperBound))"
    }
}

/// Performance metrics for monitoring
private struct PerformanceMetrics {
    var datasetGenerationTime: Double = 0
    var hoverEventCount: Int = 0
    var averageHoverTime: Double = 0
    
    var summary: String {
        return """
        Dataset Generation: \(String(format: "%.3f", datasetGenerationTime))s
        Hover Events: \(hoverEventCount)
        Avg Hover Time: \(String(format: "%.4f", averageHoverTime))s
        """
    }
}

// MARK: - View Model Factory

/// Factory for creating pre-configured view models
public struct HeatmapViewModelFactory {
    
    /// Create view model optimized for performance
    @MainActor 
    public static func performanceOptimized() -> HeatmapViewModel {
        return HeatmapViewModel(configuration: .performanceOptimized)
    }
    
    /// Create view model for compact displays
    @MainActor 
    public static func compact() -> HeatmapViewModel {
        return HeatmapViewModel(configuration: .compact)
    }
    
    /// Create view model with custom configuration
    /// - Parameter configuration: Custom configuration
    /// - Returns: Configured view model
    @MainActor 
    public static func custom(_ configuration: HeatmapConfiguration) -> HeatmapViewModel {
        return HeatmapViewModel(configuration: configuration)
    }
}

// MARK: - Extensions

public extension HeatmapViewModel {
    
    /// Whether the heatmap has data to display
    var hasData: Bool {
        dataset?.weeks.isEmpty == false
    }
    
    /// Whether the heatmap is in an error state
    var hasError: Bool {
        error != nil
    }
    
    /// Whether the heatmap is currently interactive (not loading, has data)
    var isInteractive: Bool {
        !isLoading && hasData && !hasError
    }
}
