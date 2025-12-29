//
//  DirectoryMonitor.swift
//  ClaudeUsageData
//
//  File system monitoring for usage data changes
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "DirectoryMonitor")

// MARK: - DirectoryMonitor

public final class DirectoryMonitor: @unchecked Sendable {
    private let path: String
    private let debounceInterval: TimeInterval
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "DirectoryMonitor", qos: .utility)

    /// Called when directory contents change (debounced)
    public var onChange: (() -> Void)?

    public init(path: String, debounceInterval: TimeInterval = 1.0) {
        self.path = path
        self.debounceInterval = debounceInterval
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    public func start() {
        stop()

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.error("Failed to open \(self.path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .revoke],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.handleEvent()
        }

        source?.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        source?.resume()
        logger.debug("Started watching \(self.path)")
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        source?.cancel()
        source = nil
    }

    // MARK: - Private

    private func handleEvent() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .seconds(self.debounceInterval))
                guard !Task.isCancelled else { return }
                self.onChange?()
            } catch {
                // Task cancelled
            }
        }
    }
}
