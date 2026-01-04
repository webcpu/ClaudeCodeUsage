//
//  AppEnvironment.swift
//  Single container for all app dependencies
//

import SwiftUI

// MARK: - App Environment

@MainActor
public struct AppEnvironment: @unchecked Sendable {
    public let sessionStore: SessionStore
    public let analyticsStore: AnalyticsStore
    public let settings: AppSettingsService

    public init(
        sessionStore: SessionStore = SessionStore(),
        analyticsStore: AnalyticsStore = AnalyticsStore(),
        settings: AppSettingsService = AppSettingsService()
    ) {
        self.sessionStore = sessionStore
        self.analyticsStore = analyticsStore
        self.settings = settings
    }

    public static func live() -> AppEnvironment {
        AppEnvironment()
    }
}
