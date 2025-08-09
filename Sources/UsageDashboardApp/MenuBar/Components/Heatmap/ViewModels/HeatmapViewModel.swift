//
//  HeatmapViewModel.swift
//  Business logic and state management for heatmap visualization
//
//  Provides MVVM architecture with proper separation of concerns,
//  optimized data processing, and reactive state management.
//

import SwiftUI
import Foundation
import Combine
import ClaudeCodeUsage

// MARK: - Heatmap View Model

/// View model managing heatmap data, state, and business logic
@MainActor
public final class HeatmapViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current heatmap dataset
    @Published public private(set) var dataset: HeatmapDataset?
    
    /// Currently hovered day
    @Published public var hoveredDay: HeatmapDay?
    
    /// Tooltip position for hovered day
    @Published public var tooltipPosition: CGPoint = .zero
    
    /// Loading state
    @Published public private(set) var isLoading: Bool = false
    
    /// Error state
    @Published public private(set) var error: HeatmapError?
    
    /// Configuration settings
    @Published public var configuration: HeatmapConfiguration {
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
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Performance metrics
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    /// - Parameter configuration: Heatmap configuration (defaults to standard)
    public init(configuration: HeatmapConfiguration = .default) {
        self.configuration = configuration
        setupBindings()
    }
    
    // MARK: - Public Interface
    
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
        performanceMetrics.hoverEventCount += 1
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            performanceMetrics.averageHoverTime = (performanceMetrics.averageHoverTime + duration) / 2
        }
        
        guard let dataset = dataset else {
            hoveredDay = nil
            return
        }
        
        let day = findDayAtLocation(location, in: gridBounds, dataset: dataset)
        
        // Only update if different day to minimize state changes
        if hoveredDay?.id != day?.id {
            hoveredDay = day
            
            if let day = day {
                // Calculate the exact position of the day square
                let cellSize = configuration.cellSize
                let weekIndex = day.weekOfYear
                let dayIndex = day.dayOfWeek
                
                // Account for the horizontal padding applied to grid content (4 points from HeatmapGrid)
                let gridContentPadding: CGFloat = 4
                
                // Calculate center of the day square
                let squareCenterX = CGFloat(weekIndex) * cellSize + (cellSize / 2) + gridContentPadding
                let squareCenterY = CGFloat(dayIndex) * cellSize + (cellSize / 2)
                
                // Position tooltip above the day square
                tooltipPosition = CGPoint(
                    x: squareCenterX,
                    y: squareCenterY - configuration.squareSize - 20 // Above the square with gap
                )
            }
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
    
    // MARK: - Private Methods
    
    /// Setup reactive bindings
    private func setupBindings() {
        // Clear error when starting new operations
        $isLoading
            .filter { $0 }
            .sink { [weak self] _ in
                self?.error = nil
            }
            .store(in: &cancellables)
    }
    
    /// Generate heatmap dataset from usage statistics
    /// - Parameter stats: Usage statistics to process
    private func generateDataset(from stats: UsageStats) async {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Calculate date range (365 days ending today, adjusted for complete weeks)
            let dateRange = dateCalculator.rollingDateRangeWithCompleteWeeks(numberOfDays: 365)
            
            // Validate date range
            let validationErrors = dateCalculator.validateDateRange(
                startDate: dateRange.start,
                endDate: dateRange.end
            )
            
            guard validationErrors.isEmpty else {
                throw HeatmapError.invalidDateRange(validationErrors.joined(separator: ", "))
            }
            
            // Generate heatmap data
            let weeks = await generateWeeksData(
                from: dateRange.start,
                to: dateRange.end,
                dailyUsage: stats.byDate
            )
            
            // Generate month labels
            let monthLabels = generateMonthLabels(from: dateRange.start, to: dateRange.end)
            
            // Calculate maximum cost for scaling
            let maxCost = stats.byDate.map(\.totalCost).max() ?? 1.0
            
            // Create dataset
            let dataset = HeatmapDataset(
                weeks: weeks,
                monthLabels: monthLabels,
                maxCost: maxCost,
                dateRange: dateRange.start...dateRange.end
            )
            
            self.dataset = dataset
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            performanceMetrics.datasetGenerationTime = duration
            
            print("Generated heatmap dataset in \(String(format: "%.3f", duration))s")
            
        } catch {
            self.error = error as? HeatmapError ?? .dataProcessingFailed(error.localizedDescription)
        }
    }
    
    /// Generate weeks data for heatmap
    private func generateWeeksData(
        from startDate: Date,
        to endDate: Date,
        dailyUsage: [DailyUsage]
    ) async -> [HeatmapWeek] {
        // Create cost lookup dictionary for O(1) access
        let costLookup = Dictionary(
            dailyUsage.map { ($0.date, $0.totalCost) },
            uniquingKeysWith: { first, _ in first }
        )
        
        let maxCost = dailyUsage.map(\.totalCost).max() ?? 1.0
        
        // Generate weeks layout
        let weeksLayout = dateCalculator.generateWeeksLayout(from: startDate, to: endDate)
        
        var weeks: [HeatmapWeek] = []
        weeks.reserveCapacity(weeksLayout.count)
        
        for (weekIndex, weekDates) in weeksLayout.enumerated() {
            var weekDays: [HeatmapDay?] = Array(repeating: nil, count: 7)
            
            for (dayIndex, dayDate) in weekDates.enumerated() {
                guard let dayDate = dayDate else { continue }
                
                // Only include days within our target range
                if dayDate >= startDate && dayDate <= endDate {
                    let dateString = dateCalculator.formatDateAsID(dayDate)
                    let cost = costLookup[dateString] ?? 0.0
                    let calendarProps = dateCalculator.calendarProperties(for: dayDate)
                    
                    weekDays[dayIndex] = HeatmapDay(
                        date: dayDate,
                        cost: cost,
                        dayOfYear: calendarProps.dayOfYear,
                        weekOfYear: weekIndex,
                        dayOfWeek: dayIndex,
                        maxCost: maxCost
                    )
                }
            }
            
            weeks.append(HeatmapWeek(weekNumber: weekIndex, days: weekDays))
        }
        
        return weeks
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
    
    /// Find day at specific location in heatmap grid
    private func findDayAtLocation(
        _ location: CGPoint,
        in gridBounds: CGRect,
        dataset: HeatmapDataset
    ) -> HeatmapDay? {
        let cellSize = configuration.cellSize
        
        // Account for the horizontal padding applied to grid content (4 points from HeatmapGrid)
        let gridContentPadding: CGFloat = 4
        
        // Convert location to grid coordinates
        let weekIndex = Int((location.x - gridContentPadding) / cellSize)
        let dayIndex = Int(location.y / cellSize)
        
        // Validate coordinates
        guard weekIndex >= 0,
              weekIndex < dataset.weeks.count,
              dayIndex >= 0,
              dayIndex < 7 else {
            return nil
        }
        
        return dataset.weeks[weekIndex].days[dayIndex]
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
