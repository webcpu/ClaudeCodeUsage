//
//  AppConfiguration.swift
//  App-wide configuration
//

import Foundation

// MARK: - Home Directory Helper

/// Returns the real user home directory, even in sandboxed apps.
/// In sandboxed apps, NSHomeDirectory() returns the container path,
/// but we need the actual user home to access ~/.claude
public func realHomeDirectory() -> String {
    guard let pw = getpwuid(getuid()) else { return NSHomeDirectory() }
    return String(cString: pw.pointee.pw_dir)
}

// MARK: - Configuration

public struct AppConfiguration: Sendable {
    public let basePath: String
    public let refreshInterval: TimeInterval
    public let sessionDurationHours: Double
    public let dailyCostThreshold: Double

    public init(
        basePath: String,
        refreshInterval: TimeInterval,
        sessionDurationHours: Double,
        dailyCostThreshold: Double
    ) {
        self.basePath = basePath
        self.refreshInterval = refreshInterval
        self.sessionDurationHours = sessionDurationHours
        self.dailyCostThreshold = dailyCostThreshold
    }

    public static let `default` = AppConfiguration(
        basePath: realHomeDirectory() + "/.claude",
        refreshInterval: 30.0,
        sessionDurationHours: 5.0,
        dailyCostThreshold: 10.0
    )

    public static func load() -> AppConfiguration {
        // Future: Load from UserDefaults or config file
        return .default
    }
}

// MARK: - Configuration Service

public protocol ConfigurationService: Sendable {
    var configuration: AppConfiguration { get }
}

public final class DefaultConfigurationService: ConfigurationService, @unchecked Sendable {
    public let configuration: AppConfiguration

    public init() {
        self.configuration = AppConfiguration.load()
    }
}
