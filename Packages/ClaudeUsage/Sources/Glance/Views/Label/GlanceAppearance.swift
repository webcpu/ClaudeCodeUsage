//
//  GlanceAppearance.swift
//  Appearance configuration for menu bar label
//

import SwiftUI

// MARK: - Glance Appearance Config

/// Configuration for a glance appearance state.
/// Registry pattern: each appearance is a configuration bundle, not a switch case.
struct GlanceAppearanceConfig {
    let icon: String
    let color: Color
}

// MARK: - Glance Appearance Registry

/// Registry of glance appearance configurations.
/// Open for extension (add new appearances), closed for modification (no switch changes needed).
@MainActor
enum GlanceAppearanceRegistry {
    static let active = GlanceAppearanceConfig(
        icon: "dollarsign.circle.fill",
        color: .green
    )

    static let warning = GlanceAppearanceConfig(
        icon: "exclamationmark.triangle.fill",
        color: .orange
    )

    static let normal = GlanceAppearanceConfig(
        icon: "dollarsign.circle",
        color: .primary
    )

    /// Selects the appropriate appearance configuration based on store state.
    static func select(from store: GlanceStore) -> GlanceAppearanceConfig {
        if store.hasActiveSession { return active }
        return normal
    }
}

// MARK: - GlanceStore Appearance Helpers

extension GlanceStore {
    var hasActiveSession: Bool {
        activeSession?.isActive == true
    }
}
