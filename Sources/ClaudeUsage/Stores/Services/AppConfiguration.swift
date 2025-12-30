//
//  AppConfiguration.swift
//  App-wide configuration and configuration service
//

import Foundation

// MARK: - Configuration

public struct AppConfiguration: Sendable {
    let basePath: String
    let refreshInterval: TimeInterval
    let sessionDurationHours: Double
    let dailyCostThreshold: Double

    static let `default` = AppConfiguration(
        basePath: NSHomeDirectory() + "/.claude",
        refreshInterval: 30.0,
        sessionDurationHours: 5.0,
        dailyCostThreshold: 10.0
    )

    static func load() -> AppConfiguration {
        // Future: Load from UserDefaults or config file
        return .default
    }
}

// MARK: - Configuration Service

protocol ConfigurationService {
    var configuration: AppConfiguration { get }
}

final class DefaultConfigurationService: ConfigurationService {
    let configuration: AppConfiguration

    init() {
        self.configuration = AppConfiguration.load()
    }
}
