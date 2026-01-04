//
//  DayChangeMonitor.swift
//  Monitors calendar day changes and system clock adjustments
//

import Foundation

@MainActor
public final class DayChangeMonitor: RefreshMonitor {
    private var dayChangeObserver: NSObjectProtocol?
    private var clockChangeObserver: NSObjectProtocol?
    private var dayTracker: DayTracker
    private let clock: any ClockProtocol
    private let onRefresh: (RefreshReason) -> Void

    public init(clock: any ClockProtocol, dayTracker: DayTracker, onRefresh: @escaping (RefreshReason) -> Void) {
        self.clock = clock
        self.dayTracker = dayTracker
        self.onRefresh = onRefresh
    }

    public func start() {
        stop()
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                onRefresh(dayTracker.refreshReasonForDayChange(clock: clock))
            }
        }
        clockChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let reason = dayTracker.refreshReasonForClockChange(clock: clock) else { return }
                onRefresh(reason)
            }
        }
    }

    public func stop() {
        dayChangeObserver.map { NotificationCenter.default.removeObserver($0) }
        dayChangeObserver = nil
        clockChangeObserver.map { NotificationCenter.default.removeObserver($0) }
        clockChangeObserver = nil
    }
}
