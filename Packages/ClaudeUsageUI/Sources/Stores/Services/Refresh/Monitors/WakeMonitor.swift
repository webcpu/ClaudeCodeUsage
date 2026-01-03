//
//  WakeMonitor.swift
//  Monitors system wake from sleep events
//

import Foundation
import AppKit

@MainActor
final class WakeMonitor: RefreshMonitor {
    private var observer: NSObjectProtocol?
    private var dayTracker: DayTracker
    private let clock: any ClockProtocol
    private let onRefresh: (RefreshReason) -> Void

    init(clock: any ClockProtocol, dayTracker: DayTracker, onRefresh: @escaping (RefreshReason) -> Void) {
        self.clock = clock
        self.dayTracker = dayTracker
        self.onRefresh = onRefresh
    }

    func start() {
        stop()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                onRefresh(dayTracker.refreshReasonForWake(clock: clock))
            }
        }
    }

    func stop() {
        observer.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observer = nil
    }
}
