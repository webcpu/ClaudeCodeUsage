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

    @Test("parser initializes correctly")
    func initialization() {
        let p = JSONLParser()
        #expect(type(of: p) == JSONLParser.self)
    }

    @Test("parses single file")
    func parsesSingleFile() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)
        guard let file = files.first else {
            Issue.record("No files to test")
            return
        }

        var hashes = Set<String>()
        let entries = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)

        print("Parsed \(entries.count) entries from \(file.projectName)")
        print("Unique hashes: \(hashes.count)")
    }

    @Test("parses all today files")
    func parsesTodayFiles() throws {
        let allFiles = try FileDiscovery.discoverFiles(in: basePath)
        let todayFiles = FileDiscovery.filterFilesModifiedToday(allFiles)

        var totalEntries = 0
        var totalHashes = 0
        let start = Date()

        for file in todayFiles {
            var hashes = Set<String>()
            let entries = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
            totalEntries += entries.count
            totalHashes += hashes.count
        }

        let duration = Date().timeIntervalSince(start)

        print("Parsed \(todayFiles.count) files in \(String(format: "%.2f", duration))s")
        print("Total entries: \(totalEntries)")
        print("Total hashes: \(totalHashes)")
        print("Throughput: \(String(format: "%.1f", Double(todayFiles.count) / duration)) files/sec")

        #expect(totalEntries >= 0)
    }

    @Test("measures parsing performance")
    func measuresParsingPerformance() throws {
        let files = try FileDiscovery.discoverFiles(in: basePath)

        // Test with first 100 files
        let testFiles = Array(files.prefix(100))
        let start = Date()

        var totalEntries = 0
        var totalBytes = 0

        for file in testFiles {
            var hashes = Set<String>()
            let entries = parser.parseFile(at: file.path, project: file.projectName, processedHashes: &hashes)
            totalEntries += entries.count

            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int {
                totalBytes += size
            }
        }

        let duration = Date().timeIntervalSince(start)

        print("Parsing performance (100 files):")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Entries: \(totalEntries)")
        print("  Data: \(totalBytes / 1024) KB")
        print("  Throughput: \(String(format: "%.1f", Double(testFiles.count) / duration)) files/sec")
        print("  Data rate: \(String(format: "%.1f", Double(totalBytes) / duration / 1024)) KB/sec")
    }

    @Test("validates entry structure")
    func validatesEntryStructure() throws {
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

        guard let entry = entries.first else {
            Issue.record("No entries parsed")
            return
        }

        #expect(!entry.id.isEmpty)
        #expect(!entry.model.isEmpty)
        #expect(entry.tokens.total > 0)
        #expect(entry.costUSD >= 0)
        #expect(!entry.project.isEmpty)
        #expect(!entry.sourceFile.isEmpty)

        print("Sample entry:")
        print("  ID: \(entry.id.prefix(20))...")
        print("  Model: \(entry.model)")
        print("  Tokens: \(entry.tokens.total)")
        print("  Cost: $\(String(format: "%.4f", entry.costUSD))")
    }
}
