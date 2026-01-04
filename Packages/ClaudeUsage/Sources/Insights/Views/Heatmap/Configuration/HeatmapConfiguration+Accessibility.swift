//
//  HeatmapConfiguration+Accessibility.swift
//
//  Accessibility settings and validation for heatmap configuration.
//

import Foundation

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

// MARK: - Validation Rules

enum ValidationRules {
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
