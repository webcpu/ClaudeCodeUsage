//
//  HeatmapViewModel.swift
//  Business logic and state management for heatmap visualization
//
//  Provides MVVM architecture with proper separation of concerns,
//  optimized data processing, and reactive state management.
//
//  Split into extensions for focused responsibilities:
//    - +DataGeneration: Dataset generation and processing
//    - +SupportingTypes: Error types, summary stats, factory
//

import SwiftUI
import Foundation
import Observation
import ClaudeCodeUsageKit

// MARK: - Tooltip Position Calculator (Pure Functions)

enum TooltipPositionCalculator {
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

// MARK: - Heatmap View Model

/// View model managing heatmap data, state, and business logic
@Observable
@MainActor
public final class HeatmapViewModel {

    // MARK: - Observable Properties

    /// Current heatmap dataset
    public internal(set) var dataset: HeatmapDataset?

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

    // MARK: - Hover Handling

    /// Update hovered day based on location
    func updateHoveredDay(at location: CGPoint, in gridBounds: CGRect) {
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

    /// Find day at specific location in heatmap grid
    func findDayAtLocation(
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

    // MARK: - Performance Tracking

    /// Track hover event performance
    func trackHoverPerformance(_ operation: () -> Void) {
        performanceMetrics.hoverEventCount += 1
        let startTime = CFAbsoluteTimeGetCurrent()

        operation()

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.averageHoverTime = (performanceMetrics.averageHoverTime + duration) / 2
    }

    /// Record dataset generation time
    func recordDatasetGenerationTime(since startTime: CFAbsoluteTime) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        performanceMetrics.datasetGenerationTime = duration
        print("Generated heatmap dataset in \(String(format: "%.3f", duration))s")
    }

    /// Handle dataset generation error
    func handleDatasetError(_ error: Error) {
        self.error = error as? HeatmapError ?? .dataProcessingFailed(error.localizedDescription)
        self.dataset = nil
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
