//
//  FallbackTimer.swift
//  Periodic fallback refresh timer
//

import Foundation

@MainActor
final class FallbackTimer {
    private var task: Task<Void, Never>?
    private let interval: TimeInterval
    private let onTick: () -> Void

    init(interval: TimeInterval, onTick: @escaping () -> Void) {
        self.interval = interval
        self.onTick = onTick
    }

    func start() {
        task = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                    guard !Task.isCancelled else { break }
                    onTick()
                } catch {
                    break
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
