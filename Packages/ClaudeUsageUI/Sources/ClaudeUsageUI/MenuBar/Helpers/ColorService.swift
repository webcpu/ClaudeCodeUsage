//
//  ColorService.swift
//  Business logic for color determination based on performance metrics
//

import SwiftUI

@available(macOS 13.0, *)
struct ColorService {

    // MARK: - Public API

    static func colorForPercentage(_ percentage: Double) -> Color {
        color(for: percentage, using: percentageThresholds)
    }

    static func colorForCostProgress(_ progress: Double) -> Color {
        color(for: progress, using: costProgressThresholds)
    }

    static func sessionTimeSegments() -> [ProgressSegment] {
        timeSegmentRanges
    }

    static func sessionTokenSegments() -> [ProgressSegment] {
        tokenSegmentRanges
    }

    static func singleColorSegment(color: Color) -> [ProgressSegment] {
        [ProgressSegment(range: 0...1.0, color: color)]
    }

    // MARK: - Threshold Lookup (Pure Function)

    private static func color(
        for value: Double,
        using thresholds: [ColorThreshold]
    ) -> Color {
        thresholds
            .first { value < $0.upperBound }
            .map(\.color)
            ?? MenuBarTheme.Colors.Status.critical
    }

    // MARK: - Threshold Definitions

    private static var percentageThresholds: [ColorThreshold] {
        [
            ColorThreshold(
                upperBound: MenuBarTheme.Thresholds.Percentage.low,
                color: MenuBarTheme.Colors.Status.active
            ),
            ColorThreshold(
                upperBound: MenuBarTheme.Thresholds.Percentage.high,
                color: MenuBarTheme.Colors.Status.warning
            ),
        ]
    }

    private static var costProgressThresholds: [ColorThreshold] {
        [
            ColorThreshold(
                upperBound: MenuBarTheme.Thresholds.Cost.normal,
                color: MenuBarTheme.Colors.Status.active
            ),
            ColorThreshold(
                upperBound: MenuBarTheme.Thresholds.Cost.critical,
                color: MenuBarTheme.Colors.Status.warning
            ),
        ]
    }

    // MARK: - Segment Definitions

    private static var timeSegmentRanges: [ProgressSegment] {
        [
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
    }

    private static var tokenSegmentRanges: [ProgressSegment] {
        [
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
    }
}

// MARK: - Supporting Types

@available(macOS 13.0, *)
private struct ColorThreshold {
    let upperBound: Double
    let color: Color
}

@available(macOS 13.0, *)
struct ProgressSegment {
    let range: ClosedRange<Double>
    let color: Color
}