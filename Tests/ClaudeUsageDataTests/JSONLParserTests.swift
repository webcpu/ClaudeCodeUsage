//
//  JSONLParserTests.swift
//  ClaudeUsageDataTests
//

import Testing
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("JSONLParser")
struct JSONLParserTests {
    @Test("parser initializes correctly")
    func initialization() {
        let parser = JSONLParser()
        #expect(parser != nil)
    }
}
