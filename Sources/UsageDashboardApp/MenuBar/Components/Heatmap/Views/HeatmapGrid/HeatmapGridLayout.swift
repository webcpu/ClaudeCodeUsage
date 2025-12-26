//
//  HeatmapGridLayout.swift
//  Utility for calculating grid layout dimensions
//

import SwiftUI

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
