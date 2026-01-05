//
//  JSONLParserTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("JSONLParser")
struct JSONLParserTests {
    private let parser = JSONLParser()
    private let basePath = AppConfiguration.default.basePath

    // MARK: - Tests

    @Test("parses valid entry with correct structure")
    func parsesValidEntryStructure() throws {
        guard let file = try findFileWithEntries() else {
            Issue.record("No files with entries found")
            return
        }

        let entry = try #require(parseEntries(from: file).first)
        assertEntryHasValidStructure(entry)
    }

    @Test("deduplicates entries by hash")
    func deduplicatesEntriesByHash() throws {
        guard let file = try discoverFirstFile() else {
            Issue.record("No files to test")
            return
        }

        var hashes = Set<String>()
        let firstParse = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
        let hashCountAfterFirst = hashes.count
        let secondParse = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)

        assertDeduplicationWorks(
            hashCountAfterFirst: hashCountAfterFirst,
            hashCountAfterSecond: hashes.count,
            firstParseCount: firstParse.count,
            secondParseCount: secondParse.count
        )
    }

    // MARK: - Pure Helpers

    private func discoverFirstFile() throws -> FileMetadata? {
        try FileDiscovery.discoverFiles(in: basePath).first
    }

    private func findFileWithEntries() throws -> FileMetadata? {
        try FileDiscovery.discoverFiles(in: basePath).first { fileHasEntries($0) }
    }

    private func fileHasEntries(_ file: FileMetadata) -> Bool {
        !parseEntries(from: file).isEmpty
    }

    private func parseEntries(from file: FileMetadata) -> [UsageEntry] {
        var hashes = Set<String>()
        return parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
    }

    // MARK: - Assertion Helpers

    private func assertEntryHasValidStructure(_ entry: UsageEntry) {
        #expect(!entry.id.isEmpty)
        #expect(!entry.model.isEmpty)
        #expect(entry.tokens.total > 0)
        #expect(entry.costUSD >= 0)
        #expect(!entry.project.isEmpty)
        #expect(!entry.sourceFile.isEmpty)
    }

    private func assertDeduplicationWorks(
        hashCountAfterFirst: Int,
        hashCountAfterSecond: Int,
        firstParseCount: Int,
        secondParseCount: Int
    ) {
        #expect(hashCountAfterFirst == hashCountAfterSecond, "Hash set should not grow on second parse")
        #expect(secondParseCount == 0, "Second parse should return no new entries")
        #expect(firstParseCount > 0 || hashCountAfterFirst == 0, "First parse should have entries or file was empty")
    }
}
