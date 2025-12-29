//
//  RefreshCoordinator.swift
//  Manages refresh via file monitoring, lifecycle events, and day change detection
//

import Foundation
import AppKit

// MARK: - Refresh Coordinator

@MainActor
final class RefreshCoordinator {
    private var fallbackTimerTask: Task<Void, Never>?
    private var dayChangeObserver: NSObjectProtocol?
    private var lastKnownDay: String
    private var lastRefreshTime: Date
    private let clock: any ClockProtocol
    private let monitoredPath: String
    private let directoryMonitor: DirectoryMonitor

    /// Fallback interval when file monitoring might miss changes (5 minutes)
    private let fallbackInterval: TimeInterval = 300.0

    /// Callback for refresh - set after init to avoid capturing self before initialization
    var onRefresh: (() async -> Void)?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        clock: any ClockProtocol = SystemClock(),
        refreshInterval: TimeInterval,
        basePath: String = NSHomeDirectory() + "/.claude"
    ) {
        self.clock = clock
        self.lastRefreshTime = clock.now
        self.lastKnownDay = Self.dayFormatter.string(from: clock.now)
        self.monitoredPath = basePath + "/projects"
        self.directoryMonitor = DirectoryMonitor(path: monitoredPath, debounceInterval: 1.0)

        setupDirectoryMonitor()
    }

    private func setupDirectoryMonitor() {
        directoryMonitor.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleFileChange()
            }
        }
    }

    // MARK: - Monitoring Management

    func start() {
        stop()
        directoryMonitor.start()
        startFallbackTimer()
        startDayChangeMonitoring()
    }

    func stop() {
        directoryMonitor.stop()
        fallbackTimerTask?.cancel()
        fallbackTimerTask = nil
        stopDayChangeMonitoring()
    }

    private func startFallbackTimer() {
        fallbackTimerTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(fallbackInterval))
                    guard !Task.isCancelled else { break }
                    lastRefreshTime = clock.now
                    await onRefresh?()
                } catch {
                    break
                }
            }
        }
    }

    // MARK: - File Change Handling

    private func handleFileChange() {
        guard shouldRefresh() else { return }
        lastRefreshTime = clock.now
        Task { await onRefresh?() }
    }

    // MARK: - Lifecycle Events

    func handleAppBecameActive() {
        if shouldRefresh() {
            lastRefreshTime = clock.now
            Task { await onRefresh?() }
        }
        start()
    }

    func handleAppResignActive() {
        stop()
    }

    func handleWindowFocus() {
        if shouldRefresh() {
            lastRefreshTime = clock.now
            Task { await onRefresh?() }
        }
    }

    // MARK: - Private

    private func shouldRefresh() -> Bool {
        clock.now.timeIntervalSince(lastRefreshTime) > 2.0
    }

    private func startDayChangeMonitoring() {
        stopDayChangeMonitoring()

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateLastKnownDay()
                self.lastRefreshTime = self.clock.now
                await self.onRefresh?()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignificantTimeChange),
            name: NSNotification.Name.NSSystemClockDidChange,
            object: nil
        )
    }

    private func stopDayChangeMonitoring() {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            dayChangeObserver = nil
        }
    }

    private func updateLastKnownDay() {
        lastKnownDay = Self.dayFormatter.string(from: clock.now)
    }

    @objc private func handleSignificantTimeChange() {
        Task { @MainActor in
            let currentDay = Self.dayFormatter.string(from: clock.now)

            if currentDay != lastKnownDay {
                lastKnownDay = currentDay
                lastRefreshTime = clock.now
                await onRefresh?()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
