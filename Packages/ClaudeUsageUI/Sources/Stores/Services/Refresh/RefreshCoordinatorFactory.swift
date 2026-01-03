//
//  RefreshCoordinatorFactory.swift
//  Factory for assembling RefreshCoordinator with its dependencies
//

import Foundation

/// Factory that assembles RefreshCoordinator with production dependencies.
///
/// Encapsulates dependency graph construction. For testing, create
/// RefreshCoordinator directly with mock monitors.
@MainActor
enum RefreshCoordinatorFactory {

    static func make(
        clock: any ClockProtocol = SystemClock(),
        config: RefreshConfig
    ) -> RefreshCoordinator {
        let dayTracker = DayTracker(clock: clock)
        let coordinator = RefreshCoordinator()

        let monitors: [any RefreshMonitor] = [
            FileChangeMonitor(
                path: config.monitoredPath,
                debounceInterval: config.debounceInterval,
                onRefresh: { [weak coordinator] reason in
                    coordinator?.triggerRefresh(reason: reason)
                }
            ),
            FallbackTimer(
                interval: config.fallbackInterval,
                onRefresh: { [weak coordinator] reason in
                    coordinator?.triggerRefresh(reason: reason)
                }
            ),
            DayChangeMonitor(
                clock: clock,
                dayTracker: dayTracker,
                onRefresh: { [weak coordinator] reason in
                    coordinator?.triggerRefresh(reason: reason)
                }
            ),
            WakeMonitor(
                clock: clock,
                dayTracker: dayTracker,
                onRefresh: { [weak coordinator] reason in
                    coordinator?.triggerRefresh(reason: reason)
                }
            )
        ]

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

// MARK: - Home Directory Helper

private func realHomeDirectory() -> String {
    guard let pw = getpwuid(getuid()) else { return NSHomeDirectory() }
    return String(cString: pw.pointee.pw_dir)
}
