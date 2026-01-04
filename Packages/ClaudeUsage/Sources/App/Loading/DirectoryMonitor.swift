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

public actor DirectoryMonitor {
    private let path: String
    private let debounceInterval: TimeInterval
    private let onChange: @Sendable @MainActor () -> Void
    private let queue = DispatchQueue(label: "DirectoryMonitor", qos: .utility)

    private var stream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?

    public init(
        path: String,
        debounceInterval: TimeInterval = 1.0,
        onChange: @escaping @Sendable @MainActor () -> Void
    ) {
        self.path = path
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    // MARK: - Public API

    public func start() {
        guard stream == nil else { return }

        // Capture values needed in C callback (can't capture actor self directly)
        let debounceInterval = self.debounceInterval
        let onChange = self.onChange

        // Use a simple class wrapper for the C callback context
        final class CallbackContext: @unchecked Sendable {
            let debounceInterval: TimeInterval
            let onChange: @Sendable @MainActor () -> Void
            var debounceTask: Task<Void, Never>?
            let lock = NSLock()

            init(debounceInterval: TimeInterval, onChange: @escaping @Sendable @MainActor () -> Void) {
                self.debounceInterval = debounceInterval
                self.onChange = onChange
            }

            func handleEvent() {
                lock.lock()
                debounceTask?.cancel()
                debounceTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        try await Task.sleep(for: .seconds(self.debounceInterval))
                        guard !Task.isCancelled else { return }
                        self.onChange()
                    } catch {
                        // Task cancelled
                    }
                }
                lock.unlock()
            }
        }

        let context = CallbackContext(debounceInterval: debounceInterval, onChange: onChange)

        var fsContext = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(context).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<CallbackContext>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info else { return }
                Unmanaged<CallbackContext>.fromOpaque(info).release()
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
                let ctx = Unmanaged<CallbackContext>.fromOpaque(info).takeUnretainedValue()

                if let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String], numEvents > 0 {
                    let hasJSONLChanges = paths.contains { $0.hasSuffix(".jsonl") }
                    if hasJSONLChanges {
                        ctx.handleEvent()
                    }
                }
            },
            &fsContext,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.1,
            flags
        )

        guard let stream else {
            logger.error("Failed to create FSEventStream for \(self.path)")
            return
        }

        FSEventStreamSetDispatchQueue(stream, queue)
        if !FSEventStreamStart(stream) {
            logger.error("FSEventStreamStart failed for \(self.path, privacy: .public)")
        }
    }

    public func stop() {
        debounceTask?.cancel()
        debounceTask = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
    }
}
