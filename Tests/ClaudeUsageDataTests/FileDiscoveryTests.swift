//
//  FileDiscoveryTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsageData

@Suite("FileDiscovery")
struct FileDiscoveryTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("discovers all JSONL files")
    func discoversAllFiles() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)

        #expect(files.count > 0, "Should find JSONL files")
        print("Total files discovered: \(files.count)")

        // Verify file structure
        for file in files.prefix(5) {
            #expect(file.path.hasSuffix(".jsonl"))
            #expect(!file.projectName.isEmpty)
        }
    }

    @Test("filters files modified today")
    func filtersFilesModifiedToday() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filterFilesModifiedToday(allFiles)

        print("Files today: \(todayFiles.count) / \(allFiles.count) total")
        #expect(todayFiles.count <= allFiles.count)

        // Verify all filtered files are from today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        for file in todayFiles {
            let fileDay = calendar.startOfDay(for: file.modificationDate)
            #expect(fileDay >= today)
        }
    }

    @Test("measures discovery performance")
    func measuresDiscoveryPerformance() throws {
        let iterations = 5
        var times: [TimeInterval] = []

        for _ in 0..<iterations {
            let start = Date()
            _ = try FileDiscovery.discoverFiles(in: basePath)
            times.append(Date().timeIntervalSince(start))
        }

        let average = times.reduce(0, +) / Double(iterations)
        let min = times.min() ?? 0
        let max = times.max() ?? 0

        print("Discovery performance (\(iterations) runs):")
        print("  Average: \(String(format: "%.3f", average))s")
        print("  Min: \(String(format: "%.3f", min))s")
        print("  Max: \(String(format: "%.3f", max))s")

        #expect(average < 1.0, "File discovery should be under 1 second")
    }
}
