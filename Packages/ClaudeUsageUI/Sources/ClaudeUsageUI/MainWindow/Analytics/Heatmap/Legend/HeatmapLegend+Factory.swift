//
//  HeatmapLegend+Factory.swift
//  Convenience factory methods for common legend configurations
//

import SwiftUI

// MARK: - Convenience Extensions

public extension HeatmapLegend {

    /// Create a minimal legend for compact displays
    /// - Parameters:
    ///   - colorTheme: Color theme to display
    ///   - maxCost: Maximum cost for reference
    /// - Returns: Configured minimal legend
    static func minimal(colorTheme: HeatmapColorTheme, maxCost: Double) -> HeatmapLegend {
        HeatmapLegend(
            colorTheme: colorTheme,
            maxCost: maxCost,
            style: .compact,
            showCostLabels: true,
            showIntensityLabels: false
        )
    }

    /// Create a detailed legend with all information
    /// - Parameters:
    ///   - colorTheme: Color theme to display
    ///   - maxCost: Maximum cost for reference
    ///   - title: Optional custom title
    /// - Returns: Configured detailed legend
    static func detailed(colorTheme: HeatmapColorTheme, maxCost: Double, title: String? = nil) -> HeatmapLegend {
        HeatmapLegend(
            colorTheme: colorTheme,
            maxCost: maxCost,
            style: .horizontal,
            showCostLabels: true,
            showIntensityLabels: true,
            customTitle: title
        )
    }

    /// Create an accessibility-optimized legend
    /// - Parameters:
    ///   - colorTheme: Color theme to display
    ///   - maxCost: Maximum cost for reference
    /// - Returns: Accessibility-optimized legend
    static func accessible(colorTheme: HeatmapColorTheme, maxCost: Double) -> HeatmapLegend {
        HeatmapLegend(
            colorTheme: colorTheme,
            maxCost: maxCost,
            style: .vertical,
            font: .body,
            showCostLabels: true,
            showIntensityLabels: true,
            accessibility: .default
        )
    }
}
