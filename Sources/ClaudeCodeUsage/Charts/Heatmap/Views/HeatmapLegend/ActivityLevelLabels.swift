//
//  ActivityLevelLabels.swift
//  Pure data for activity level accessibility labels
//

import Foundation

// MARK: - Activity Level Labels (Pure Data)

enum ActivityLevelLabels {
    static let labels = [
        "No activity",
        "Low activity",
        "Medium-low activity",
        "Medium-high activity",
        "High activity"
    ]

    static func label(for level: Int) -> String {
        labels.indices.contains(level) ? labels[level] : "Activity level \(level)"
    }
}
