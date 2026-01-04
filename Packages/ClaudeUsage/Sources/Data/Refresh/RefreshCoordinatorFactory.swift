//
//  RefreshCoordinatorFactory.swift
//  Factory for assembling RefreshCoordinator with its dependencies
//

import Foundation
import ClaudeUsageCore

// MARK: - Monitor Builder (OCP: Open for Extension)

/// Dependencies available to monitor builders
public struct MonitorDependencies: Sendable {
    public let config: RefreshConfig
    public let clock: any ClockProtocol
    public let dayTracker: DayTracker
    public let onRefresh: @MainActor @Sendable (RefreshReason) -> Void

    public init(config: RefreshConfig, clock: any ClockProtocol, dayTracker: DayTracker, onRefresh: @escaping @MainActor @Sendable (RefreshReason) -> Void) {
        self.config = config
        self.clock = clock
        self.dayTracker = dayTracker
        self.onRefresh = onRefresh
    }
}

/// Builder function type: dependencies → monitor
/// Add new monitor types by creating new builders, not modifying factory
public typealias MonitorBuilder = @MainActor (MonitorDependencies) -> any RefreshMonitor

// MARK: - Default Monitor Builders (Composable)

@MainActor
public enum MonitorBuilders {
    public static let fileChange: MonitorBuilder = { deps in
        FileChangeMonitor(
            path: deps.config.monitoredPath,
            debounceInterval: deps.config.debounceInterval,
            onRefresh: deps.onRefresh
        )
    }

    public static let fallbackTimer: MonitorBuilder = { deps in
        FallbackTimer(
            interval: deps.config.fallbackInterval,
            onRefresh: deps.onRefresh
        )
    }

    public static let dayChange: MonitorBuilder = { deps in
        DayChangeMonitor(
            clock: deps.clock,
            dayTracker: deps.dayTracker,
            onRefresh: deps.onRefresh
        )
    }

    public static let wake: MonitorBuilder = { deps in
        WakeMonitor(
            clock: deps.clock,
            dayTracker: deps.dayTracker,
            onRefresh: deps.onRefresh
        )
    }

    /// Production monitor set - compose custom sets by combining builders
    public static let production: [MonitorBuilder] = [
        fileChange,
        fallbackTimer,
        dayChange,
        wake
    ]
}

// MARK: - Factory (Closed for Modification)

/// Factory that assembles RefreshCoordinator with production dependencies.
///
/// OCP compliant: extend by passing custom builders, not by modifying this code.
/// For testing, create RefreshCoordinator directly with mock monitors.
@MainActor
public enum RefreshCoordinatorFactory {

    public static func make(
        clock: any ClockProtocol = SystemClock(),
        config: RefreshConfig,
        builders: [MonitorBuilder] = MonitorBuilders.production
    ) -> RefreshCoordinator {
        let coordinator = RefreshCoordinator()
        let monitors = buildMonitors(
            using: builders,
            config: config,
            clock: clock,
            coordinator: coordinator
        )
        coordinator.setMonitors(monitors)
        coordinator.start()
        return coordinator
    }

    public static func make(
        clock: any ClockProtocol = SystemClock(),
        basePath: String? = nil
    ) -> RefreshCoordinator {
        let path = basePath ?? (realHomeDirectory() + "/.claude")
        return make(clock: clock, config: .standard(basePath: path))
    }
}

// MARK: - Private Helpers

private extension RefreshCoordinatorFactory {

    static func buildMonitors(
        using builders: [MonitorBuilder],
        config: RefreshConfig,
        clock: any ClockProtocol,
        coordinator: RefreshCoordinator
    ) -> [any RefreshMonitor] {
        let deps = makeDependencies(config: config, clock: clock, coordinator: coordinator)
        return builders.map { $0(deps) }
    }

    static func makeDependencies(
        config: RefreshConfig,
        clock: any ClockProtocol,
        coordinator: RefreshCoordinator
    ) -> MonitorDependencies {
        MonitorDependencies(
            config: config,
            clock: clock,
            dayTracker: DayTracker(clock: clock),
            onRefresh: { [weak coordinator] reason in
                coordinator?.triggerRefresh(reason: reason)
            }
        )
    }
}
