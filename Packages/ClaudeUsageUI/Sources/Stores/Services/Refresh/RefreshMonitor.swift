//
//  RefreshMonitor.swift
//  Protocol for refresh event monitors
//

import Foundation

/// Protocol for monitors that detect refresh-triggering events.
///
/// Monitors encapsulate event detection (file changes, timer ticks, system events)
/// and emit RefreshReason through a callback. RefreshCoordinator depends on this
/// abstraction, not concrete implementations (DIP).
@MainActor
protocol RefreshMonitor {
    /// Starts monitoring for events.
    func start()

    /// Stops monitoring and releases resources.
    func stop()
}
