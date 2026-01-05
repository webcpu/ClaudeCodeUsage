//
//  ActivityLevel.swift
//  Activity level classification for tooltip display
//

import SwiftUI

// MARK: - Activity Level Descriptor (OCP: Open for Extension)

/// Describes an activity level with its threshold, text, and color.
/// Add new levels by adding entries to the registry, not by modifying code.
struct ActivityLevelDescriptor: Sendable {
    let threshold: Double
    let text: String
    let color: Color

    /// Registry of activity levels, ordered from lowest to highest threshold.
    /// Intensity is classified by finding the first descriptor where intensity >= threshold.
    static let registry: [ActivityLevelDescriptor] = [
        ActivityLevelDescriptor(threshold: 0.75, text: "Very High", color: .red),
        ActivityLevelDescriptor(threshold: 0.5, text: "High", color: .orange),
        ActivityLevelDescriptor(threshold: 0.25, text: "Medium", color: .green),
        ActivityLevelDescriptor(threshold: 0.001, text: "Low", color: .green.opacity(0.7)),
        ActivityLevelDescriptor(threshold: 0, text: "None", color: .gray)
    ]

    /// Classify intensity to find the appropriate descriptor
    static func classify(intensity: Double) -> ActivityLevelDescriptor {
        registry.first { intensity >= $0.threshold } ?? registry.last!
    }
}

// MARK: - Activity Level (Computed from Descriptor)

/// Activity level classification based on intensity.
/// Uses ActivityLevelDescriptor registry for OCP-compliant classification.
struct ActivityLevel: Sendable {
    private let descriptor: ActivityLevelDescriptor

    init(intensity: Double) {
        self.descriptor = ActivityLevelDescriptor.classify(intensity: intensity)
    }

    var text: String { descriptor.text }
    var color: Color { descriptor.color }
}
