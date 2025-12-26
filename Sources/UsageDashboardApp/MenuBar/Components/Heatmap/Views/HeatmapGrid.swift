//
//  HeatmapGrid.swift
//  Reusable grid component for heatmap visualization
//

import SwiftUI

// MARK: - Border Style (Pure Data)

private struct BorderStyle {
    let color: Color
    let width: CGFloat

    static let none = BorderStyle(color: .clear, width: 0)

    static func forDay(_ day: HeatmapDay, isHovered: Bool, config: HeatmapConfiguration) -> BorderStyle {
        if day.isToday {
            return BorderStyle(color: config.todayHighlightColor, width: config.todayHighlightWidth)
        } else if isHovered {
            return BorderStyle(color: .primary, width: 1)
        } else {
            return .none
        }
    }
}

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
    
    // MARK: - Public API (High Level)

    public var body: some View {
        VStack(spacing: 8) {
            mainGridLayout
        }
    }

    // MARK: - Orchestration (Coordination)

    @ViewBuilder
    private var mainGridLayout: some View {
        HStack(alignment: .top, spacing: 2) {
            dayLabelsSidebar
            scrollableGridWithMonthLabels
        }
    }

    @ViewBuilder
    private var dayLabelsSidebar: some View {
        if configuration.showDayLabels {
            VStack(spacing: 0) {
                monthLabelsSpacer
                dayLabelsColumn
            }
        }
    }

    @ViewBuilder
    private var scrollableGridWithMonthLabels: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 8) {
                monthLabelsRowIfNeeded
                gridWithHoverOverlay
            }
        }
        .accessibilityElement(children: accessibility.groupAccessibilityElements ? .contain : .ignore)
        .accessibilityLabel("Heatmap grid showing daily usage over time")
    }

    @ViewBuilder
    private var gridWithHoverOverlay: some View {
        ZStack {
            gridContent
            hoverOverlayIfEnabled
        }
    }

    // MARK: - Content Builders (Mid Level)

    @ViewBuilder
    private var monthLabelsSpacer: some View {
        if configuration.showMonthLabels {
            Spacer().frame(height: 20)
        }
    }

    @ViewBuilder
    private var monthLabelsRowIfNeeded: some View {
        if configuration.showMonthLabels {
            monthLabelsRow
        }
    }

    @ViewBuilder
    private var monthLabelsRow: some View {
        ZStack(alignment: .topLeading) {
            monthLabelsBackground
            monthLabelItems
        }
    }

    @ViewBuilder
    private var monthLabelsBackground: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: totalGridWidth, height: 20)
    }

    @ViewBuilder
    private var monthLabelItems: some View {
        ForEach(dataset.monthLabels) { month in
            monthLabel(for: month)
        }
    }

    @ViewBuilder
    private func monthLabel(for month: HeatmapMonth) -> some View {
        Text(month.name)
            .font(configuration.monthLabelFont)
            .foregroundColor(.secondary)
            .accessibilityLabel(accessibility.enableAccessibilityLabels ? month.fullName : "")
            .offset(x: monthLabelOffset(for: month), y: 0)
    }

    @ViewBuilder
    private var dayLabelsColumn: some View {
        VStack(spacing: configuration.spacing) {
            ForEach(Array(configuration.dayLabels.enumerated()), id: \.offset) { index, dayLabel in
                dayLabelView(dayLabel)
            }
        }
    }

    @ViewBuilder
    private func dayLabelView(_ label: String) -> some View {
        Text(label)
            .font(configuration.dayLabelFont)
            .foregroundColor(.secondary)
            .frame(width: 28, height: configuration.squareSize, alignment: .trailing)
            .accessibilityHidden(!accessibility.enableAccessibilityLabels)
    }

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

    @ViewBuilder
    private var hoverOverlayIfEnabled: some View {
        if configuration.enableTooltips {
            hoverOverlay
        }
    }

    @ViewBuilder
    private var hoverOverlay: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onContinuousHover(perform: handleHoverPhase)
    }

    // MARK: - Layout Calculations (Low Level)

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onHover(value.location)
            }
    }

    private func handleHoverPhase(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            onHover(location)
        case .ended:
            onEndHover()
        }
    }

    private func monthLabelOffset(for month: HeatmapMonth) -> CGFloat {
        let weekStartIndex = CGFloat(month.weekSpan.lowerBound)
        let squareOffset = weekStartIndex * configuration.squareSize
        let spacingOffset = weekStartIndex * configuration.spacing
        let horizontalPadding: CGFloat = 4
        return squareOffset + spacingOffset + horizontalPadding
    }

    private var totalGridWidth: CGFloat {
        let weekCount = CGFloat(dataset.weeks.count)
        let totalSpacing = (weekCount - 1) * configuration.spacing
        let totalSquares = weekCount * configuration.squareSize
        let horizontalPadding: CGFloat = 8
        return totalSquares + totalSpacing + horizontalPadding
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

    private var borderStyle: BorderStyle {
        BorderStyle.forDay(day, isHovered: isHovered, config: configuration)
    }

    private var scaleEffect: CGFloat {
        configuration.scaleOnHover && isHovered ? configuration.hoverScale : 1.0
    }

    private var hoverAnimation: Animation? {
        configuration.animationDuration > 0
            ? .easeInOut(duration: configuration.animationDuration)
            : nil
    }

    var body: some View {
        Rectangle()
            .fill(day.color)
            .frame(width: configuration.squareSize, height: configuration.squareSize)
            .cornerRadius(configuration.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .stroke(borderStyle.color, lineWidth: borderStyle.width)
            )
            .scaleEffect(scaleEffect)
            .animation(hoverAnimation, value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        accessibility.enableAccessibilityLabels
            ? "\(accessibility.dateAccessibilityPrefix) \(day.dateString)"
            : ""
    }

    private var accessibilityValue: String {
        accessibility.enableAccessibilityValues
            ? "\(accessibility.costAccessibilityPrefix) \(day.costString)"
            : ""
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
        // Calculate x position: (week_index * square_size) + (week_index * spacing) + horizontal_padding
        let squareOffset = CGFloat(weekIndex) * configuration.squareSize
        let spacingOffset = CGFloat(weekIndex) * configuration.spacing
        let x = squareOffset + spacingOffset + 4 // 4 for horizontal padding
        
        // Calculate y position: (day_index * square_size) + (day_index * spacing)
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