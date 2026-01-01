//
//  DirectoryMonitorTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsageData

@Suite("DirectoryMonitor")
struct DirectoryMonitorTests {

    @Test("detects file creation in monitored directory")
    func detectsFileCreation() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1)
        let eventReceived = Mutex(false)

        monitor.onChange = {
            eventReceived.withLock { $0 = true }
        }

        monitor.start()

        // Wait for FSEvents to initialize
        try await Task.sleep(for: .milliseconds(100))

        // Create a .jsonl file to trigger event
        let testFile = tempDir + "/test.jsonl"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        // Wait for debounce + processing
        try await Task.sleep(for: .milliseconds(500))

        monitor.stop()

        let received = eventReceived.withLock { $0 }
        #expect(received, "onChange should be called when .jsonl file is created")
    }

    @Test("detects file modification in subdirectory")
    func detectsFileModificationInSubdirectory() async throws {
        let tempDir = createTempDirectory()
        let subDir = tempDir + "/subdir"
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        defer { cleanup(tempDir) }

        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1)
        let eventReceived = Mutex(false)

        monitor.onChange = {
            eventReceived.withLock { $0 = true }
        }

        monitor.start()

        // Wait for FSEvents to initialize
        try await Task.sleep(for: .milliseconds(100))

        // Create a .jsonl file in subdirectory
        let testFile = subDir + "/conversation.jsonl"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        // Wait for debounce + processing
        try await Task.sleep(for: .milliseconds(500))

        monitor.stop()

        let received = eventReceived.withLock { $0 }
        #expect(received, "onChange should be called when .jsonl file is created in subdirectory")
    }

    @Test("ignores non-jsonl files")
    func ignoresNonJsonlFiles() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1)
        let eventReceived = Mutex(false)

        monitor.onChange = {
            eventReceived.withLock { $0 = true }
        }

        monitor.start()

        // Wait for FSEvents to initialize
        try await Task.sleep(for: .milliseconds(100))

        // Create a non-.jsonl file
        let testFile = tempDir + "/test.txt"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        // Wait for debounce + processing
        try await Task.sleep(for: .milliseconds(500))

        monitor.stop()

        let received = eventReceived.withLock { $0 }
        #expect(!received, "onChange should NOT be called for non-.jsonl files")
    }

    @Test("debounces rapid file changes")
    func debouncesRapidFileChanges() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.2)
        let callCount = Mutex(0)

        monitor.onChange = {
            callCount.withLock { $0 += 1 }
        }

        monitor.start()

        // Wait for FSEvents to initialize
        try await Task.sleep(for: .milliseconds(100))

        // Create multiple files rapidly
        for i in 0..<5 {
            let testFile = tempDir + "/test\(i).jsonl"
            FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))
            try await Task.sleep(for: .milliseconds(50))
        }

        // Wait for debounce to settle
        try await Task.sleep(for: .milliseconds(500))

        monitor.stop()

        let count = callCount.withLock { $0 }
        #expect(count >= 1 && count <= 2, "Should debounce rapid changes (got \(count) calls)")
    }

    // MARK: - Helpers

    private func createTempDirectory() -> String {
        let tempDir = NSTemporaryDirectory() + "DirectoryMonitorTest-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}

// Thread-safe wrapper for test state
private final class Mutex<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
