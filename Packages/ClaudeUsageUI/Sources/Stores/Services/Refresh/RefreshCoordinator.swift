//
//  RefreshCoordinator.swift
//  Manages refresh via file monitoring, lifecycle events, and day change detection
//

import Foundation
import ClaudeUsageData
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Refresh")

// MARK: - Home Directory Helper

private func realHomeDirectory() -> String {
    guard let pw = getpwuid(getuid()) else { return NSHomeDirectory() }
    return String(cString: pw.pointee.pw_dir)
}

// MARK: - Timing Constants

private enum Timing {
    static let fallbackInterval: TimeInterval = 3600.0
    static let debounceInterval: TimeInterval = 1.0
    static let refreshThreshold: TimeInterval = 2.0
}

// MARK: - Refresh Coordinator

@MainActor
final class RefreshCoordinator {
    private var lastRefreshTime: Date
    private let clock: any ClockProtocol

    private var directoryMonitor: DirectoryMonitor?
    private var fallbackTimer: FallbackTimer?
    private var dayChangeMonitor: DayChangeMonitor?
    private var wakeMonitor: WakeMonitor?

    var onRefresh: ((RefreshReason) async -> Void)?

    // MARK: - Initialization

    init(
        clock: any ClockProtocol = SystemClock(),
        refreshInterval: TimeInterval,
        basePath: String = realHomeDirectory() + "/.claude"
    ) {
        self.clock = clock
        self.lastRefreshTime = clock.now

        let dayTracker = DayTracker(clock: clock)
        let monitoredPath = basePath + "/projects"

        directoryMonitor = DirectoryMonitor(
            path: monitoredPath,
            debounceInterval: Timing.debounceInterval
        ) { [weak self] in
            self?.triggerRefreshIfNeeded(reason: .fileChange)
        }

        fallbackTimer = FallbackTimer(interval: Timing.fallbackInterval) { [weak self] in
            self?.triggerRefresh(reason: .timer)
        }

        dayChangeMonitor = DayChangeMonitor(clock: clock, dayTracker: dayTracker) { [weak self] reason in
            self?.triggerRefresh(reason: reason)
        }

        wakeMonitor = WakeMonitor(clock: clock, dayTracker: dayTracker) { [weak self] reason in
            self?.triggerRefresh(reason: reason)
        }
    }

    // MARK: - Public API

    func start() {
        Task { await directoryMonitor?.start() }
        fallbackTimer?.start()
        dayChangeMonitor?.start()
        wakeMonitor?.start()
    }

    func handleAppBecameActive() {
        triggerRefreshIfNeeded(reason: .appBecameActive)
        start()
    }

    func handleAppResignActive() {
        fallbackTimer?.stop()
    }

    func handleWindowFocus() {
        triggerRefreshIfNeeded(reason: .windowFocus)
    }

    // MARK: - Refresh Logic

    private func triggerRefreshIfNeeded(reason: RefreshReason) {
        guard shouldRefresh() else { return }
        triggerRefresh(reason: reason)
    }

    private func triggerRefresh(reason: RefreshReason) {
        logger.info("Refresh triggered: \(String(describing: reason), privacy: .public)")
        lastRefreshTime = clock.now
        Task { await onRefresh?(reason) }
    }

    private func shouldRefresh() -> Bool {
        clock.now.timeIntervalSince(lastRefreshTime) > Timing.refreshThreshold
    }
}
