//
//  RefreshConfig.swift
//  Configuration for refresh timing and paths
//

import Foundation

/// Configuration for refresh behavior. Injectable for testing.
public struct RefreshConfig: Sendable {
    public let fallbackInterval: TimeInterval
    public let debounceInterval: TimeInterval
    public let monitoredPath: String

    public init(fallbackInterval: TimeInterval, debounceInterval: TimeInterval, monitoredPath: String) {
        self.fallbackInterval = fallbackInterval
        self.debounceInterval = debounceInterval
        self.monitoredPath = monitoredPath
    }

    public static func standard(basePath: String) -> RefreshConfig {
        RefreshConfig(
            fallbackInterval: 3600.0,
            debounceInterval: 1.0,
            monitoredPath: basePath + "/projects"
        )
    }

    public static func forTesting() -> RefreshConfig {
        RefreshConfig(
            fallbackInterval: 0.1,
            debounceInterval: 0.01,
            monitoredPath: "/tmp/test-projects"
        )
    }
}
