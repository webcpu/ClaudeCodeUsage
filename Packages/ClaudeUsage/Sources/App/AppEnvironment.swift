//
//  AppEnvironment.swift
//  Single container for all app dependencies
//

import SwiftUI

// MARK: - App Environment

@MainActor
public struct AppEnvironment: @unchecked Sendable {
    public let glanceStore: GlanceStore
    public let insightsStore: InsightsStore
    public let settings: AppSettingsService

    public init(
        glanceStore: GlanceStore = GlanceStore(),
        insightsStore: InsightsStore = InsightsStore(),
        settings: AppSettingsService = AppSettingsService()
    ) {
        self.glanceStore = glanceStore
        self.insightsStore = insightsStore
        self.settings = settings
    }

    public static func live() -> AppEnvironment {
        AppEnvironment()
    }
}
