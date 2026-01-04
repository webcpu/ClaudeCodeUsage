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
            upperBound: GlanceTheme.Thresholds.Percentage.low,
            color: GlanceTheme.Colors.Status.active
        ),
        ColorThreshold(
            upperBound: GlanceTheme.Thresholds.Percentage.high,
            color: GlanceTheme.Colors.Status.warning
        ),
    ]

    // MARK: - Cost Progress Thresholds

    static let costProgress: [ColorThreshold] = [
        ColorThreshold(
            upperBound: GlanceTheme.Thresholds.Cost.normal,
            color: GlanceTheme.Colors.Status.active
        ),
        ColorThreshold(
            upperBound: GlanceTheme.Thresholds.Cost.critical,
            color: GlanceTheme.Colors.Status.warning
        ),
    ]

    // MARK: - Fallback Color

    static let fallbackColor = GlanceTheme.Colors.Status.critical
}

// MARK: - Segment Registry

/// Registry of progress segment configurations.
/// Open for extension (add new segment types), closed for modification (no switch changes needed).
@available(macOS 13.0, *)
enum SegmentRegistry {

    // MARK: - Time Segments

    static let sessionTime: [ProgressSegment] = [
        ProgressSegment(
            range: 0...GlanceTheme.Thresholds.Sessions.timeSegments.low,
            color: GlanceTheme.Colors.ProgressSegments.green
        ),
        ProgressSegment(
            range: GlanceTheme.Thresholds.Sessions.timeSegments.low...GlanceTheme.Thresholds.Sessions.timeSegments.medium,
            color: GlanceTheme.Colors.ProgressSegments.orange
        ),
        ProgressSegment(
            range: GlanceTheme.Thresholds.Sessions.timeSegments.medium...GlanceTheme.Thresholds.Sessions.timeSegments.max,
            color: GlanceTheme.Colors.ProgressSegments.red
        ),
    ]

    // MARK: - Token Segments

    static let sessionToken: [ProgressSegment] = [
        ProgressSegment(
            range: 0...GlanceTheme.Thresholds.Sessions.tokenSegments.low,
            color: GlanceTheme.Colors.ProgressSegments.blue
        ),
        ProgressSegment(
            range: GlanceTheme.Thresholds.Sessions.tokenSegments.low...GlanceTheme.Thresholds.Sessions.tokenSegments.medium,
            color: GlanceTheme.Colors.ProgressSegments.purple
        ),
        ProgressSegment(
            range: GlanceTheme.Thresholds.Sessions.tokenSegments.medium...GlanceTheme.Thresholds.Sessions.tokenSegments.max,
            color: GlanceTheme.Colors.ProgressSegments.red
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