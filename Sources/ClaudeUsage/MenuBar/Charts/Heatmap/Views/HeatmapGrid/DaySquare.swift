//
//  DaySquare.swift
//  Day square components for heatmap grid
//

import SwiftUI

// MARK: - Day Square Container

/// Container for day squares handling both filled and empty states
struct DaySquareContainer: View {
    let day: HeatmapDay?
    let configuration: HeatmapConfiguration
    let isHovered: Bool
    let accessibility: HeatmapAccessibility

    var body: some View {
        Group {
            if let day = day {
                DaySquare(
                    day: day,
                    configuration: configuration,
                    isHovered: isHovered,
                    accessibility: accessibility
                )
            } else {
                // Empty placeholder for consistent grid layout
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: configuration.squareSize, height: configuration.squareSize)
            }
        }
    }
}

// MARK: - Day Square

/// Individual day square component with optimized rendering
struct DaySquare: View {
    let day: HeatmapDay
    let configuration: HeatmapConfiguration
    let isHovered: Bool
    let accessibility: HeatmapAccessibility

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    private var dayColor: Color {
        day.color(for: colorScheme)
    }

    private var borderStyle: BorderStyle {
        BorderStyle.forDay(day, isHovered: isHovered, config: configuration)
    }

    private var scaleEffect: CGFloat {
        configuration.scaleOnHover && isHovered ? configuration.hoverScale : 1.0
    }

    private var hoverAnimation: Animation? {
        configuration.animationDuration > 0
            ? .easeInOut(duration: configuration.animationDuration)
            : nil
    }

    // MARK: - Body

    var body: some View {
        Rectangle()
            .fill(dayColor)
            .frame(width: configuration.squareSize, height: configuration.squareSize)
            .cornerRadius(configuration.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .stroke(borderStyle.color, lineWidth: borderStyle.width)
            )
            .scaleEffect(scaleEffect)
            .animation(hoverAnimation, value: isHovered)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        accessibility.enableAccessibilityLabels
            ? "\(accessibility.dateAccessibilityPrefix) \(day.dateString)"
            : ""
    }

    private var accessibilityValue: String {
        accessibility.enableAccessibilityValues
            ? "\(accessibility.costAccessibilityPrefix) \(day.costString)"
            : ""
    }
}
