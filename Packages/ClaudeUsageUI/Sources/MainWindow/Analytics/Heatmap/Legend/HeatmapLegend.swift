//
//  HeatmapLegend.swift
//  Legend component for heatmap visualization
//

import SwiftUI

// MARK: - Legend Style Descriptor

/// Descriptor that encapsulates view building logic for each legend style.
/// Adding a new legend style requires only adding an entry to the registry.
@MainActor
struct LegendStyleDescriptor {
    let buildView: (LegendContext) -> AnyView

    /// Context containing all data needed to build a legend view
    struct LegendContext {
        let legendTitle: AnyView
        let horizontalLegendContent: AnyView
        let verticalColorScale: AnyView
        let conditionalCostReference: AnyView
        let colorSquares: AnyView
        let compactCostLabel: AnyView
        let legendAccessibilityLabel: String
        let compactAccessibilityLabel: String
    }

    /// Registry mapping each legend style to its descriptor
    static let registry: [HeatmapLegend.LegendStyle: LegendStyleDescriptor] = [
        .horizontal: LegendStyleDescriptor { context in
            AnyView(
                VStack(alignment: .leading, spacing: 4) {
                    context.legendTitle
                    context.horizontalLegendContent
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(context.legendAccessibilityLabel)
            )
        },
        .vertical: LegendStyleDescriptor { context in
            AnyView(
                VStack(alignment: .center, spacing: 8) {
                    context.legendTitle
                    context.verticalColorScale
                    context.conditionalCostReference
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(context.legendAccessibilityLabel)
            )
        },
        .compact: LegendStyleDescriptor { context in
            AnyView(
                HStack(spacing: 4) {
                    context.colorSquares
                    context.compactCostLabel
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(context.compactAccessibilityLabel)
            )
        }
    ]
}

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
        let context = LegendStyleDescriptor.LegendContext(
            legendTitle: AnyView(legendTitle),
            horizontalLegendContent: AnyView(horizontalLegendContent),
            verticalColorScale: AnyView(verticalColorScale),
            conditionalCostReference: AnyView(conditionalCostReference),
            colorSquares: AnyView(colorSquares),
            compactCostLabel: AnyView(compactCostLabel),
            legendAccessibilityLabel: legendAccessibilityLabel,
            compactAccessibilityLabel: compactAccessibilityLabel
        )

        if let descriptor = LegendStyleDescriptor.registry[style] {
            descriptor.buildView(context)
        }
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
