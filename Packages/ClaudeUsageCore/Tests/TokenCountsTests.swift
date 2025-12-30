//
//  TokenCountsTests.swift
//  ClaudeUsageCoreTests
//

import Testing
@testable import ClaudeUsageCore

@Suite("TokenCounts")
struct TokenCountsTests {
    @Test("calculates total correctly")
    func totalCalculation() {
        let tokens = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        #expect(tokens.total == 185)
    }

    @Test("addition works correctly")
    func addition() {
        let a = TokenCounts(input: 100, output: 50)
        let b = TokenCounts(input: 50, output: 25)
        let sum = a + b
        #expect(sum.input == 150)
        #expect(sum.output == 75)
    }

    @Test("zero is identity for addition")
    func zeroIdentity() {
        let tokens = TokenCounts(input: 100, output: 50)
        let sum = tokens + .zero
        #expect(sum == tokens)
    }
}
