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

    @Test("discovers JSONL files with valid structure")
    func discoversValidFiles() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)

        #expect(files.count > 0, "Should find JSONL files")

        for file in files.prefix(5) {
            #expect(file.path.hasSuffix(".jsonl"))
            #expect(!file.projectName.isEmpty)
        }
    }

    @Test("filters files modified today correctly")
    func filtersFilesModifiedToday() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filterFilesModifiedToday(allFiles)

        #expect(todayFiles.count <= allFiles.count)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for file in todayFiles {
            let fileDay = calendar.startOfDay(for: file.modificationDate)
            #expect(fileDay >= today, "Filtered file should be from today")
        }
    }
}
