//
//  TooltipPositioning.swift
//  Pure functions for tooltip positioning calculations
//

import SwiftUI

// MARK: - Tooltip Size Descriptor (OCP Registry)

/// Registry of tooltip sizes by style - new styles register here without modifying positioning logic
enum TooltipSizeDescriptor {
    nonisolated(unsafe) static let sizes: [HeatmapTooltip.TooltipStyle: CGSize] = [
        .minimal: CGSize(width: 100, height: 35),
        .standard: CGSize(width: 140, height: 50),
        .detailed: CGSize(width: 180, height: 85),
        .custom: CGSize(width: 150, height: 60)
    ]

    static let defaultSize = CGSize(width: 140, height: 50)
}

// MARK: - Positioning Strategy Extension (OCP Pattern)

extension HeatmapTooltip.PositioningStrategy {
    /// Each strategy provides its own offset calculation function
    var offsetCalculator: (CGPoint, CGRect, HeatmapTooltip.TooltipStyle, Bool) -> CGSize {
        switch self {
        case .automatic:
            TooltipPositioning.smartOffset
        case .fixed:
            TooltipPositioning.fixedOffset
        case .adaptive:
            TooltipPositioning.adaptiveOffset
        }
    }
}

// MARK: - Tooltip Positioning (Pure Functions)

enum TooltipPositioning {

    static func offset(
        for strategy: HeatmapTooltip.PositioningStrategy,
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle,
        shouldFlipLeft: Bool = false
    ) -> CGSize {
        strategy.offsetCalculator(position, screenBounds, style, shouldFlipLeft)
    }

    static func smartOffset(
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle,
        shouldFlipLeft: Bool
    ) -> CGSize {
        let size = estimatedSize(for: style)
        let gap: CGFloat = 8

        // Position tooltip edge near cell center
        // .position() places tooltip CENTER, so offset by half-width to align edge
        let adjustedX: CGFloat = shouldFlipLeft
            ? -(size.width / 2) - gap  // Right edge near cell
            : (size.width / 2) + gap   // Left edge near cell

        return CGSize(width: adjustedX, height: 0)
    }

    static func fixedOffset(
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle,
        shouldFlipLeft: Bool
    ) -> CGSize {
        CGSize(width: shouldFlipLeft ? -150 : 10, height: -30)
    }

    static func adaptiveOffset(
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle,
        shouldFlipLeft: Bool
    ) -> CGSize {
        let size = estimatedSize(for: style)
        let xOffset = shouldFlipLeft ? -size.width - 10 : -size.width / 2
        return CGSize(width: xOffset, height: -size.height - 15)
    }

    static func estimatedSize(for style: HeatmapTooltip.TooltipStyle) -> CGSize {
        TooltipSizeDescriptor.sizes[style] ?? TooltipSizeDescriptor.defaultSize
    }
}
