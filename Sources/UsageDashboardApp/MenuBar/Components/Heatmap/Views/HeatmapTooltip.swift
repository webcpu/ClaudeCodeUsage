//
//  HeatmapTooltip.swift
//  Tooltip component for heatmap hover interactions
//

import SwiftUI

// MARK: - Activity Level (Pure Data)

/// Activity level classification based on intensity
private enum ActivityLevel {
    case none, low, medium, high, veryHigh

    init(intensity: Double) {
        switch intensity {
        case 0: self = .none
        case ..<0.25: self = .low
        case ..<0.5: self = .medium
        case ..<0.75: self = .high
        default: self = .veryHigh
        }
    }

    var text: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }

    var color: Color {
        switch self {
        case .none: .gray
        case .low: .green.opacity(0.7)
        case .medium: .green
        case .high: .orange
        case .veryHigh: .red
        }
    }
}

// MARK: - Tooltip Positioning (Pure Functions)

private enum TooltipPositioning {

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

// MARK: - Heatmap Tooltip

/// Customizable tooltip for displaying heatmap day information
public struct HeatmapTooltip: View {
    
    // MARK: - Configuration
    
    /// Tooltip content style
    public enum TooltipStyle {
        case minimal      // Cost and date only
        case standard     // Cost, date, and basic info
        case detailed     // Cost, date, and additional statistics
        case custom       // Fully customizable content
    }
    
    /// Tooltip positioning strategy
    public enum PositioningStrategy {
        case automatic    // Smart positioning based on screen bounds
        case fixed        // Fixed offset from cursor
        case adaptive     // Adapts to content size
    }
    
    // MARK: - Properties
    
    /// Day data to display
    let day: HeatmapDay
    
    /// Tooltip position on screen
    let position: CGPoint
    
    /// Display style
    let style: TooltipStyle
    
    /// Positioning strategy
    let positioning: PositioningStrategy
    
    /// Custom content builder (for .custom style)
    let customContent: ((HeatmapDay) -> AnyView)?
    
    /// Screen bounds for smart positioning
    let screenBounds: CGRect
    
    /// Configuration settings
    private let configuration: TooltipConfiguration
    
    // MARK: - Initialization
    
    /// Initialize tooltip with day data
    /// - Parameters:
    ///   - day: Day to display information for
    ///   - position: Position on screen
    ///   - style: Display style (default: standard)
    ///   - positioning: Positioning strategy (default: automatic)
    ///   - screenBounds: Screen bounds for positioning
    ///   - configuration: Tooltip configuration
    ///   - customContent: Custom content builder (for .custom style)
    public init(
        day: HeatmapDay,
        position: CGPoint,
        style: TooltipStyle = .standard,
        positioning: PositioningStrategy = .automatic,
        screenBounds: CGRect = NSScreen.main?.frame ?? .zero,
        configuration: TooltipConfiguration = .default,
        customContent: ((HeatmapDay) -> AnyView)? = nil
    ) {
        self.day = day
        self.position = position
        self.style = style
        self.positioning = positioning
        self.screenBounds = screenBounds
        self.configuration = configuration
        self.customContent = customContent
    }
    
    // MARK: - Body
    
    public var body: some View {
        tooltipContent
            .background(tooltipBackground)
            .cornerRadius(configuration.cornerRadius)
            .shadow(
                color: configuration.shadowColor,
                radius: configuration.shadowRadius,
                x: configuration.shadowOffset.width,
                y: configuration.shadowOffset.height
            )
            .offset(calculatedOffset)
            .opacity(configuration.opacity)
            .scaleEffect(configuration.scale)
            .animation(configuration.animation, value: day.id)
    }
    
    // MARK: - Tooltip Content
    
    @ViewBuilder
    private var tooltipContent: some View {
        switch style {
        case .minimal:
            minimalContent
        case .standard:
            standardContent
        case .detailed:
            detailedContent
        case .custom:
            customContentView
        }
    }
    
    // MARK: - Content Variants
    
    @ViewBuilder
    private var minimalContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.costString)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(day.dateString)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            standardPrimaryRow
            standardDateLabel
            standardUsageStatus
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Standard Content Components

    @ViewBuilder
    private var standardPrimaryRow: some View {
        HStack(spacing: 8) {
            Text(day.costString)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            if day.isToday {
                standardTodayBadge
            }
        }
    }

