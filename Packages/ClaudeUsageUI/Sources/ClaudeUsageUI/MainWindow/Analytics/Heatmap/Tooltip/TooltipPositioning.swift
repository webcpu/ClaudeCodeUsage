//
//  TooltipPositioning.swift
//  Pure functions for tooltip positioning calculations
//

import SwiftUI

// MARK: - Tooltip Positioning (Pure Functions)

enum TooltipPositioning {

    static func offset(
        for strategy: HeatmapTooltip.PositioningStrategy,
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle,
        shouldFlipLeft: Bool = false
    ) -> CGSize {
        switch strategy {
        case .automatic:
            smartOffset(position: position, screenBounds: screenBounds, style: style, shouldFlipLeft: shouldFlipLeft)
        case .fixed:
            CGSize(width: shouldFlipLeft ? -150 : 10, height: -30)
        case .adaptive:
            adaptiveOffset(style: style, shouldFlipLeft: shouldFlipLeft)
        }
    }

    private static func smartOffset(
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

    private static func adaptiveOffset(style: HeatmapTooltip.TooltipStyle, shouldFlipLeft: Bool) -> CGSize {
        let size = estimatedSize(for: style)
        let xOffset = shouldFlipLeft ? -size.width - 10 : -size.width / 2
        return CGSize(width: xOffset, height: -size.height - 15)
    }

    static func estimatedSize(for style: HeatmapTooltip.TooltipStyle) -> CGSize {
        switch style {
        case .minimal: CGSize(width: 100, height: 35)
        case .standard: CGSize(width: 140, height: 50)
        case .detailed: CGSize(width: 180, height: 85)
        case .custom: CGSize(width: 150, height: 60)
        }
    }
}
