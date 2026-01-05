//
//  FileDiscoveryTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("FileDiscovery")
struct FileDiscoveryTests {
    private let basePath = AppConfiguration.default.basePath

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
        let todayFiles = FileDiscovery.filter(allFiles, by: FileFilters.modifiedToday())

        #expect(todayFiles.count <= allFiles.count)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for file in todayFiles {
            let fileDay = calendar.startOfDay(for: file.modificationDate)
            #expect(fileDay >= today, "Filtered file should be from today")
        }
    }

    @Test("filters compose with AND logic")
    func filtersComposeWithAnd() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)

        // Combine modifiedToday AND modifiedWithin(hours: 1)
        let composedFilter = FileFilters.all(
            FileFilters.modifiedToday(),
            FileFilters.modifiedWithin(hours: 1)
        )
        let recentTodayFiles = FileDiscovery.filter(allFiles, by: composedFilter)

        // Files matching composed filter should be subset of today's files
        let todayFiles = FileDiscovery.filter(allFiles, by: FileFilters.modifiedToday())
        #expect(recentTodayFiles.count <= todayFiles.count)
    }

    @Test("filters compose with OR logic")
    func filtersComposeWithOr() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)

        // Either modified today OR modified within last 48 hours
        let composedFilter = FileFilters.any(
            FileFilters.modifiedToday(),
            FileFilters.modifiedWithin(hours: 48)
        )
        let result = FileDiscovery.filter(allFiles, by: composedFilter)

        // Result should include all of today's files
        let todayFiles = FileDiscovery.filter(allFiles, by: FileFilters.modifiedToday())
        for todayFile in todayFiles {
            #expect(result.contains(todayFile), "OR filter should include today's files")
        }
    }

    @Test("not filter inverts predicate")
    func notFilterInverts() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filter(allFiles, by: FileFilters.modifiedToday())
        let notTodayFiles = FileDiscovery.filter(allFiles, by: FileFilters.not(FileFilters.modifiedToday()))

        #expect(todayFiles.count + notTodayFiles.count == allFiles.count)
    }
}
