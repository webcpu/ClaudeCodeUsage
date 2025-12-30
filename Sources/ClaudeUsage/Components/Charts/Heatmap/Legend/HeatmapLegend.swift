//
//  HeatmapLegend.swift
//  Legend component for heatmap visualization
//

import SwiftUI

// MARK: - Heatmap Legend

/// Reusable legend component for heatmap color scale
public struct HeatmapLegend: View {

    // MARK: - Configuration

    /// Legend layout style
    public enum LegendStyle {
        case horizontal
        case vertical
        case compact
    }

    /// Legend position relative to parent
    public enum LegendPosition {
        case bottom
        case top
        case leading
        case trailing
    }

    // MARK: - Properties

    /// Color theme for the legend
    let colorTheme: HeatmapColorTheme

    /// Maximum cost value for scale reference
    let maxCost: Double

    /// Legend display style
    let style: LegendStyle

    /// Font for legend text
    let font: Font

    /// Whether to show cost labels
    let showCostLabels: Bool

    /// Whether to show intensity labels (Less/More)
    let showIntensityLabels: Bool

    /// Custom title for the legend
    let customTitle: String?

    /// Accessibility configuration
    private let accessibility: HeatmapAccessibility

    // MARK: - Initialization

    /// Initialize heatmap legend
    /// - Parameters:
    ///   - colorTheme: Color theme to display
    ///   - maxCost: Maximum cost value for reference
    ///   - style: Display style (default: horizontal)
    ///   - font: Font for text (default: caption)
    ///   - showCostLabels: Whether to show cost values (default: true)
    ///   - showIntensityLabels: Whether to show Less/More labels (default: true)
    ///   - customTitle: Optional custom title
    ///   - accessibility: Accessibility configuration
    public init(
        colorTheme: HeatmapColorTheme,
        maxCost: Double,
        style: LegendStyle = .horizontal,
        font: Font = .caption,
        showCostLabels: Bool = true,
        showIntensityLabels: Bool = true,
        customTitle: String? = nil,
        accessibility: HeatmapAccessibility = .default
    ) {
        self.colorTheme = colorTheme
        self.maxCost = maxCost
        self.style = style
        self.font = font
        self.showCostLabels = showCostLabels
        self.showIntensityLabels = showIntensityLabels
        self.customTitle = customTitle
        self.accessibility = accessibility
    }

    // MARK: - Body

    public var body: some View {
        switch style {
        case .horizontal:
            horizontalLegend
        case .vertical:
            verticalLegend
        case .compact:
            compactLegend
        }
    }

    // MARK: - Legend Variants (Mid Level)

    @ViewBuilder
    private var horizontalLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendTitle
            horizontalLegendContent
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(legendAccessibilityLabel)
    }

    @ViewBuilder
    private var verticalLegend: some View {
        VStack(alignment: .center, spacing: 8) {
            legendTitle
            verticalColorScale
            conditionalCostReference
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(legendAccessibilityLabel)
    }

    // MARK: - Legend Content (Mid Level)

    @ViewBuilder
    private var horizontalLegendContent: some View {
        HStack(spacing: 8) {
            lessLabel
            colorSquares
            moreLabel
            Spacer()
            conditionalCostReference
        }
    }

    @ViewBuilder
    private var verticalColorScale: some View {
        VStack(spacing: 3) {
            moreLabel
            verticalColorSquares
            lessLabel
        }
    }

    @ViewBuilder
    private var verticalColorSquares: some View {
        ForEach(Array((0..<5).reversed()), id: \.self) { level in
            LegendSquare(
                level: level,
                accessibility: accessibility
            )
        }
    }

    @ViewBuilder
    private var compactLegend: some View {
        HStack(spacing: 4) {
            colorSquares
            compactCostLabel
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    // MARK: - Components (Low Level)

    @ViewBuilder
    private var legendTitle: some View {
        if let title = effectiveTitle {
            Text(title)
                .font(font.weight(.semibold))
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    @ViewBuilder
    private var lessLabel: some View {
        if showIntensityLabels {
            Text("Less")
                .font(font)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var moreLabel: some View {
        if showIntensityLabels {
            Text("More")
                .font(font)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var colorSquares: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { level in
                LegendSquare(
                    level: level,
                    accessibility: accessibility
                )
            }
        }
    }

    @ViewBuilder
    private var conditionalCostReference: some View {
        if showCostLabels && maxCost > 0 {
            costReference
        }
    }

    @ViewBuilder
    private var costReference: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Max: \(maxCost.asCurrency)")
                .font(font)
                .foregroundColor(.secondary)

            if maxCost > 1 {
                let quarterCost = maxCost * 0.25
                Text("~\(quarterCost.asCurrency) per level")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var compactCostLabel: some View {
        if showCostLabels && maxCost > 0 {
            Text("Max: \(maxCost.asCurrency)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var effectiveTitle: String? {
        customTitle ?? (showCostLabels ? "Daily Cost Activity" : nil)
    }

    // MARK: - Accessibility (Low Level)

    private var legendAccessibilityLabel: String {
        guard accessibility.enableAccessibilityLabels else { return "" }

        var label = "Activity legend: "
        label += "5 levels from no activity to high activity, "

        if showCostLabels && maxCost > 0 {
            label += "maximum daily cost \(maxCost.asCurrency)"
        }

        return label
    }

    private var compactAccessibilityLabel: String {
        guard accessibility.enableAccessibilityLabels else { return "" }
        return "Activity scale with maximum cost \(maxCost.asCurrency)"
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapLegend_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HeatmapLegend(
                colorTheme: .github,
                maxCost: 15.42,
                style: .horizontal
            )

            HeatmapLegend(
                colorTheme: .ocean,
                maxCost: 8.75,
                style: .compact
            )

            HeatmapLegend(
                colorTheme: .sunset,
                maxCost: 23.15,
                style: .vertical
            )

            Spacer()
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
}
#endif
