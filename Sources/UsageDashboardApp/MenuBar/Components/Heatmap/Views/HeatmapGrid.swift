//
//  HeatmapGrid.swift
//  Reusable grid component for heatmap visualization
//
//  Provides optimized grid rendering with efficient hover detection,
//  accessibility support, and customizable appearance.
//

import SwiftUI
import Foundation

// MARK: - Heatmap Grid

/// High-performance grid component for rendering heatmap data
public struct HeatmapGrid: View {
    
    // MARK: - Properties
    
    /// Heatmap dataset to display
    let dataset: HeatmapDataset
    
    /// Configuration for grid appearance and behavior
    let configuration: HeatmapConfiguration
    
    /// Currently hovered day (optional)
    let hoveredDay: HeatmapDay?
    
    /// Hover event handler
    let onHover: (CGPoint) -> Void
    
    /// End hover event handler
    let onEndHover: () -> Void
    
    /// Accessibility configuration
    private let accessibility: HeatmapAccessibility
    
    // MARK: - Initialization
    
    /// Initialize heatmap grid
    /// - Parameters:
    ///   - dataset: Data to display
    ///   - configuration: Grid configuration
    ///   - hoveredDay: Currently hovered day
    ///   - accessibility: Accessibility settings
    ///   - onHover: Hover event handler
    ///   - onEndHover: End hover handler
    public init(
        dataset: HeatmapDataset,
        configuration: HeatmapConfiguration,
        hoveredDay: HeatmapDay? = nil,
        accessibility: HeatmapAccessibility = .default,
        onHover: @escaping (CGPoint) -> Void,
        onEndHover: @escaping () -> Void
    ) {
        self.dataset = dataset
        self.configuration = configuration
        self.hoveredDay = hoveredDay
        self.accessibility = accessibility
        self.onHover = onHover
        self.onEndHover = onEndHover
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: 8) {
            // Month labels header
            if configuration.showMonthLabels {
                monthLabelsHeader
            }
            
            // Main grid with day labels
            HStack(alignment: .top, spacing: 2) {
                // Day of week labels
                if configuration.showDayLabels {
                    dayLabelsColumn
                }
                
                // Calendar grid
                scrollableGrid
            }
        }
    }
    
    // MARK: - Month Labels Header
    
    @ViewBuilder
    private var monthLabelsHeader: some View {
        HStack(spacing: 0) {
            // Spacer for day labels column
            if configuration.showDayLabels {
                Spacer()
                    .frame(width: 30)
            }
            
            // Month labels positioned based on their week spans
            ZStack(alignment: .topLeading) {
                // Create a full-width container to match the scrollable grid
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: totalGridWidth, height: 20)
                
                // Position each month label at the correct offset
                ForEach(dataset.monthLabels) { month in
                    Text(month.name)
                        .font(configuration.monthLabelFont)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(accessibility.enableAccessibilityLabels ? month.fullName : "")
                        .offset(x: monthLabelOffset(for: month), y: 0)
                }
            }
        }
    }
    
    // MARK: - Month Label Positioning
    
    /// Calculate the horizontal offset for a month label based on its week span
    private func monthLabelOffset(for month: HeatmapMonth) -> CGFloat {
        let weekStartOffset = CGFloat(month.weekSpan.lowerBound) * configuration.cellSize
        let paddingOffset: CGFloat = 4 // Match the padding from gridContent
        return weekStartOffset + paddingOffset
    }
    
    /// Calculate the total width of the grid to match the scrollable content
    private var totalGridWidth: CGFloat {
        let weekCount = CGFloat(dataset.weeks.count)
        let totalSpacing = (weekCount - 1) * configuration.spacing
        let totalSquares = weekCount * configuration.squareSize
        return totalSquares + totalSpacing + 8 // 8 for horizontal padding (4 on each side)
    }
    
    // MARK: - Day Labels Column
    
    @ViewBuilder
    private var dayLabelsColumn: some View {
        VStack(spacing: configuration.spacing) {
            ForEach(Array(configuration.dayLabels.enumerated()), id: \.offset) { index, dayLabel in
                Text(dayLabel)
                    .font(configuration.dayLabelFont)
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: configuration.squareSize, alignment: .trailing)
                    .accessibilityHidden(!accessibility.enableAccessibilityLabels)
            }
        }
    }
    
    // MARK: - Scrollable Grid
    
    @ViewBuilder
    private var scrollableGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack {
                // Grid content
                gridContent
                
                // Hover overlay (performance-critical)
                if configuration.enableTooltips {
                    hoverOverlay
                }
            }
        }
        .accessibilityElement(children: accessibility.groupAccessibilityElements ? .contain : .ignore)
        .accessibilityLabel("Heatmap grid showing daily usage over time")
    }
    
    // MARK: - Grid Content
    
    @ViewBuilder
    private var gridContent: some View {
        HStack(spacing: configuration.spacing) {
            ForEach(dataset.weeks) { week in
                WeekColumn(
                    week: week,
                    configuration: configuration,
                    hoveredDay: hoveredDay,
                    accessibility: accessibility
                )
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Hover Overlay
    
    @ViewBuilder
    private var hoverOverlay: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onHover(value.location)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    onHover(location)
                case .ended:
                    onEndHover()
                }
            }
    }
}

