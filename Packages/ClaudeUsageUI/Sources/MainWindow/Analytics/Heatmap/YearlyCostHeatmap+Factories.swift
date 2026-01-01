//
//  YearlyCostHeatmap+Factories.swift
//
//  Static factory methods for YearlyCostHeatmap.
//

import SwiftUI
import ClaudeUsageCore

// MARK: - Factory Methods

public extension YearlyCostHeatmap {

    /// Performance-optimized version for large datasets
    static func performanceOptimized(stats: UsageStats) -> YearlyCostHeatmap {
        YearlyCostHeatmap(stats: stats, configuration: .performanceOptimized)
    }

    /// Compact version for limited space
    static func compact(stats: UsageStats) -> YearlyCostHeatmap {
        YearlyCostHeatmap(stats: stats, configuration: .compact)
    }

    /// Accessibility-optimized version
    static func accessible(stats: UsageStats) -> YearlyCostHeatmap {
        let config = HeatmapConfiguration(
            squareSize: 14,
            spacing: 3,
            cornerRadius: 2,
            padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
            colorScheme: .github,
            showMonthLabels: true,
            showDayLabels: true,
            showLegend: true,
            monthLabelFont: .body,
            dayLabelFont: .subheadline,
            legendFont: .body,
            enableTooltips: true,
            tooltipDelay: 0.1,
            highlightToday: true,
            todayHighlightColor: .blue,
            todayHighlightWidth: 3,
            animationDuration: 0.0,
            animateColorTransitions: false,
            scaleOnHover: false,
            hoverScale: 1.0
        )
        return YearlyCostHeatmap(stats: stats, configuration: config)
    }
}
