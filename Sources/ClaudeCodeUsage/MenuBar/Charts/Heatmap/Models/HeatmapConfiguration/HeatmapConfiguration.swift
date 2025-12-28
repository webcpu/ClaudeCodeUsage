//
//  HeatmapConfiguration.swift
//  Configuration models for heatmap customization
//
//  Provides type-safe configuration options for heatmap appearance,
//  layout, and behavior with sensible defaults.
//
//  Split into extensions for focused responsibilities:
//    - +ColorThemes: Color theme definitions
//    - +Accessibility: Accessibility settings and validation
//

import SwiftUI
import Foundation

// MARK: - Configuration Struct

/// Configuration settings for heatmap appearance and behavior
public struct HeatmapConfiguration: Equatable, @unchecked Sendable {

    // MARK: - Layout Settings

    /// Size of each day square in points
    public let squareSize: CGFloat

    /// Spacing between day squares in points
    public let spacing: CGFloat

    /// Corner radius for day squares
    public let cornerRadius: CGFloat

    /// Padding around the entire heatmap
    public let padding: EdgeInsets

    // MARK: - Visual Settings

    /// Color scheme for the heatmap
    public let colorScheme: HeatmapColorTheme

    /// Whether to show month labels
    public let showMonthLabels: Bool

    /// Whether to show day-of-week labels
    public let showDayLabels: Bool

    /// Whether to show the legend
    public let showLegend: Bool

    /// Font for month labels
    public let monthLabelFont: Font

    /// Font for day labels
    public let dayLabelFont: Font

    /// Font for legend text
    public let legendFont: Font

    // MARK: - Interaction Settings

    /// Whether hover tooltips are enabled
    public let enableTooltips: Bool

    /// Tooltip delay in seconds
    public let tooltipDelay: Double

    /// Whether to highlight today's date
    public let highlightToday: Bool

    /// Color for today's highlight border
    public let todayHighlightColor: Color

    /// Width of today's highlight border
    public let todayHighlightWidth: CGFloat

    // MARK: - Animation Settings

    /// Duration for hover animations
    public let animationDuration: Double

    /// Whether to animate color transitions
    public let animateColorTransitions: Bool

    /// Whether to scale squares on hover
    public let scaleOnHover: Bool

    /// Scale factor for hover effect
    public let hoverScale: CGFloat

    // MARK: - Default Configuration

    /// Standard configuration matching GitHub's contribution graph
    public static let `default` = HeatmapConfiguration(
        squareSize: 12,
        spacing: 2,
        cornerRadius: 2,
        padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        colorScheme: .github,
        showMonthLabels: true,
        showDayLabels: true,
        showLegend: true,
        monthLabelFont: .system(size: 10, weight: .medium),
        dayLabelFont: .system(size: 9, weight: .regular),
        legendFont: .caption,
        enableTooltips: true,
        tooltipDelay: 0.5,
        highlightToday: true,
        todayHighlightColor: .blue,
        todayHighlightWidth: 2,
        animationDuration: 0.1,
        animateColorTransitions: false, // Disabled for performance
        scaleOnHover: false, // Disabled for performance
        hoverScale: 1.1
    )

    /// Compact configuration for smaller displays
    public static let compact = HeatmapConfiguration(
        squareSize: 10,
        spacing: 1.5,
        cornerRadius: 1.5,
        padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
        colorScheme: .github,
        showMonthLabels: true,
        showDayLabels: false, // Hide day labels in compact mode
        showLegend: true,
        monthLabelFont: .system(size: 9, weight: .medium),
        dayLabelFont: .system(size: 8, weight: .regular),
        legendFont: .system(size: 10),
        enableTooltips: true,
        tooltipDelay: 0.3,
        highlightToday: true,
        todayHighlightColor: .blue,
        todayHighlightWidth: 1.5,
        animationDuration: 0.08,
        animateColorTransitions: false,
        scaleOnHover: false,
        hoverScale: 1.05
    )

    /// Performance-optimized configuration
    public static let performanceOptimized = HeatmapConfiguration(
        squareSize: 12,
        spacing: 2,
        cornerRadius: 2,
        padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        colorScheme: .github,
        showMonthLabels: true,
        showDayLabels: true,
        showLegend: true,
        monthLabelFont: .system(size: 10, weight: .medium),
        dayLabelFont: .system(size: 9, weight: .regular),
        legendFont: .caption,
        enableTooltips: true,
        tooltipDelay: 0.0, // No delay for immediate feedback
        highlightToday: true,
        todayHighlightColor: .blue,
        todayHighlightWidth: 2,
        animationDuration: 0.0, // No animations for maximum performance
        animateColorTransitions: false,
        scaleOnHover: false,
        hoverScale: 1.0
    )

    // MARK: - Computed Properties

    /// Total cell size including spacing
    public var cellSize: CGFloat {
        squareSize + spacing
    }

    /// Array of day labels based on configuration
    public var dayLabels: [String] {
        showDayLabels ? DayLabelsConstants.withLabels : DayLabelsConstants.empty
    }
}

// MARK: - Layout Constants

/// Constants for heatmap layout calculations
public struct HeatmapLayoutConstants {

    /// Number of days in a week
    public static let daysPerWeek = 7

    /// Number of weeks to display (approximately 52-53 weeks)
    public static let weeksPerYear = 53

    /// Number of days in a rolling year
    public static let rollingYearDays = 365

    /// Minimum tooltip offset from cursor
    public static let tooltipOffset = CGPoint(x: 10, y: -30)

    /// Default animation curve
    public static let defaultAnimationCurve = Animation.easeInOut

    /// Performance threshold for number of hover targets
    public static let performanceThreshold = 400
}

// MARK: - Day Labels Constants

enum DayLabelsConstants {
    static let withLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    static let empty = Array(repeating: "", count: 7)
}
