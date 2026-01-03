//
//  BorderStyle.swift
//  Pure data struct for day square border styling
//

import SwiftUI

// MARK: - Border Style (Pure Data)

struct BorderStyle {
    let color: Color
    let width: CGFloat

    static let none = BorderStyle(color: .clear, width: 0)
}

// MARK: - Border Style Rule (OCP Pattern)

struct BorderStyleRule: Sendable {
    let matches: @Sendable (HeatmapDay, Bool, HeatmapConfiguration) -> Bool
    let style: @Sendable (HeatmapConfiguration) -> BorderStyle

    static let rules: [BorderStyleRule] = [
        BorderStyleRule(
            matches: { day, _, _ in day.isToday },
            style: { BorderStyle(color: $0.todayHighlightColor, width: $0.todayHighlightWidth) }
        ),
        BorderStyleRule(
            matches: { _, isHovered, _ in isHovered },
            style: { _ in BorderStyle(color: .primary, width: 1) }
        )
    ]

    static func forDay(_ day: HeatmapDay, isHovered: Bool, config: HeatmapConfiguration) -> BorderStyle {
        rules.first { $0.matches(day, isHovered, config) }?.style(config) ?? .none
    }
}
