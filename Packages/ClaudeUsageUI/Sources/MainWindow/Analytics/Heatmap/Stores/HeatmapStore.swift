//
//  HeatmapStore.swift
//  Business logic and state management for heatmap visualization
//
//  Split into extensions for focused responsibilities:
//    - +DataGeneration: Dataset generation and processing
//    - +SupportingTypes: Error types, summary stats, factory
//

import SwiftUI
import Foundation
import Observation
import ClaudeUsageCore
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "HeatmapStore")

// MARK: - Constants

private enum ViewModelConstants {
    static let gridContentPadding: CGFloat = 4
    static let daysPerWeek = 7
}

private enum AccessibilityStrings {
    static let datePrefix = "Usage on"
    static let costPrefix = "Cost:"
}

// MARK: - Heatmap View Model

/// View model managing heatmap data, state, and business logic
@Observable
@MainActor
public final class HeatmapStore {

    // MARK: - Observable Properties

    /// Current heatmap dataset
    public internal(set) var dataset: HeatmapDataset?

    /// Currently hovered day
    public var hoveredDay: HeatmapDay?

    /// Tooltip position for hovered day
    public var tooltipPosition: CGPoint = .zero

    /// Whether tooltip should flip to left side (near right edge)
    public var tooltipShouldFlipLeft: Bool = false

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

    // MARK: - Internal Properties

    /// Current usage stats
    var currentStats: UsageStats?

    /// Date calculator utility
    let dateCalculator = HeatmapDateCalculator.shared

    /// Color manager for optimized color calculations
    let colorManager = HeatmapColorManager.shared

    /// Performance metrics
    var performanceMetrics = PerformanceMetrics()

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

    /// Synchronous update for capture mode (ImageRenderer doesn't wait for .task)
    public func updateStatsSync(_ stats: UsageStats) {
        error = nil
        currentStats = stats

        do {
            let validDailyUsage = try validateDailyUsage(stats.byDate)
            let dateRange = try calculateValidDateRange(from: validDailyUsage)
            dataset = buildDatasetSync(from: validDailyUsage, dateRange: dateRange)
        } catch {
            handleDatasetError(error)
        }
    }

    /// Synchronous dataset building for capture mode
    private func buildDatasetSync(
        from dailyUsage: [DailyUsage],
        dateRange: (start: Date, end: Date)
    ) -> HeatmapDataset {
        let costLookup = buildCostLookup(from: dailyUsage)
        let maxCost = calculateMaxCost(from: dailyUsage)
        let weeksLayout = dateCalculator.generateWeeksLayout(from: dateRange.start, to: dateRange.end)

        let weeks = buildWeeks(
            from: weeksLayout,
            costLookup: costLookup,
            maxCost: maxCost,
            dateRange: dateRange.start...dateRange.end
        )

        return HeatmapDataset(
            weeks: weeks,
            monthLabels: generateMonthLabels(from: dateRange.start, to: dateRange.end),
            maxCost: calculateMaxCost(from: dailyUsage),
            dateRange: dateRange.start...dateRange.end
        )
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
    public func accessibilityLabel(for day: HeatmapDay) -> String {
        formatAccessibilityLabel(dateString: day.dateString, costString: day.costString)
    }

    /// Get summary statistics for the current dataset
    public var summaryStats: SummaryStats? {
        dataset.map(buildSummaryStats)
    }

    // MARK: - Hover Handling

    /// Update hovered day based on location
    func updateHoveredDay(at location: CGPoint, in gridBounds: CGRect) {
        guard let dataset else {
            applyHoverState(.empty)
            return
        }

        let newState = calculateHoverState(at: location, in: dataset)
        guard shouldApplyHoverState(newState) else { return }
        applyHoverState(newState)
    }

    // MARK: - Performance Tracking

    /// Track hover event performance
    func trackHoverPerformance(_ operation: () -> Void) {
        let duration = measureDuration(operation)
        updateHoverMetrics(duration: duration)
    }

    /// Record dataset generation time
    func recordDatasetGenerationTime(since startTime: CFAbsoluteTime) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.datasetGenerationTime = duration
        logger.debug("Generated heatmap dataset in \(String(format: "%.3f", duration))s")
    }

    /// Handle dataset generation error
    func handleDatasetError(_ error: Error) {
        self.error = error as? HeatmapError ?? .dataProcessingFailed(error.localizedDescription)
        self.dataset = nil
    }
}

// MARK: - Public State Properties

public extension HeatmapStore {

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

// MARK: - Hover State Value Type

/// Immutable hover state computed from location
@MainActor
private struct HoverState {
    let day: HeatmapDay?
    let tooltipPosition: CGPoint
    let tooltipShouldFlipLeft: Bool

    static let empty = HoverState(day: nil, tooltipPosition: .zero, tooltipShouldFlipLeft: false)
}

// MARK: - Hover State Helpers

private extension HeatmapStore {

    func shouldApplyHoverState(_ newState: HoverState) -> Bool {
        hoveredDay?.id != newState.day?.id
    }

    func applyHoverState(_ state: HoverState) {
        hoveredDay = state.day
        tooltipPosition = state.tooltipPosition
        tooltipShouldFlipLeft = state.tooltipShouldFlipLeft
    }
}

// MARK: - Pure Hover State Calculation

private extension HeatmapStore {

