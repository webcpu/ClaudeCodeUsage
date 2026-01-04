//
//  LegendSquare.swift
//  Individual square component for legend visualization
//

import SwiftUI

// MARK: - Legend Square

/// Individual square in the legend
struct LegendSquare: View {
    let level: Int
    let accessibility: HeatmapAccessibility

    @Environment(\.colorScheme) private var colorScheme

    private var squareColor: Color {
        HeatmapColorScheme.color(for: level, scheme: colorScheme)
    }

    var body: some View {
        Rectangle()
            .fill(squareColor)
            .frame(width: 11, height: 11)
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
    }

    private var accessibilityLabel: String {
        guard accessibility.enableAccessibilityLabels else { return "" }
        return ActivityLevelLabels.label(for: level)
    }

    private var accessibilityValue: String {
        guard accessibility.enableAccessibilityValues else { return "" }
        return "Level \(level) of 4"
    }
}
