//
//  RefreshCoordinator.swift
//  Facade that coordinates refresh monitors
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Refresh")

/// Coordinates multiple refresh monitors.
///
/// This is a facade that depends on abstractions (RefreshMonitor protocol),
/// not concrete implementations (DIP). Monitors are injected and auto-started.
@MainActor
public final class RefreshCoordinator {
    private var monitors: [any RefreshMonitor]

    public var onRefresh: ((RefreshReason) async -> Void)?

    // MARK: - Initialization

    public init(monitors: [any RefreshMonitor] = []) {
        self.monitors = monitors
    }

    /// Sets monitors after initialization. Used by factory to resolve circular dependency.
    public func setMonitors(_ monitors: [any RefreshMonitor]) {
        self.monitors = monitors
    }

    /// Starts all monitors. Called once by factory after construction.
    public func start() {
        monitors.forEach { $0.start() }
    }

    // MARK: - Lifecycle Events

    public func handleAppBecameActive() {
        triggerRefresh(reason: .appBecameActive)
    }

    public func handleAppResignActive() {
        // Menu bar apps: passive monitors keep running
    }

    public func handleWindowFocus() {
        triggerRefresh(reason: .windowFocus)
    }

    // MARK: - Refresh Dispatch

    public func triggerRefresh(reason: RefreshReason) {
        Task { await onRefresh?(reason) }
    }
}
