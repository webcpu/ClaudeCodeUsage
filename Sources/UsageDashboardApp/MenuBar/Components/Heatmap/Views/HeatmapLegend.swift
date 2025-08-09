//
//  HeatmapLegend.swift
//  Legend component for heatmap visualization
//
//  Provides customizable legend with accessibility support,
//  multiple layout options, and comprehensive labeling.
//

import SwiftUI
import Foundation

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
    
    // MARK: - Horizontal Legend
    
    @ViewBuilder
    private var horizontalLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            if let title = effectiveTitle {
                Text(title)
                    .font(font.weight(.semibold))
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            
            // Legend content
            HStack(spacing: 8) {
                // Intensity labels
                if showIntensityLabels {
                    Text("Less")
                        .font(font)
                        .foregroundColor(.secondary)
                }
                
                // Color squares
                colorSquares
                
                if showIntensityLabels {
                    Text("More")
                        .font(font)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Cost reference
                if showCostLabels && maxCost > 0 {
                    costReference
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(legendAccessibilityLabel)
    }
    
    // MARK: - Vertical Legend
    
    @ViewBuilder
    private var verticalLegend: some View {
        VStack(alignment: .center, spacing: 8) {
            // Title
            if let title = effectiveTitle {
                Text(title)
                    .font(font.weight(.semibold))
                    .foregroundColor(.primary)
                    .accessibilityAddTraits(.isHeader)
            }
            
            // Color squares (vertical)
            VStack(spacing: 3) {
                if showIntensityLabels {
                    Text("More")
                        .font(font)
                        .foregroundColor(.secondary)
                }
                
                ForEach(Array(colorTheme.colors.reversed().enumerated()), id: \.offset) { index, color in
                    LegendSquare(
                        color: color,
                        level: colorTheme.colors.count - 1 - index,
                        accessibility: accessibility
                    )
                }
                
                if showIntensityLabels {
                    Text("Less")
                        .font(font)
                        .foregroundColor(.secondary)
                }
            }
            
            // Cost reference
            if showCostLabels && maxCost > 0 {
                costReference
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(legendAccessibilityLabel)
    }
    
    // MARK: - Compact Legend
    
    @ViewBuilder
    private var compactLegend: some View {
        HStack(spacing: 4) {
            // Color squares only
            colorSquares
            
            // Minimal cost reference
            if showCostLabels && maxCost > 0 {
                Text("Max: \(maxCost.asCurrency)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactAccessibilityLabel)
    }
    
    // MARK: - Color Squares
    
    @ViewBuilder
    private var colorSquares: some View {
        HStack(spacing: 3) {
            ForEach(Array(colorTheme.colors.enumerated()), id: \.offset) { index, color in
                LegendSquare(
                    color: color,
                    level: index,
                    accessibility: accessibility
                )
            }
        }
    }
    
    // MARK: - Cost Reference
    
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
    
    // MARK: - Computed Properties
    
    private var effectiveTitle: String? {
        customTitle ?? (showCostLabels ? "Daily Cost Activity" : nil)
    }
    
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

// MARK: - Legend Square

/// Individual square in the legend
private struct LegendSquare: View {
    let color: Color
    let level: Int
    let accessibility: HeatmapAccessibility
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 11, height: 11)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }
    
    private var accessibilityLabel: String {
        guard accessibility.enableAccessibilityLabels else { return "" }
        
        switch level {
        case 0:
            return "No activity"
        case 1:
            return "Low activity"
        case 2:
            return "Medium-low activity"
        case 3:
            return "Medium-high activity"
        case 4:
            return "High activity"
        default:
            return "Activity level \(level)"
        }
    }
    
    private var accessibilityValue: String {
        guard accessibility.enableAccessibilityValues else { return "" }
        return "Level \(level) of 4"
    }
}

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
        return HeatmapLegend(
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

// MARK: - Convenience Extensions

public extension HeatmapLegend {
    
    /// Create a minimal legend for compact displays
    /// - Parameters:
    ///   - colorTheme: Color theme to display
    ///   - maxCost: Maximum cost for reference
    /// - Returns: Configured minimal legend
    static func minimal(colorTheme: HeatmapColorTheme, maxCost: Double) -> HeatmapLegend {
        return HeatmapLegend(
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
        return HeatmapLegend(
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
        return HeatmapLegend(
            colorTheme: colorTheme,
            maxCost: maxCost,
            style: .vertical,
            font: .body, // Larger font for accessibility
            showCostLabels: true,
            showIntensityLabels: true,
            accessibility: .default
        )
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapLegend_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Horizontal legend
            HeatmapLegend(
                colorTheme: .github,
                maxCost: 15.42,
                style: .horizontal
            )
            
            // Compact legend
            HeatmapLegend(
                colorTheme: .ocean,
                maxCost: 8.75,
                style: .compact
            )
            
            // Vertical legend
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