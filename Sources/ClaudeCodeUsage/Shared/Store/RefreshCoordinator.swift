//
//  RefreshCoordinator.swift
//  Manages refresh timing, lifecycle events, and day change detection
//

import Foundation
import AppKit

// MARK: - Refresh Coordinator

@MainActor
final class RefreshCoordinator {
    private var timerTask: Task<Void, Never>?
    private var dayChangeObserver: NSObjectProtocol?
    private var lastKnownDay: String
    private var lastRefreshTime: Date
    private let clock: any ClockProtocol
    private let refreshInterval: TimeInterval

    /// Callback for refresh - set after init to avoid capturing self before initialization
    var onRefresh: (() async -> Void)?

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        clock: any ClockProtocol = SystemClock(),
        refreshInterval: TimeInterval
    ) {
        self.clock = clock
        self.refreshInterval = refreshInterval
        self.lastRefreshTime = clock.now
        self.lastKnownDay = Self.dayFormatter.string(from: clock.now)
    }

    // MARK: - Timer Management

    func start() {
        stop()

        timerTask = Task { @MainActor in
            var nextFireTime = ContinuousClock.now + .seconds(refreshInterval)

            while !Task.isCancelled {
                do {
                    try await Task.sleep(until: nextFireTime, clock: .continuous)
                    guard !Task.isCancelled else { break }
                    await onRefresh?()
                    nextFireTime = nextFireTime + .seconds(refreshInterval)
                } catch {
                    break
                }
            }
        }

        startDayChangeMonitoring()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        stopDayChangeMonitoring()
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
                await onRefresh?()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
