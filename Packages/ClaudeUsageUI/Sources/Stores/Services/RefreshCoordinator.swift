//
//  RefreshCoordinator.swift
//  Manages refresh via file monitoring, lifecycle events, and day change detection
//

import Foundation
import AppKit
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

// MARK: - Refresh Reason

enum RefreshReason: Sendable {
    case manual
    case fileChange
    case dayChange
    case timer
    case appBecameActive
    case windowFocus

    var shouldInvalidateCache: Bool {
        switch self {
        case .timer:
            false
        case .manual, .fileChange, .dayChange, .appBecameActive, .windowFocus:
            true
        }
    }
}

// MARK: - Refresh Coordinator

@MainActor
final class RefreshCoordinator {
    private var fallbackTimerTask: Task<Void, Never>?
    private var dayChangeObserver: NSObjectProtocol?
    private var clockChangeObserver: NSObjectProtocol?
    private var lastKnownDay: String
    private var lastRefreshTime: Date
    private let clock: any ClockProtocol
    private let monitoredPath: String

    private var directoryMonitor: DirectoryMonitor?

    var onRefresh: ((RefreshReason) async -> Void)?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Initialization

    init(
        clock: any ClockProtocol = SystemClock(),
        refreshInterval: TimeInterval,
        basePath: String = realHomeDirectory() + "/.claude"
    ) {
        self.clock = clock
        self.lastRefreshTime = clock.now
        self.lastKnownDay = Self.formatDay(clock.now)
        self.monitoredPath = basePath + "/projects"
    }

    // MARK: - Public API

    func start() {
        if directoryMonitor == nil {
            directoryMonitor = DirectoryMonitor(
                path: monitoredPath,
                debounceInterval: Timing.debounceInterval
            ) { [weak self] in
                self?.triggerRefreshIfNeeded(reason: .fileChange)
            }
        }
        Task { await directoryMonitor?.start() }
        startFallbackTimer()
        startDayChangeMonitoring()
    }

    func stop() {
        Task { await directoryMonitor?.stop() }
        stopFallbackTimer()
        stopDayChangeMonitoring()
    }

    func handleAppBecameActive() {
        triggerRefreshIfNeeded(reason: .appBecameActive)
        start()
    }

    func handleAppResignActive() {
        pauseActiveRefreshingButKeepPassiveMonitoring()
    }

    // MARK: - Pause Logic

    /// Pauses the active polling timer while keeping passive monitors running.
    ///
    /// Only pause the timer. Keep monitoring file changes and day changes—
    /// they're passive and menu bar apps lose focus constantly.
    private func pauseActiveRefreshingButKeepPassiveMonitoring() {
        stopFallbackTimer()
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

    // MARK: - Fallback Timer

    private func startFallbackTimer() {
        fallbackTimerTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Timing.fallbackInterval))
                    guard !Task.isCancelled else { break }
                    triggerRefresh(reason: .timer)
                } catch {
                    break
                }
            }
        }
    }

    private func stopFallbackTimer() {
        fallbackTimerTask?.cancel()
        fallbackTimerTask = nil
    }

    // MARK: - Day Change Monitoring

    private func startDayChangeMonitoring() {
        stopDayChangeMonitoring()
        observeCalendarDayChange()
        observeSystemClockChange()
    }

    private func stopDayChangeMonitoring() {
        dayChangeObserver.map { NotificationCenter.default.removeObserver($0) }
        dayChangeObserver = nil
        clockChangeObserver.map { NotificationCenter.default.removeObserver($0) }
        clockChangeObserver = nil
    }

    private func observeCalendarDayChange() {
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleDayChange()
            }
        }
    }

    private func observeSystemClockChange() {
        clockChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSystemClockChange()
            }
        }
    }

    private func handleDayChange() {
        lastKnownDay = Self.formatDay(clock.now)
        triggerRefresh(reason: .dayChange)
    }

    private func handleSystemClockChange() {
        let currentDay = Self.formatDay(clock.now)
        guard currentDay != lastKnownDay else { return }
        lastKnownDay = currentDay
        triggerRefresh(reason: .dayChange)
    }

    // MARK: - Pure Functions

    private static func formatDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
