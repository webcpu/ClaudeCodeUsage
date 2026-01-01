//
//  DirectoryMonitor.swift
//  ClaudeUsageData
//
//  File system monitoring for usage data changes using FSEvents (recursive)
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "DirectoryMonitor")

// MARK: - DirectoryMonitor

public final class DirectoryMonitor: @unchecked Sendable {
    private let path: String
    private let debounceInterval: TimeInterval
    private var stream: FSEventStreamRef?
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
        guard stream == nil else { return }  // Already running

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(self).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<DirectoryMonitor>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info else { return }
                Unmanaged<DirectoryMonitor>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

        let paths = [path] as CFArray
        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(info).takeUnretainedValue()

                if let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String], numEvents > 0 {
                    logger.debug("FSEvents: \(numEvents) event(s) received")
                    for (i, path) in paths.enumerated() {
                        let flags = eventFlags[i]
                        logger.debug("  [\(i)] \(path, privacy: .public) flags=\(flags)")
                    }

                    let jsonlPaths = paths.filter { $0.hasSuffix(".jsonl") }
                    if !jsonlPaths.isEmpty {
                        logger.info("JSONL change detected: \(jsonlPaths.count) file(s)")
                        monitor.handleEvent()
                    }
                }
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,  // Coalesce events within 100ms
            flags
        )

        guard let stream else {
            logger.error("Failed to create FSEventStream for \(self.path)")
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        let started = FSEventStreamStart(stream)
        if started {
            logger.info("Started watching \(self.path, privacy: .public) (recursive)")
        } else {
            logger.error("FSEventStreamStart failed for \(self.path, privacy: .public)")
        }
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        if let stream {
            logger.debug("Stopping FSEventStream")
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }

    // MARK: - Private

    private func handleEvent() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .seconds(self.debounceInterval))
                guard !Task.isCancelled else { return }
                logger.info("Triggering onChange callback")
                self.onChange?()
            } catch {
                // Task cancelled
            }
        }
    }
}
