//
//  HeatmapColorProviding.swift
//  Protocol for heatmap color calculations (DIP)
//

import SwiftUI

/// Protocol for heatmap color calculations.
/// Enables dependency injection and testability.
public protocol HeatmapColorProviding: Sendable {
    /// Get color for a cost value
    func color(
        for cost: Double,
        maxCost: Double,
        theme: HeatmapColorTheme,
        variation: ColorVariation
    ) -> Color
}

// MARK: - Default Implementation

extension HeatmapColorManager: HeatmapColorProviding {}
