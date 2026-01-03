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
final class RefreshCoordinator {
    private var monitors: [any RefreshMonitor]

    var onRefresh: ((RefreshReason) async -> Void)?

    // MARK: - Initialization

    init(monitors: [any RefreshMonitor] = []) {
        self.monitors = monitors
    }

    /// Sets monitors after initialization. Used by factory to resolve circular dependency.
    func setMonitors(_ monitors: [any RefreshMonitor]) {
        self.monitors = monitors
    }

    /// Starts all monitors. Called once by factory after construction.
    func start() {
        monitors.forEach { $0.start() }
    }

    // MARK: - Lifecycle Events

    func handleAppBecameActive() {
        triggerRefresh(reason: .appBecameActive)
    }

    func handleAppResignActive() {
        // Menu bar apps: passive monitors keep running
    }

    func handleWindowFocus() {
        triggerRefresh(reason: .windowFocus)
    }

    // MARK: - Refresh Dispatch

    func triggerRefresh(reason: RefreshReason) {
        logger.info("Refresh triggered: \(String(describing: reason), privacy: .public)")
        Task { await onRefresh?(reason) }
    }
}
