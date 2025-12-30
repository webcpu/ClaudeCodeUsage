//
//  HeatmapTooltip+Factory.swift
//  Convenience factory methods for common tooltip configurations
//

import SwiftUI

// MARK: - Convenience Extensions

public extension HeatmapTooltip {

    /// Create a quick tooltip with minimal styling
    /// - Parameters:
    ///   - day: Day data
    ///   - position: Position on screen
    /// - Returns: Minimal tooltip
    static func quick(day: HeatmapDay, position: CGPoint) -> HeatmapTooltip {
        HeatmapTooltip(
            day: day,
            position: position,
            style: .minimal,
            configuration: .minimal
        )
    }

    /// Create a rich tooltip with detailed information
    /// - Parameters:
    ///   - day: Day data
    ///   - position: Position on screen
    /// - Returns: Detailed tooltip
    static func rich(day: HeatmapDay, position: CGPoint) -> HeatmapTooltip {
        HeatmapTooltip(
            day: day,
            position: position,
            style: .detailed,
            configuration: .enhanced
        )
    }
}
