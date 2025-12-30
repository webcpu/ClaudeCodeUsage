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

    static func forDay(_ day: HeatmapDay, isHovered: Bool, config: HeatmapConfiguration) -> BorderStyle {
        if day.isToday {
            return BorderStyle(color: config.todayHighlightColor, width: config.todayHighlightWidth)
        } else if isHovered {
            return BorderStyle(color: .primary, width: 1)
        } else {
            return .none
        }
    }
}