    func calculateHoverState(at location: CGPoint, in dataset: HeatmapDataset) -> HoverState {
        guard let day = findDayAtLocation(location, in: dataset) else {
            return .empty
        }
        return buildHoverState(for: day, totalWeeks: dataset.weeks.count)
    }

    func findDayAtLocation(_ location: CGPoint, in dataset: HeatmapDataset) -> HeatmapDay? {
        let indices = calculateGridIndices(from: location)
        guard isValidGridPosition(indices, in: dataset) else { return nil }
        return dataset.weeks[indices.week].days[indices.day]
    }

    func buildHoverState(for day: HeatmapDay, totalWeeks: Int) -> HoverState {
        HoverState(
            day: day,
            tooltipPosition: calculateTooltipPosition(for: day),
            tooltipShouldFlipLeft: shouldFlipTooltipLeft(for: day, totalWeeks: totalWeeks)
        )
    }

    func calculateTooltipPosition(for day: HeatmapDay) -> CGPoint {
        TooltipPositionCalculator.position(
            for: day,
            cellSize: configuration.cellSize,
            squareSize: configuration.squareSize
        )
    }

    func shouldFlipTooltipLeft(for day: HeatmapDay, totalWeeks: Int) -> Bool {
        TooltipPositionCalculator.shouldFlipLeft(day: day, totalWeeks: totalWeeks)
    }
}

// MARK: - Grid Index Calculations

private extension HeatmapStore {

    typealias GridIndices = (week: Int, day: Int)

    func calculateGridIndices(from location: CGPoint) -> GridIndices {
        let cellSize = configuration.cellSize
        let weekIndex = Int((location.x - ViewModelConstants.gridContentPadding) / cellSize)
        let dayIndex = Int(location.y / cellSize)
        return (week: weekIndex, day: dayIndex)
    }

    func isValidGridPosition(_ indices: GridIndices, in dataset: HeatmapDataset) -> Bool {
        isValidWeekIndex(indices.week, in: dataset) && isValidDayIndex(indices.day)
    }

    func isValidWeekIndex(_ index: Int, in dataset: HeatmapDataset) -> Bool {
        index >= 0 && index < dataset.weeks.count
    }

    func isValidDayIndex(_ index: Int) -> Bool {
        index >= 0 && index < ViewModelConstants.daysPerWeek
    }
}

// MARK: - Performance Measurement

private extension HeatmapStore {

    func measureDuration(_ operation: () -> Void) -> Double {
        let startTime = CFAbsoluteTimeGetCurrent()
        operation()
        return CFAbsoluteTimeGetCurrent() - startTime
    }

    func updateHoverMetrics(duration: Double) {
        performanceMetrics.hoverEventCount += 1
        performanceMetrics.averageHoverTime = calculateRunningAverage(
            current: performanceMetrics.averageHoverTime,
            newValue: duration
        )
    }

    func calculateRunningAverage(current: Double, newValue: Double) -> Double {
        (current + newValue) / 2
    }
}

// MARK: - Pure Transformation Functions

private extension HeatmapStore {

    func buildSummaryStats(from dataset: HeatmapDataset) -> SummaryStats {
        SummaryStats(
            totalCost: dataset.totalCost,
            daysWithUsage: dataset.daysWithUsage,
            totalDays: dataset.allDays.count,
            maxDailyCost: dataset.maxCost,
            averageDailyCost: calculateAverageDailyCost(total: dataset.totalCost, days: dataset.allDays.count),
            dateRange: dataset.dateRange
        )
    }

    func calculateAverageDailyCost(total: Double, days: Int) -> Double {
        total / Double(max(1, days))
    }

    func formatAccessibilityLabel(dateString: String, costString: String) -> String {
        "\(AccessibilityStrings.datePrefix) \(dateString), \(AccessibilityStrings.costPrefix) \(costString)"
    }
}

// MARK: - Supporting Types

/// Tooltip position calculation (pure functions)
enum TooltipPositionCalculator {
    /// Fixed Y position for tooltip (in header area)
    private static let fixedY: CGFloat = 30

    /// Calculate tooltip position for a hovered day
    /// - Parameters:
    ///   - day: The day being hovered
    ///   - cellSize: Size of each cell in the grid
    ///   - squareSize: Size of the day square (unused, kept for API compatibility)
    ///   - gridContentPadding: Horizontal padding applied to grid content
    /// - Returns: Position for the tooltip (X follows column, Y fixed at header)
    static func position(
        for day: HeatmapDay,
        cellSize: CGFloat,
        squareSize: CGFloat,
        gridContentPadding: CGFloat = 4
    ) -> CGPoint {
        let squareCenterX = CGFloat(day.weekOfYear) * cellSize + (cellSize / 2) + gridContentPadding

        return CGPoint(
            x: squareCenterX,
            y: fixedY
        )
    }

    /// Determine if tooltip should appear on the left side of the cell
    static func shouldFlipLeft(day: HeatmapDay, totalWeeks: Int) -> Bool {
        let weeksFromEnd = totalWeeks - day.weekOfYear
        return weeksFromEnd < 8
    }
}

/// Date validation (pure functions)
enum DailyUsageValidator {
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
