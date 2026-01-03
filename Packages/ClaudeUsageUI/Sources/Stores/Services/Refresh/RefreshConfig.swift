//
//  RefreshConfig.swift
//  Configuration for refresh timing and paths
//

import Foundation

/// Configuration for refresh behavior. Injectable for testing.
struct RefreshConfig {
    let fallbackInterval: TimeInterval
    let debounceInterval: TimeInterval
    let monitoredPath: String

    static func standard(basePath: String) -> RefreshConfig {
        RefreshConfig(
            fallbackInterval: 3600.0,
            debounceInterval: 1.0,
            monitoredPath: basePath + "/projects"
        )
    }

    static func forTesting() -> RefreshConfig {
        RefreshConfig(
            fallbackInterval: 0.1,
            debounceInterval: 0.01,
            monitoredPath: "/tmp/test-projects"
        )
    }
}
