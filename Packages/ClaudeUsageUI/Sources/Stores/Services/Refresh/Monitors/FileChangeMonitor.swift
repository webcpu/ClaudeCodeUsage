//
//  FileChangeMonitor.swift
//  Adapter for DirectoryMonitor conforming to RefreshMonitor protocol
//

import Foundation
import ClaudeUsageData

@MainActor
final class FileChangeMonitor: RefreshMonitor {
    private var directoryMonitor: DirectoryMonitor?
    private let path: String
    private let debounceInterval: TimeInterval
    private let onRefresh: (RefreshReason) -> Void

    init(path: String, debounceInterval: TimeInterval, onRefresh: @escaping (RefreshReason) -> Void) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.onRefresh = onRefresh
    }

    func start() {
        stop()
        directoryMonitor = DirectoryMonitor(
            path: path,
            debounceInterval: debounceInterval
        ) { [weak self] in
            self?.onRefresh(.fileChange)
        }
        Task { await directoryMonitor?.start() }
    }

    func stop() {
        directoryMonitor = nil
    }
}
