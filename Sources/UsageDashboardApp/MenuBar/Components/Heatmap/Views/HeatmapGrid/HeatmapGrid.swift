//
//  HeatmapGrid.swift
//  Reusable grid component for heatmap visualization
//

import SwiftUI

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
            ForEach(Array(configuration.dayLabels.enumerated()), id: \.offset) { _, dayLabel in
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
