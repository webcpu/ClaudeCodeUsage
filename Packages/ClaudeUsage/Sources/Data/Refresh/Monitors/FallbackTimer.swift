//
//  FallbackTimer.swift
//  Periodic fallback refresh timer
//

import Foundation
import ClaudeUsageCore

@MainActor
public final class FallbackTimer: RefreshMonitor {
    private var task: Task<Void, Never>?
    private let interval: TimeInterval
    private let onRefresh: (RefreshReason) -> Void

    public init(interval: TimeInterval, onRefresh: @escaping (RefreshReason) -> Void) {
        self.interval = interval
        self.onRefresh = onRefresh
    }

    public func start() {
        stop()
        task = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }
                    onRefresh(.timer)
                } catch {
                    break
                }
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