// MARK: - Week Column

/// Single week column in the heatmap grid
private struct WeekColumn: View {
    let week: HeatmapWeek
    let configuration: HeatmapConfiguration
    let hoveredDay: HeatmapDay?
    let accessibility: HeatmapAccessibility
    
    var body: some View {
        VStack(spacing: configuration.spacing) {
            ForEach(0..<7, id: \.self) { dayIndex in
                DaySquareContainer(
                    day: week.days[safe: dayIndex] ?? nil,
                    configuration: configuration,
                    isHovered: hoveredDay?.id == week.days[safe: dayIndex]??.id,
                    accessibility: accessibility
                )
            }
        }
    }
}

// MARK: - Day Square Container

/// Container for day squares handling both filled and empty states
private struct DaySquareContainer: View {
    let day: HeatmapDay?
    let configuration: HeatmapConfiguration
    let isHovered: Bool
    let accessibility: HeatmapAccessibility
    
    var body: some View {
        Group {
            if let day = day {
                DaySquare(
                    day: day,
                    configuration: configuration,
                    isHovered: isHovered,
                    accessibility: accessibility
                )
            } else {
                // Empty placeholder for consistent grid layout
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: configuration.squareSize, height: configuration.squareSize)
            }
        }
    }
}

// MARK: - Day Square

/// Individual day square component with optimized rendering
private struct DaySquare: View {
    let day: HeatmapDay
    let configuration: HeatmapConfiguration
    let isHovered: Bool
    let accessibility: HeatmapAccessibility
    
