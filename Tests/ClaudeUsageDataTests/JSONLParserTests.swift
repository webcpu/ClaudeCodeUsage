//
//  JSONLParserTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("JSONLParser")
struct JSONLParserTests {
    private let parser = JSONLParser()
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("parses valid entry with correct structure")
    func parsesValidEntryStructure() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)
        guard let file = files.first(where: { file in
            var hashes = Set<String>()
            return !parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes).isEmpty
        }) else {
            Issue.record("No files with entries found")
            return
        }

        var hashes = Set<String>()
        let entries = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
        let entry = try #require(entries.first)

        #expect(!entry.id.isEmpty)
        #expect(!entry.model.isEmpty)
        #expect(entry.tokens.total > 0)
        #expect(entry.costUSD >= 0)
        #expect(!entry.project.isEmpty)
        #expect(!entry.sourceFile.isEmpty)
    }

    @Test("deduplicates entries by hash")
    func deduplicatesEntriesByHash() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)
        guard let file = files.first else {
            Issue.record("No files to test")
            return
        }

        var hashes = Set<String>()
        let firstParse = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
        let hashCountAfterFirst = hashes.count

        // Parse same file again - should return empty (all duplicates)
        let secondParse = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)

        #expect(hashCountAfterFirst == hashes.count, "Hash set should not grow on second parse")
        #expect(secondParse.isEmpty, "Second parse should return no new entries")
        #expect(firstParse.count > 0 || hashes.isEmpty, "First parse should have entries or file was empty")
    }
}
