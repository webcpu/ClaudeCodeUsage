//
//  HeatmapLegendBuilder.swift
//  Builder pattern for creating customized legends
//

import SwiftUI

// MARK: - Legend Builder

/// Builder pattern for creating customized legends
public struct HeatmapLegendBuilder {
    private var colorTheme: HeatmapColorTheme = .github
    private var maxCost: Double = 0
    private var style: HeatmapLegend.LegendStyle = .horizontal
    private var font: Font = .caption
    private var showCostLabels: Bool = true
    private var showIntensityLabels: Bool = true
    private var customTitle: String?
    private var accessibility: HeatmapAccessibility = .default

    public init() {}

    public func colorTheme(_ theme: HeatmapColorTheme) -> Self {
        var builder = self
        builder.colorTheme = theme
        return builder
    }

    public func maxCost(_ cost: Double) -> Self {
        var builder = self
        builder.maxCost = cost
        return builder
    }

    public func style(_ legendStyle: HeatmapLegend.LegendStyle) -> Self {
        var builder = self
        builder.style = legendStyle
        return builder
    }

    public func font(_ legendFont: Font) -> Self {
        var builder = self
        builder.font = legendFont
        return builder
    }

    public func showCostLabels(_ show: Bool) -> Self {
        var builder = self
        builder.showCostLabels = show
        return builder
    }

    public func showIntensityLabels(_ show: Bool) -> Self {
        var builder = self
        builder.showIntensityLabels = show
        return builder
    }

    public func title(_ title: String?) -> Self {
        var builder = self
        builder.customTitle = title
        return builder
    }

    public func accessibility(_ config: HeatmapAccessibility) -> Self {
        var builder = self
        builder.accessibility = config
        return builder
    }

    public func build() -> HeatmapLegend {
        HeatmapLegend(
            colorTheme: colorTheme,
            maxCost: maxCost,
            style: style,
            font: font,
            showCostLabels: showCostLabels,
            showIntensityLabels: showIntensityLabels,
            customTitle: customTitle,
            accessibility: accessibility
        )
    }
}
