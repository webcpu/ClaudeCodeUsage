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
        style: HeatmapTooltip.TooltipStyle
    ) -> CGSize {
        switch strategy {
        case .automatic:
            smartOffset(position: position, screenBounds: screenBounds, style: style)
        case .fixed:
            CGSize(width: 10, height: -30)
        case .adaptive:
            adaptiveOffset(style: style)
        }
    }

    private static func smartOffset(
        position: CGPoint,
        screenBounds: CGRect,
        style: HeatmapTooltip.TooltipStyle
    ) -> CGSize {
        let size = estimatedSize(for: style)
        let preferredX: CGFloat = 10
        let preferredY: CGFloat = -size.height - 10

        let adjustedX = position.x + preferredX + size.width > screenBounds.maxX
            ? -size.width - 10
            : preferredX

        let adjustedY = position.y + preferredY < screenBounds.minY
            ? 10
            : preferredY

        return CGSize(width: adjustedX, height: adjustedY)
    }

    private static func adaptiveOffset(style: HeatmapTooltip.TooltipStyle) -> CGSize {
        let size = estimatedSize(for: style)
        return CGSize(width: -size.width / 2, height: -size.height - 15)
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
