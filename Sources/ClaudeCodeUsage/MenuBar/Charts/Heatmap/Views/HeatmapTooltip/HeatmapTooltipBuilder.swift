//
//  HeatmapTooltipBuilder.swift
//  Builder pattern for creating customized tooltips
//

import SwiftUI

// MARK: - Tooltip Builder

/// Builder for creating customized tooltips
public struct HeatmapTooltipBuilder: @unchecked Sendable {
    private var day: HeatmapDay
    private var position: CGPoint
    private var style: HeatmapTooltip.TooltipStyle = .standard
    private var positioning: HeatmapTooltip.PositioningStrategy = .automatic
    private var screenBounds: CGRect = NSScreen.main?.frame ?? .zero
    private var configuration: TooltipConfiguration = .default
    private var customContent: ((HeatmapDay) -> AnyView)?

    public init(day: HeatmapDay, position: CGPoint) {
        self.day = day
        self.position = position
    }

    public func style(_ tooltipStyle: HeatmapTooltip.TooltipStyle) -> Self {
        var builder = self
        builder.style = tooltipStyle
        return builder
    }

    public func positioning(_ strategy: HeatmapTooltip.PositioningStrategy) -> Self {
        var builder = self
        builder.positioning = strategy
        return builder
    }

    public func screenBounds(_ bounds: CGRect) -> Self {
        var builder = self
        builder.screenBounds = bounds
        return builder
    }

    public func configuration(_ config: TooltipConfiguration) -> Self {
        var builder = self
        builder.configuration = config
        return builder
    }

    public func customContent(_ content: @escaping (HeatmapDay) -> AnyView) -> Self {
        var builder = self
        builder.customContent = content
        return builder
    }

    public func build() -> HeatmapTooltip {
        HeatmapTooltip(
            day: day,
            position: position,
            style: style,
            positioning: positioning,
            screenBounds: screenBounds,
            configuration: configuration,
            customContent: customContent
        )
    }
}
