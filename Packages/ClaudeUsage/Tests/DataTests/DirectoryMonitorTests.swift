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
    @MainActor
    func detectsFileCreation() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        var eventReceived = false
        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1) {
            eventReceived = true
        }

        await monitor.start()
        try await Task.sleep(for: .milliseconds(100))

        let testFile = tempDir + "/test.jsonl"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        try await Task.sleep(for: .milliseconds(500))
        await monitor.stop()

        #expect(eventReceived, "onChange should be called when .jsonl file is created")
    }

    @Test("detects file modification in subdirectory")
    @MainActor
    func detectsFileModificationInSubdirectory() async throws {
        let tempDir = createTempDirectory()
        let subDir = tempDir + "/subdir"
        try FileManager.default.createDirectory(atPath: subDir, withIntermediateDirectories: true)
        defer { cleanup(tempDir) }

        var eventReceived = false
        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1) {
            eventReceived = true
        }

        await monitor.start()
        try await Task.sleep(for: .milliseconds(100))

        let testFile = subDir + "/conversation.jsonl"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        try await Task.sleep(for: .milliseconds(500))
        await monitor.stop()

        #expect(eventReceived, "onChange should be called when .jsonl file is created in subdirectory")
    }

    @Test("ignores non-jsonl files")
    @MainActor
    func ignoresNonJsonlFiles() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        var eventReceived = false
        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.1) {
            eventReceived = true
        }

        await monitor.start()
        try await Task.sleep(for: .milliseconds(100))

        let testFile = tempDir + "/test.txt"
        FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))

        try await Task.sleep(for: .milliseconds(500))
        await monitor.stop()

        #expect(!eventReceived, "onChange should NOT be called for non-.jsonl files")
    }

    @Test("debounces rapid file changes")
    @MainActor
    func debouncesRapidFileChanges() async throws {
        let tempDir = createTempDirectory()
        defer { cleanup(tempDir) }

        var callCount = 0
        let monitor = DirectoryMonitor(path: tempDir, debounceInterval: 0.2) {
            callCount += 1
        }

        await monitor.start()
        try await Task.sleep(for: .milliseconds(100))

        for i in 0..<5 {
            let testFile = tempDir + "/test\(i).jsonl"
            FileManager.default.createFile(atPath: testFile, contents: Data("test".utf8))
            try await Task.sleep(for: .milliseconds(50))
        }

        try await Task.sleep(for: .milliseconds(500))
        await monitor.stop()

        #expect(callCount >= 1 && callCount <= 2, "Should debounce rapid changes (got \(callCount) calls)")
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
