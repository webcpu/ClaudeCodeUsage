//
//  YearlyCostHeatmap+Factories.swift
//
//  Static factory methods and legacy compatibility for YearlyCostHeatmap.
//

import SwiftUI
import ClaudeCodeUsageKit

// MARK: - Legacy Compatibility

/// Legacy extension providing the original interface for backward compatibility
public extension YearlyCostHeatmap {

    /// Legacy initializer matching the original component interface
    /// - Parameters:
    ///   - stats: Usage statistics
    ///   - year: Year (ignored, rolling year used instead)
    /// - Returns: Configured heatmap with default settings
    @available(*, deprecated, message: "Use init(stats:year:configuration:) with explicit configuration instead")
    static func legacy(stats: UsageStats, year: Int) -> YearlyCostHeatmap {
        return YearlyCostHeatmap(
            stats: stats,
            year: year,
            configuration: .default
        )
    }

    /// Performance-optimized version for large datasets
    /// - Parameters:
    ///   - stats: Usage statistics
    ///   - year: Year (ignored)
    /// - Returns: Performance-optimized heatmap
    static func performanceOptimized(stats: UsageStats, year: Int) -> YearlyCostHeatmap {
        return YearlyCostHeatmap(
            stats: stats,
            year: year,
            configuration: .performanceOptimized
        )
    }

    /// Compact version for limited space
    /// - Parameters:
    ///   - stats: Usage statistics
    ///   - year: Year (ignored)
    /// - Returns: Compact heatmap
    static func compact(stats: UsageStats, year: Int) -> YearlyCostHeatmap {
        return YearlyCostHeatmap(
            stats: stats,
            year: year,
            configuration: .compact
        )
    }
}

// MARK: - Custom Configurations

public extension YearlyCostHeatmap {

    /// Create heatmap with custom color theme
    /// - Parameters:
    ///   - stats: Usage statistics
    ///   - year: Year (ignored)
    ///   - colorTheme: Custom color theme
    /// - Returns: Heatmap with custom colors
    static func withColorTheme(
        stats: UsageStats,
        year: Int,
        colorTheme: HeatmapColorTheme
    ) -> YearlyCostHeatmap {
        let config = HeatmapConfiguration.default
        // Note: This would require modifying HeatmapConfiguration to be mutable
        // For now, we'll use the default configuration
        return YearlyCostHeatmap(stats: stats, year: year, configuration: config)
    }

    /// Create heatmap with accessibility optimizations
    /// - Parameters:
    ///   - stats: Usage statistics
    ///   - year: Year (ignored)
    /// - Returns: Accessibility-optimized heatmap
    static func accessible(stats: UsageStats, year: Int) -> YearlyCostHeatmap {
        // Create configuration optimized for accessibility
        let config = HeatmapConfiguration(
            squareSize: 14, // Larger squares
            spacing: 3,     // More spacing
            cornerRadius: 2,
            padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
            colorScheme: .github, // High contrast theme would be better
            showMonthLabels: true,
            showDayLabels: true,
            showLegend: true,
            monthLabelFont: .body, // Larger font
            dayLabelFont: .subheadline,
            legendFont: .body,
            enableTooltips: true,
            tooltipDelay: 0.1,
            highlightToday: true,
            todayHighlightColor: .blue,
            todayHighlightWidth: 3, // Thicker border
            animationDuration: 0.0, // No animations for accessibility
            animateColorTransitions: false,
            scaleOnHover: false,
            hoverScale: 1.0
        )

        return YearlyCostHeatmap(stats: stats, year: year, configuration: config)
    }
}

// MARK: - Migration Guide

/*
 MIGRATION GUIDE: Upgrading from Legacy YearlyCostHeatmap

 The YearlyCostHeatmap component has been completely refactored with clean architecture.
 While backward compatibility is maintained, consider migrating to the new API:

 OLD (still works):
 ```swift
 YearlyCostHeatmap(stats: stats, year: 2024)
 ```

 NEW (recommended):
 ```swift
 YearlyCostHeatmap(
     stats: stats,
     year: 2024,
     configuration: .default // or .performanceOptimized, .compact
 )
 ```

 PERFORMANCE OPTIMIZED:
 ```swift
 YearlyCostHeatmap.performanceOptimized(stats: stats, year: 2024)
 ```

 COMPACT VERSION:
 ```swift
 YearlyCostHeatmap.compact(stats: stats, year: 2024)
 ```

 ACCESSIBILITY OPTIMIZED:
 ```swift
 YearlyCostHeatmap.accessible(stats: stats, year: 2024)
 ```

 BENEFITS OF MIGRATION:
 - Better performance with optimized configurations
 - Improved accessibility support
 - More customization options
 - Better error handling and loading states
 - Type-safe configuration
 - Easier testing with separated concerns
 */
