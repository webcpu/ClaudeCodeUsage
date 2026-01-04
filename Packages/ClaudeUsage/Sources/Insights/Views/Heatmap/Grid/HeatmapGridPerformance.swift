//
//  HeatmapGridPerformance.swift
//  Performance optimization utilities for heatmap grid
//

import SwiftUI

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
        HeatmapConfiguration(
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
    }
}
