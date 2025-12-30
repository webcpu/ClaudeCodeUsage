//
//  WeekColumn.swift
//  Single week column component for heatmap grid
//

import SwiftUI

// MARK: - Week Column

/// Single week column in the heatmap grid
struct WeekColumn: View {
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
