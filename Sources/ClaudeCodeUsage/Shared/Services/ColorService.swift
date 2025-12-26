//
//  ColorService.swift
//  Business logic for color determination based on performance metrics
//

import SwiftUI

@available(macOS 13.0, *)
struct ColorService {
    
    // MARK: - Percentage-based Colors
    static func colorForPercentage(_ percentage: Double) -> Color {
        switch percentage {
        case 0..<MenuBarTheme.Thresholds.Percentage.low:
            return MenuBarTheme.Colors.Status.active
        case MenuBarTheme.Thresholds.Percentage.low..<MenuBarTheme.Thresholds.Percentage.medium:
            return MenuBarTheme.Colors.Status.warning
        case MenuBarTheme.Thresholds.Percentage.medium..<MenuBarTheme.Thresholds.Percentage.high:
            return MenuBarTheme.Colors.Status.warning
        default:
            return MenuBarTheme.Colors.Status.critical
        }
    }
    
    // MARK: - Cost Progress Colors
    static func colorForCostProgress(_ progress: Double) -> Color {
        switch progress {
        case 0..<MenuBarTheme.Thresholds.Cost.normal:
            return MenuBarTheme.Colors.Status.active
        case MenuBarTheme.Thresholds.Cost.normal..<MenuBarTheme.Thresholds.Cost.warning:
            return MenuBarTheme.Colors.Status.warning
        case MenuBarTheme.Thresholds.Cost.warning..<MenuBarTheme.Thresholds.Cost.critical:
            return MenuBarTheme.Colors.Status.warning
        default:
            return MenuBarTheme.Colors.Status.critical
        }
    }
    
    // MARK: - Session Time Progress Segments
    static func sessionTimeSegments() -> [ProgressSegment] {
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
            )
        ]
    }
    
    // MARK: - Session Token Progress Segments
    static func sessionTokenSegments() -> [ProgressSegment] {
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
            )
        ]
    }
    
    // MARK: - Single Color Segments (for simple progress bars)
    static func singleColorSegment(color: Color) -> [ProgressSegment] {
        [ProgressSegment(range: 0...1.0, color: color)]
    }
}

// MARK: - Supporting Types
@available(macOS 13.0, *)
struct ProgressSegment {
    let range: ClosedRange<Double>
    let color: Color
}