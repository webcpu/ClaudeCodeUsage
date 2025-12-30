//
//  ActivityLevel.swift
//  Activity level classification for tooltip display
//

import SwiftUI

// MARK: - Activity Level (Pure Data)

/// Activity level classification based on intensity
enum ActivityLevel {
    case none, low, medium, high, veryHigh

    init(intensity: Double) {
        switch intensity {
        case 0: self = .none
        case ..<0.25: self = .low
        case ..<0.5: self = .medium
        case ..<0.75: self = .high
        default: self = .veryHigh
        }
    }

    var text: String {
        switch self {
        case .none: "None"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .veryHigh: "Very High"
        }
    }

    var color: Color {
        switch self {
        case .none: .gray
        case .low: .green.opacity(0.7)
        case .medium: .green
        case .high: .orange
        case .veryHigh: .red
        }
    }
}
