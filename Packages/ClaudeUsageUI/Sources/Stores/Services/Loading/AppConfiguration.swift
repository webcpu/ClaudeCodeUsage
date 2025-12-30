//
//  AppConfiguration.swift
//  App-wide configuration and configuration service
//

import Foundation

// MARK: - Home Directory Helper

/// Returns the real user home directory, even in sandboxed apps.
/// In sandboxed apps, NSHomeDirectory() returns the container path,
/// but we need the actual user home to access ~/.claude
private func realHomeDirectory() -> String {
    guard let pw = getpwuid(getuid()) else { return NSHomeDirectory() }
    return String(cString: pw.pointee.pw_dir)
}

// MARK: - Configuration

public struct AppConfiguration: Sendable {
    let basePath: String
    let refreshInterval: TimeInterval
    let sessionDurationHours: Double
    let dailyCostThreshold: Double

    static let `default` = AppConfiguration(
        basePath: realHomeDirectory() + "/.claude",
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
