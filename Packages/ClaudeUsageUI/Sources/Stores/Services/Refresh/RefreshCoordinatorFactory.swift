//
//  RefreshCoordinatorFactory.swift
//  Factory for assembling RefreshCoordinator with its dependencies
//

import Foundation

// MARK: - Monitor Builder (OCP: Open for Extension)

/// Dependencies available to monitor builders
struct MonitorDependencies: Sendable {
    let config: RefreshConfig
    let clock: any ClockProtocol
    let dayTracker: DayTracker
    let onRefresh: @MainActor @Sendable (RefreshReason) -> Void
}

/// Builder function type: dependencies → monitor
/// Add new monitor types by creating new builders, not modifying factory
typealias MonitorBuilder = @MainActor (MonitorDependencies) -> any RefreshMonitor

// MARK: - Default Monitor Builders (Composable)

@MainActor
enum MonitorBuilders {
    static let fileChange: MonitorBuilder = { deps in
        FileChangeMonitor(
            path: deps.config.monitoredPath,
            debounceInterval: deps.config.debounceInterval,
            onRefresh: deps.onRefresh
        )
    }

    static let fallbackTimer: MonitorBuilder = { deps in
        FallbackTimer(
            interval: deps.config.fallbackInterval,
            onRefresh: deps.onRefresh
        )
    }

    static let dayChange: MonitorBuilder = { deps in
        DayChangeMonitor(
            clock: deps.clock,
            dayTracker: deps.dayTracker,
            onRefresh: deps.onRefresh
        )
    }

    static let wake: MonitorBuilder = { deps in
        WakeMonitor(
            clock: deps.clock,
            dayTracker: deps.dayTracker,
            onRefresh: deps.onRefresh
        )
    }

    /// Production monitor set - compose custom sets by combining builders
    static let production: [MonitorBuilder] = [
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
enum RefreshCoordinatorFactory {

    static func make(
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

    static func make(
        clock: any ClockProtocol = SystemClock(),
        basePath: String = realHomeDirectory() + "/.claude"
    ) -> RefreshCoordinator {
        make(clock: clock, config: .standard(basePath: basePath))
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

// MARK: - Home Directory Helper

private func realHomeDirectory() -> String {
    guard let pw = getpwuid(getuid()) else { return NSHomeDirectory() }
    return String(cString: pw.pointee.pw_dir)
}