    var body: some View {
        Rectangle()
            .fill(day.color) // Pre-computed color for performance
            .frame(width: configuration.squareSize, height: configuration.squareSize)
            .cornerRadius(configuration.cornerRadius)
            .overlay(borderOverlay)
            .scaleEffect(scaleEffect)
            .animation(hoverAnimation, value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }
    
    // MARK: - Border Overlay
    
    @ViewBuilder
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: configuration.cornerRadius)
            .stroke(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if day.isToday {
            return configuration.todayHighlightColor
        } else if isHovered {
            return Color.primary
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        if day.isToday {
            return configuration.todayHighlightWidth
        } else if isHovered {
            return 1
        } else {
            return 0
        }
    }
    
    // MARK: - Scale Effect
    
    private var scaleEffect: CGFloat {
        if configuration.scaleOnHover && isHovered {
            return configuration.hoverScale
        } else {
            return 1.0
        }
    }
    
    // MARK: - Animation
    
    private var hoverAnimation: Animation? {
        if configuration.animationDuration > 0 {
            return .easeInOut(duration: configuration.animationDuration)
        } else {
            return nil
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityLabel: String {
        guard accessibility.enableAccessibilityLabels else { return "" }
        return "\(accessibility.dateAccessibilityPrefix) \(day.dateString)"
    }
    
    private var accessibilityValue: String {
        guard accessibility.enableAccessibilityValues else { return "" }
        return "\(accessibility.costAccessibilityPrefix) \(day.costString)"
    }
}

// MARK: - Grid Layout Calculations

/// Utility for calculating grid layout dimensions
public struct HeatmapGridLayout {
    let configuration: HeatmapConfiguration
    let dataset: HeatmapDataset
    
    /// Total width of the grid content
    public var contentWidth: CGFloat {
        let weekCount = CGFloat(dataset.weeks.count)
        let totalSpacing = (weekCount - 1) * configuration.spacing
        let totalSquares = weekCount * configuration.squareSize
        return totalSquares + totalSpacing + 8 // 8 for padding
    }
    
    /// Total height of the grid content
    public var contentHeight: CGFloat {
        let dayCount: CGFloat = 7
        let totalSpacing = (dayCount - 1) * configuration.spacing
        let totalSquares = dayCount * configuration.squareSize
        return totalSquares + totalSpacing
    }
    
    /// Size required for the entire heatmap including labels
    public var totalSize: CGSize {
        let width = contentWidth + (configuration.showDayLabels ? 30 : 0)
        let height = contentHeight + (configuration.showMonthLabels ? 20 : 0)
        return CGSize(width: width, height: height)
    }
    
    /// Calculate position of a day square
    /// - Parameters:
    ///   - weekIndex: Week index in the grid
    ///   - dayIndex: Day index within the week
    /// - Returns: Position of the day square
    public func dayPosition(weekIndex: Int, dayIndex: Int) -> CGPoint {
        let x = CGFloat(weekIndex) * configuration.cellSize + 4 // 4 for padding
        let y = CGFloat(dayIndex) * configuration.cellSize
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Performance Optimizations

/// Performance-optimized grid rendering strategies
public enum HeatmapGridPerformance {
    
    /// Maximum number of days before performance optimizations kick in
    static let performanceThreshold = 400
    
    /// Check if dataset requires performance optimizations
    /// - Parameter dataset: Dataset to check
    /// - Returns: True if performance optimizations should be applied
    public static func requiresOptimization(for dataset: HeatmapDataset) -> Bool {
        let totalDays = dataset.weeks.reduce(0) { count, week in
            count + week.days.compactMap { $0 }.count
        }
        return totalDays > performanceThreshold
    }
    
    /// Get recommended configuration for large datasets
    /// - Parameter baseConfig: Base configuration to optimize
    /// - Returns: Performance-optimized configuration
    public static func optimizedConfiguration(from baseConfig: HeatmapConfiguration) -> HeatmapConfiguration {
        var config = baseConfig
        config = HeatmapConfiguration(
            squareSize: baseConfig.squareSize,
            spacing: baseConfig.spacing,
            cornerRadius: baseConfig.cornerRadius,
            padding: baseConfig.padding,
            colorScheme: baseConfig.colorScheme,
            showMonthLabels: baseConfig.showMonthLabels,
            showDayLabels: baseConfig.showDayLabels,
            showLegend: baseConfig.showLegend,
            monthLabelFont: baseConfig.monthLabelFont,
            dayLabelFont: baseConfig.dayLabelFont,
            legendFont: baseConfig.legendFont,
            enableTooltips: baseConfig.enableTooltips,
            tooltipDelay: 0.0, // No delay for better performance
            highlightToday: baseConfig.highlightToday,
            todayHighlightColor: baseConfig.todayHighlightColor,
            todayHighlightWidth: baseConfig.todayHighlightWidth,
            animationDuration: 0.0, // Disable animations
            animateColorTransitions: false,
            scaleOnHover: false, // Disable scaling
            hoverScale: 1.0
        )
        return config
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapGrid_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = generateSampleDataset()
        
        HeatmapGrid(
            dataset: sampleData,
            configuration: .default,
            onHover: { _ in },
            onEndHover: { }
        )
        .frame(height: 200)
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private static func generateSampleDataset() -> HeatmapDataset {
        let weeks = (0..<52).map { weekIndex in
            let days = (0..<7).map { dayIndex -> HeatmapDay? in
                let cost = Double.random(in: 0...5)
                let date = Calendar.current.date(byAdding: .day, value: weekIndex * 7 + dayIndex, to: Date())!
                return HeatmapDay(
                    date: date,
                    cost: cost,
                    dayOfYear: weekIndex * 7 + dayIndex,
                    weekOfYear: weekIndex,
                    dayOfWeek: dayIndex,
                    maxCost: 5.0
                )
            }
            return HeatmapWeek(weekNumber: weekIndex, days: days)
        }
        
        let months = [
            HeatmapMonth(name: "Jan", weekSpan: 0..<4),
            HeatmapMonth(name: "Feb", weekSpan: 4..<8),
            HeatmapMonth(name: "Mar", weekSpan: 8..<13),
        ]
        
        return HeatmapDataset(
            weeks: weeks,
            monthLabels: months,
            maxCost: 5.0,
            dateRange: Date()...Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        )
    }
}
#endif