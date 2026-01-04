//
//  ColorService.swift
//  Business logic for color determination based on performance metrics
//

import SwiftUI

// MARK: - Supporting Types

@available(macOS 13.0, *)
struct ColorThreshold {
    let upperBound: Double
    let color: Color
}

@available(macOS 13.0, *)
struct ProgressSegment {
    let range: ClosedRange<Double>
    let color: Color
}

// MARK: - Threshold Registry

/// Registry of color threshold configurations.
/// Open for extension (add new threshold types), closed for modification (no switch changes needed).
@available(macOS 13.0, *)
enum ThresholdRegistry {

    // MARK: - Percentage Thresholds

    static let percentage: [ColorThreshold] = [
        ColorThreshold(
            upperBound: MenuBarTheme.Thresholds.Percentage.low,
            color: MenuBarTheme.Colors.Status.active
        ),
        ColorThreshold(
            upperBound: MenuBarTheme.Thresholds.Percentage.high,
            color: MenuBarTheme.Colors.Status.warning
        ),
    ]

    // MARK: - Cost Progress Thresholds

    static let costProgress: [ColorThreshold] = [
        ColorThreshold(
            upperBound: MenuBarTheme.Thresholds.Cost.normal,
            color: MenuBarTheme.Colors.Status.active
        ),
        ColorThreshold(
            upperBound: MenuBarTheme.Thresholds.Cost.critical,
            color: MenuBarTheme.Colors.Status.warning
        ),
    ]

    // MARK: - Fallback Color

    static let fallbackColor = MenuBarTheme.Colors.Status.critical
}

// MARK: - Segment Registry

/// Registry of progress segment configurations.
/// Open for extension (add new segment types), closed for modification (no switch changes needed).
@available(macOS 13.0, *)
enum SegmentRegistry {

    // MARK: - Time Segments

    static let sessionTime: [ProgressSegment] = [
        ProgressSegment(
            range: 0...MenuBarTheme.Thresholds.Sessions.timeSegments.low,
            color: MenuBarTheme.Colors.ProgressSegments.green
        ),
        ProgressSegment(
            range: MenuBarTheme.Thresholds.Sessions.timeSegments.low...MenuBarTheme.Thresholds.Sessions.timeSegments.medium,
            color: MenuBarTheme.Colors.ProgressSegments.orange
        ),
        ProgressSegment(
            range: MenuBarTheme.Thresholds.Sessions.timeSegments.medium...MenuBarTheme.Thresholds.Sessions.timeSegments.max,
            color: MenuBarTheme.Colors.ProgressSegments.red
        ),
    ]

    // MARK: - Token Segments

    static let sessionToken: [ProgressSegment] = [
        ProgressSegment(
            range: 0...MenuBarTheme.Thresholds.Sessions.tokenSegments.low,
            color: MenuBarTheme.Colors.ProgressSegments.blue
        ),
        ProgressSegment(
            range: MenuBarTheme.Thresholds.Sessions.tokenSegments.low...MenuBarTheme.Thresholds.Sessions.tokenSegments.medium,
            color: MenuBarTheme.Colors.ProgressSegments.purple
        ),
        ProgressSegment(
            range: MenuBarTheme.Thresholds.Sessions.tokenSegments.medium...MenuBarTheme.Thresholds.Sessions.tokenSegments.max,
            color: MenuBarTheme.Colors.ProgressSegments.red
        ),
    ]

    // MARK: - Single Color Segment Factory

    static func singleColor(_ color: Color) -> [ProgressSegment] {
        [ProgressSegment(range: 0...1.0, color: color)]
    }
}

// MARK: - Color Service

/// Service for color determination based on performance metrics.
/// Uses registry pattern for threshold/segment lookups.
@available(macOS 13.0, *)
enum ColorService {

    // MARK: - Public API

    static func colorForPercentage(_ percentage: Double) -> Color {
        color(for: percentage, using: ThresholdRegistry.percentage)
    }

    static func colorForCostProgress(_ progress: Double) -> Color {
        color(for: progress, using: ThresholdRegistry.costProgress)
    }

    static func sessionTimeSegments() -> [ProgressSegment] {
        SegmentRegistry.sessionTime
    }

    static func sessionTokenSegments() -> [ProgressSegment] {
        SegmentRegistry.sessionToken
    }

    static func singleColorSegment(color: Color) -> [ProgressSegment] {
        SegmentRegistry.singleColor(color)
    }

    // MARK: - Threshold Lookup (Pure Function)

    private static func color(
        for value: Double,
        using thresholds: [ColorThreshold]
    ) -> Color {
        thresholds
            .first { value < $0.upperBound }
            .map(\.color)
            ?? ThresholdRegistry.fallbackColor
    }
}