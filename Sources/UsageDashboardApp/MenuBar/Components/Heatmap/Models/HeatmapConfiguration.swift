//
//  HeatmapConfiguration.swift
//  Configuration models for heatmap customization
//
//  Provides type-safe configuration options for heatmap appearance,
//  layout, and behavior with sensible defaults.
//

import SwiftUI
import Foundation

// MARK: - Heatmap Configuration

/// Configuration settings for heatmap appearance and behavior
public struct HeatmapConfiguration: Equatable {
    
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
        if showDayLabels {
            return ["", "Mon", "", "Wed", "", "Fri", ""]
        } else {
            return Array(repeating: "", count: 7)
        }
    }
}

// MARK: - Color Themes

/// Predefined color themes for heatmap visualization
public enum HeatmapColorTheme: String, CaseIterable, Equatable {
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
    
    /// Colors for this theme
    public var colors: [Color] {
        switch self {
        case .github:
            return [
                Color(red: 240/255, green: 242/255, blue: 245/255),  // Level 0: Light gray (no activity)
                Color(red: 186/255, green: 236/255, blue: 191/255),  // Level 1: Very light green
                Color(red: 109/255, green: 191/255, blue: 116/255),  // Level 2: Light green
                Color(red: 83/255, green: 162/255, blue: 88/255),    // Level 3: Medium green
                Color(red: 45/255, green: 97/255, blue: 48/255)      // Level 4: Dark green
            ]
        case .ocean:
            return [
                Color.gray.opacity(0.3),      // Empty
                Color.blue.opacity(0.25),     // Low
                Color.blue.opacity(0.45),     // Medium-low
                Color.blue.opacity(0.65),     // Medium-high
                Color.blue                    // High
            ]
        case .sunset:
            return [
                Color.gray.opacity(0.3),      // Empty
                Color.yellow.opacity(0.4),    // Low
                Color.orange.opacity(0.6),    // Medium-low
                Color.red.opacity(0.7),       // Medium-high
                Color.red                     // High
            ]
        case .forest:
            return [
                Color.gray.opacity(0.3),      // Empty
                Color.mint.opacity(0.3),      // Low
                Color.green.opacity(0.5),     // Medium-low
                Color.green.opacity(0.7),     // Medium-high
                Color(red: 0, green: 0.5, blue: 0) // High (dark green)
            ]
        case .monochrome:
            return [
                Color.gray.opacity(0.3),      // Empty
                Color.gray.opacity(0.5),      // Low
                Color.gray.opacity(0.7),      // Medium-low
                Color.gray.opacity(0.85),     // Medium-high
                Color.gray                    // High
            ]
        }
    }
    
    /// Get color for specific intensity level
    public func color(for level: Int) -> Color {
        let index = max(0, min(colors.count - 1, level))
        return colors[index]
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
public struct HeatmapAccessibility: Equatable {
    
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
        var issues: [String] = []
        
        if squareSize <= 0 {
            issues.append("Square size must be greater than 0")
        }
        
        if spacing < 0 {
            issues.append("Spacing cannot be negative")
        }
        
        if cornerRadius < 0 {
            issues.append("Corner radius cannot be negative")
        }
        
        if tooltipDelay < 0 {
            issues.append("Tooltip delay cannot be negative")
        }
        
        if animationDuration < 0 {
            issues.append("Animation duration cannot be negative")
        }
        
        if hoverScale <= 0 {
            issues.append("Hover scale must be greater than 0")
        }
        
        if todayHighlightWidth < 0 {
            issues.append("Today highlight width cannot be negative")
        }
        
        return issues
    }
    
    /// Whether the configuration is valid
    var isValid: Bool {
        validate().isEmpty
    }
}