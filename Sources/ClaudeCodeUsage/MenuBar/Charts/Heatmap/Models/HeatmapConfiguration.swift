//
//  HeatmapConfiguration.swift
//  Configuration models for heatmap customization
//
//  Provides type-safe configuration options for heatmap appearance,
//  layout, and behavior with sensible defaults.
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

// MARK: - Preset Configurations

// Preset configurations (default, compact, performanceOptimized) are defined
// as static properties within HeatmapConfiguration above.

// MARK: - Color Themes

/// Predefined color themes for heatmap visualization
public enum HeatmapColorTheme: String, CaseIterable, Equatable, @unchecked Sendable {
    case github = "github"
    case ocean = "ocean"
    case sunset = "sunset"
    case forest = "forest"
    case monochrome = "monochrome"
    
    /// Display name for the theme
    public var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .monochrome: return "Monochrome"
        }
    }
    
    /// Colors for this theme (light mode - legacy)
    public var colors: [Color] {
        colors(for: .light)
    }

    /// Colors for this theme based on color scheme
    public func colors(for scheme: ColorScheme) -> [Color] {
        switch self {
        case .github:
            return scheme == .dark ? githubDarkColors : githubLightColors
        case .ocean:
            return scheme == .dark ? oceanDarkColors : oceanLightColors
        case .sunset:
            return scheme == .dark ? sunsetDarkColors : sunsetLightColors
        case .forest:
            return scheme == .dark ? forestDarkColors : forestLightColors
        case .monochrome:
            return scheme == .dark ? monochromeDarkColors : monochromeLightColors
        }
    }

    /// Get color for specific intensity level (legacy - light mode)
    public func color(for level: Int) -> Color {
        color(for: level, scheme: .light)
    }

    /// Get color for specific intensity level and color scheme
    public func color(for level: Int, scheme: ColorScheme) -> Color {
        let themeColors = colors(for: scheme)
        let index = max(0, min(themeColors.count - 1, level))
        return themeColors[index]
    }

    // MARK: - GitHub Theme Colors

    private var githubLightColors: [Color] {
        [
            Color(red: 235/255, green: 237/255, blue: 240/255),  // Level 0: #ebedf0
            Color(red: 155/255, green: 233/255, blue: 168/255),  // Level 1: #9be9a8
            Color(red: 64/255, green: 196/255, blue: 99/255),    // Level 2: #40c463
            Color(red: 48/255, green: 161/255, blue: 78/255),    // Level 3: #30a14e
            Color(red: 33/255, green: 110/255, blue: 57/255)     // Level 4: #216e39
        ]
    }

    private var githubDarkColors: [Color] {
        [
            Color(red: 22/255, green: 27/255, blue: 34/255),     // Level 0: #161b22
            Color(red: 14/255, green: 68/255, blue: 41/255),     // Level 1: #0e4429
            Color(red: 0/255, green: 109/255, blue: 50/255),     // Level 2: #006d32
            Color(red: 38/255, green: 166/255, blue: 65/255),    // Level 3: #26a641
            Color(red: 57/255, green: 211/255, blue: 83/255)     // Level 4: #39d353
        ]
    }

    // MARK: - Ocean Theme Colors

    private var oceanLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.blue.opacity(0.25),
            Color.blue.opacity(0.45),
            Color.blue.opacity(0.65),
            Color.blue
        ]
    }

    private var oceanDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.blue.opacity(0.35),
            Color.blue.opacity(0.55),
            Color.blue.opacity(0.75),
            Color(red: 0.3, green: 0.6, blue: 1.0)
        ]
    }

    // MARK: - Sunset Theme Colors

    private var sunsetLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.yellow.opacity(0.4),
            Color.orange.opacity(0.6),
            Color.red.opacity(0.7),
            Color.red
        ]
    }

    private var sunsetDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.yellow.opacity(0.5),
            Color.orange.opacity(0.7),
            Color.red.opacity(0.8),
            Color(red: 1.0, green: 0.3, blue: 0.3)
        ]
    }

    // MARK: - Forest Theme Colors

    private var forestLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.mint.opacity(0.3),
            Color.green.opacity(0.5),
            Color.green.opacity(0.7),
            Color(red: 0, green: 0.5, blue: 0)
        ]
    }

    private var forestDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color.mint.opacity(0.4),
            Color.green.opacity(0.6),
            Color.green.opacity(0.8),
            Color(red: 0.2, green: 0.8, blue: 0.2)
        ]
    }

    // MARK: - Monochrome Theme Colors

    private var monochromeLightColors: [Color] {
        [
            Color.gray.opacity(0.3),
            Color.gray.opacity(0.5),
            Color.gray.opacity(0.7),
            Color.gray.opacity(0.85),
            Color.gray
        ]
    }

    private var monochromeDarkColors: [Color] {
        [
            Color(white: 0.15),
            Color(white: 0.35),
            Color(white: 0.5),
            Color(white: 0.65),
            Color(white: 0.8)
        ]
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

// MARK: - Accessibility Settings

/// Accessibility configuration for the heatmap
public struct HeatmapAccessibility: Equatable, Sendable {
    
    /// Whether to provide accessibility labels
    public let enableAccessibilityLabels: Bool
    
    /// Whether to provide accessibility values
    public let enableAccessibilityValues: Bool
    
    /// Whether to group accessibility elements
    public let groupAccessibilityElements: Bool
    
    /// Custom accessibility prefix for dates
    public let dateAccessibilityPrefix: String
    
    /// Custom accessibility prefix for costs
    public let costAccessibilityPrefix: String
    
    /// Default accessibility configuration
    public static let `default` = HeatmapAccessibility(
        enableAccessibilityLabels: true,
        enableAccessibilityValues: true,
        groupAccessibilityElements: true,
        dateAccessibilityPrefix: "Usage on",
        costAccessibilityPrefix: "Cost:"
    )
    
    /// Disabled accessibility for performance-critical scenarios
    public static let disabled = HeatmapAccessibility(
        enableAccessibilityLabels: false,
        enableAccessibilityValues: false,
        groupAccessibilityElements: false,
        dateAccessibilityPrefix: "",
        costAccessibilityPrefix: ""
    )
}

// MARK: - Validation

public extension HeatmapConfiguration {

    /// Validates the configuration and returns any issues
    func validate() -> [String] {
        ValidationRules.validate(self)
    }

    /// Whether the configuration is valid
    var isValid: Bool {
        validate().isEmpty
    }
}

// MARK: - Private Implementation Details

/// Day label constants for week display
private enum DayLabelsConstants {
    static let withLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    static let empty = Array(repeating: "", count: 7)
}

/// Validation rules for configuration parameters
private enum ValidationRules {
    /// All validation rules as closures that return optional error message
    static let rules: [@Sendable (HeatmapConfiguration) -> String?] = [
        { $0.squareSize <= 0 ? "Square size must be greater than 0" : nil },
        { $0.spacing < 0 ? "Spacing cannot be negative" : nil },
        { $0.cornerRadius < 0 ? "Corner radius cannot be negative" : nil },
        { $0.tooltipDelay < 0 ? "Tooltip delay cannot be negative" : nil },
        { $0.animationDuration < 0 ? "Animation duration cannot be negative" : nil },
        { $0.hoverScale <= 0 ? "Hover scale must be greater than 0" : nil },
        { $0.todayHighlightWidth < 0 ? "Today highlight width cannot be negative" : nil }
    ]

    /// Validate configuration and return all errors
    static func validate(_ config: HeatmapConfiguration) -> [String] {
        rules.compactMap { $0(config) }
    }
}