    private var standardTodayBadge: some View {
        Text("Today")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue)
            .cornerRadius(4)
    }

    private var standardDateLabel: some View {
        Text(day.dateString)
            .font(.system(size: 10))
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var standardUsageStatus: some View {
        if day.isEmpty {
            Text("No usage")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        } else {
            Text("Usage recorded")
                .font(.system(size: 9))
                .foregroundColor(.green)
        }
    }
    
    @ViewBuilder
    private var detailedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailedHeader
            detailedDivider
            detailedStatistics
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Detailed Content Components

    @ViewBuilder
    private var detailedHeader: some View {
        HStack {
            detailedCostAndDate
            Spacer()
            if day.isToday {
                detailedTodayBadge
            }
        }
    }

    @ViewBuilder
    private var detailedCostAndDate: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day.costString)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)

            Text(day.dateString)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var detailedTodayBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 12))
                .foregroundColor(.blue)
            Text("Today")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.blue)
        }
    }

    private var detailedDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(height: 0.5)
    }

    @ViewBuilder
    private var detailedStatistics: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !day.isEmpty {
                activityLevelRow
                intensityRow
            } else {
                noActivityRow
            }
            dayOfYearLabel
        }
    }

    @ViewBuilder
    private var activityLevelRow: some View {
        HStack {
            Text("Activity Level:")
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            Spacer()

            Text(activityLevel.text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(activityLevel.color)
        }
    }

    @ViewBuilder
    private var intensityRow: some View {
        HStack {
            Text("Intensity:")
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            Spacer()

            Text("\(Int(day.intensity * 100))%")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private var noActivityRow: some View {
        HStack {
            Image(systemName: "moon.zzz")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            Text("No activity recorded")
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
    }

    private var dayOfYearLabel: some View {
        Text("Day \(day.dayOfYear) of year")
            .font(.system(size: 8))
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var customContentView: some View {
        if let customContent = customContent {
            customContent(day)
        } else {
            standardContent
        }
    }
    
    // MARK: - Background
    
    @ViewBuilder
    private var tooltipBackground: some View {
        Rectangle()
            .fill(configuration.backgroundMaterial)
    }
    
    // MARK: - Computed Properties

    private var calculatedOffset: CGSize {
        TooltipPositioning.offset(
            for: positioning,
            position: position,
            screenBounds: screenBounds,
            style: style
        )
    }

    private var activityLevel: ActivityLevel {
        ActivityLevel(intensity: day.intensity)
    }
}

// MARK: - Tooltip Configuration

/// Configuration for tooltip appearance and behavior
public struct TooltipConfiguration {
    
    /// Background material
    public let backgroundMaterial: Material
    
    /// Corner radius
    public let cornerRadius: CGFloat
    
    /// Shadow properties
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowOffset: CGSize
    
    /// Opacity
    public let opacity: Double
    
    /// Scale
    public let scale: CGFloat
    
    /// Animation
    public let animation: Animation?
    
    /// Default configuration
    public static let `default` = TooltipConfiguration(
        backgroundMaterial: .regularMaterial,
        cornerRadius: 8,
        shadowColor: .black.opacity(0.15),
        shadowRadius: 6,
        shadowOffset: CGSize(width: 0, height: 2),
        opacity: 1.0,
        scale: 1.0,
        animation: .easeInOut(duration: 0.2)
    )
    
    /// Minimal configuration without shadows or animations
    public static let minimal = TooltipConfiguration(
        backgroundMaterial: .thinMaterial,
        cornerRadius: 4,
        shadowColor: .clear,
        shadowRadius: 0,
        shadowOffset: .zero,
        opacity: 0.95,
        scale: 1.0,
        animation: nil
    )
    
    /// Enhanced configuration with prominent styling
    public static let enhanced = TooltipConfiguration(
        backgroundMaterial: .thickMaterial,
        cornerRadius: 12,
        shadowColor: .black.opacity(0.25),
        shadowRadius: 10,
        shadowOffset: CGSize(width: 0, height: 4),
        opacity: 1.0,
        scale: 1.05,
        animation: .spring(response: 0.4, dampingFraction: 0.8)
    )
}

// MARK: - Tooltip Builder

/// Builder for creating customized tooltips
public struct HeatmapTooltipBuilder {
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
        return HeatmapTooltip(
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

// MARK: - Convenience Extensions

public extension HeatmapTooltip {
    
    /// Create a quick tooltip with minimal styling
    /// - Parameters:
    ///   - day: Day data
    ///   - position: Position on screen
    /// - Returns: Minimal tooltip
    static func quick(day: HeatmapDay, position: CGPoint) -> HeatmapTooltip {
        return HeatmapTooltip(
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
        return HeatmapTooltip(
            day: day,
            position: position,
            style: .detailed,
            configuration: .enhanced
        )
    }
}

// MARK: - Preview

#if DEBUG
struct HeatmapTooltip_Previews: PreviewProvider {
    static var previews: some View {
        let sampleDay = HeatmapDay(
            date: Date(),
            cost: 12.45,
            dayOfYear: 285,
            weekOfYear: 41,
            dayOfWeek: 3,
            maxCost: 25.0
        )
        
        VStack(spacing: 30) {
            // Minimal tooltip
            HeatmapTooltip.quick(day: sampleDay, position: .zero)
            
            // Standard tooltip
            HeatmapTooltip(day: sampleDay, position: .zero, style: .standard)
            
            // Detailed tooltip
            HeatmapTooltip.rich(day: sampleDay, position: .zero)
        }
        .padding(50)
        .background(Color(.windowBackgroundColor))
    }
}
#endif