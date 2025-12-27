//
//  AppConfiguration.swift
//  App-wide configuration and configuration service
//

import Foundation
import Observation

// MARK: - Configuration

public struct AppConfiguration: Sendable {
    let basePath: String
    let refreshInterval: TimeInterval
    let sessionDurationHours: Double
    let dailyCostThreshold: Double
    let minimumRefreshInterval: TimeInterval

    static let `default` = AppConfiguration(
        basePath: NSHomeDirectory() + "/.claude",
        refreshInterval: 30.0,
        sessionDurationHours: 5.0,
        dailyCostThreshold: 10.0,
        minimumRefreshInterval: 5.0
    )

    static func load() -> AppConfiguration {
        // Future: Load from UserDefaults or config file
        return .default
    }
}

// MARK: - Configuration Service

protocol ConfigurationService {
    var configuration: AppConfiguration { get }
    func updateConfiguration(_ config: AppConfiguration)
}

@Observable
final class DefaultConfigurationService: ConfigurationService {
    private(set) var configuration: AppConfiguration

    init() {
        self.configuration = AppConfiguration.load()
    }

    func updateConfiguration(_ config: AppConfiguration) {
        self.configuration = config
    }
}
