//
//  HeatmapTooltip.swift
//  Tooltip component for heatmap hover interactions
//

import SwiftUI

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

    // MARK: - Tooltip Content (Mid Level)

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

    // MARK: - Content Variants (Mid Level)

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

    @ViewBuilder
    private var customContentView: some View {
        if let customContent = customContent {
            customContent(day)
        } else {
            standardContent
        }
    }

    // MARK: - Standard Content Components (Low Level)

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

    // MARK: - Detailed Content Components (Low Level)

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
