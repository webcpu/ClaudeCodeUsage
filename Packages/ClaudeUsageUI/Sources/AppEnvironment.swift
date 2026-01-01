//
//  AppEnvironment.swift
//  Single container for all app dependencies
//

import SwiftUI

// MARK: - App Environment

@MainActor
public struct AppEnvironment: @unchecked Sendable {
    public let store: UsageStore
    public let settings: AppSettingsService

    public init(store: UsageStore = UsageStore(), settings: AppSettingsService = AppSettingsService()) {
        self.store = store
        self.settings = settings
    }

    public static func live() -> AppEnvironment {
        AppEnvironment()
    }
}
