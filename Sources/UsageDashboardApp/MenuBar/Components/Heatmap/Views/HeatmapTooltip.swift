//
//  HeatmapTooltip.swift
//  Tooltip component for heatmap hover interactions
//
//  Provides customizable tooltips with smart positioning,
//  rich content support, and smooth animations.
//

import SwiftUI
import Foundation

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
            // Primary info
            HStack(spacing: 8) {
                Text(day.costString)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                if day.isToday {
                    Text("Today")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }
            
            // Date
            Text(day.dateString)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            // Usage status
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var detailedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with cost and today indicator
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.costString)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(day.dateString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if day.isToday {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text("Today")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
            
            // Statistics
            VStack(alignment: .leading, spacing: 3) {
                if !day.isEmpty {
                    HStack {
                        Text("Activity Level:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(activityLevelText)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(activityLevelColor)
                    }
                    
                    HStack {
                        Text("Intensity:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(day.intensity * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.primary)
                    }
                } else {
                    HStack {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Text("No activity recorded")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                
                // Day of year info
                Text("Day \(day.dayOfYear) of year")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
        switch positioning {
        case .automatic:
            return calculateSmartOffset()
        case .fixed:
            return CGSize(width: 10, height: -30)
        case .adaptive:
            return calculateAdaptiveOffset()
        }
    }
    
    private var activityLevelText: String {
        switch day.intensity {
        case 0:
            return "None"
        case 0..<0.25:
            return "Low"
        case 0.25..<0.5:
            return "Medium"
        case 0.5..<0.75:
            return "High"
        default:
            return "Very High"
        }
    }
    
    private var activityLevelColor: Color {
        switch day.intensity {
        case 0:
            return .gray
        case 0..<0.25:
            return .green.opacity(0.7)
        case 0.25..<0.5:
            return .green
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }
    
    // MARK: - Positioning Calculations
    
    private func calculateSmartOffset() -> CGSize {
        // Estimate tooltip size based on content
        let estimatedSize = estimateTooltipSize()
        
        // Calculate preferred position (above and to the right)
        var offsetX: CGFloat = 10
        var offsetY: CGFloat = -estimatedSize.height - 10
        
        // Adjust if tooltip would go off-screen
        if position.x + offsetX + estimatedSize.width > screenBounds.maxX {
            offsetX = -estimatedSize.width - 10 // Move to left
        }
        
        if position.y + offsetY < screenBounds.minY {
            offsetY = 10 // Move below cursor
        }
        
        return CGSize(width: offsetX, height: offsetY)
    }
    
    private func calculateAdaptiveOffset() -> CGSize {
        let estimatedSize = estimateTooltipSize()
        
        // Center tooltip relative to cursor
        return CGSize(
            width: -estimatedSize.width / 2,
            height: -estimatedSize.height - 15
        )
    }
    
    private func estimateTooltipSize() -> CGSize {
        switch style {
        case .minimal:
            return CGSize(width: 100, height: 35)
        case .standard:
            return CGSize(width: 140, height: 50)
        case .detailed:
            return CGSize(width: 180, height: 85)
        case .custom:
            return CGSize(width: 150, height: 60) // Default estimate
        }
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