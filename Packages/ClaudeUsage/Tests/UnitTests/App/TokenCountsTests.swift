//
//  TokenCountsTests.swift
//
//  Specification for TokenCounts - the fundamental token counting type.
//
//  This test suite fully specifies the TokenCounts struct.
//  Reading these tests tells you exactly how to implement TokenCounts.
//

import Testing
import Foundation
@testable import ClaudeUsage

// MARK: - TokenCounts Specification

/// TokenCounts is a value type that holds token counts for API usage.
/// It is Sendable, Hashable, and Codable.
@Suite("TokenCounts")
struct TokenCountsTests {

    // MARK: - Type Properties

    @Test("has four stored properties: input, output, cacheCreation, cacheRead")
    func storedProperties() {
        let tokens = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)

        #expect(tokens.input == 100)
        #expect(tokens.output == 50)
        #expect(tokens.cacheCreation == 25)
        #expect(tokens.cacheRead == 10)
    }

    @Test("all properties default to 0")
    func defaultValues() {
        let tokens = TokenCounts()

        #expect(tokens.input == 0)
        #expect(tokens.output == 0)
        #expect(tokens.cacheCreation == 0)
        #expect(tokens.cacheRead == 0)
    }

    @Test("accepts partial initialization with defaults")
    func partialInitialization() {
        let inputOnly = TokenCounts(input: 100)
        #expect(inputOnly.input == 100)
        #expect(inputOnly.output == 0)

        let inputOutput = TokenCounts(input: 100, output: 50)
        #expect(inputOutput.input == 100)
        #expect(inputOutput.output == 50)
        #expect(inputOutput.cacheCreation == 0)
    }

    // MARK: - Computed Property: total

    @Test("total equals sum of all four properties")
    func totalCalculation() {
        let tokens = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        #expect(tokens.total == 185)
    }

    @Test("total is 0 for zero tokens")
    func totalZero() {
        let tokens = TokenCounts()
        #expect(tokens.total == 0)
    }

    // MARK: - Static Property: zero

    @Test("zero returns TokenCounts with all properties at 0")
    func zeroProperty() {
        let zero = TokenCounts.zero

        #expect(zero.input == 0)
        #expect(zero.output == 0)
        #expect(zero.cacheCreation == 0)
        #expect(zero.cacheRead == 0)
        #expect(zero.total == 0)
    }

    // MARK: - Operator: +

    @Test("+ adds corresponding properties")
    func addition() {
        let a = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        let b = TokenCounts(input: 50, output: 25, cacheCreation: 10, cacheRead: 5)

        let sum = a + b

        #expect(sum.input == 150)
        #expect(sum.output == 75)
        #expect(sum.cacheCreation == 35)
        #expect(sum.cacheRead == 15)
    }

    @Test("zero is identity element for +")
    func additionIdentity() {
        let tokens = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)

        let sum = tokens + .zero

        #expect(sum == tokens)
    }

    @Test("+ is commutative: a + b == b + a")
    func additionCommutative() {
        let a = TokenCounts(input: 100, output: 50)
        let b = TokenCounts(input: 30, output: 20)

        #expect(a + b == b + a)
    }

    @Test("+ is associative: (a + b) + c == a + (b + c)")
    func additionAssociative() {
        let a = TokenCounts(input: 10, output: 5)
        let b = TokenCounts(input: 20, output: 10)
        let c = TokenCounts(input: 30, output: 15)

        #expect((a + b) + c == a + (b + c))
    }

    // MARK: - Protocol Conformance: Hashable

    @Test("is Hashable - equal values have equal hashes")
    func hashable() {
        let a = TokenCounts(input: 100, output: 50)
        let b = TokenCounts(input: 100, output: 50)

        #expect(a.hashValue == b.hashValue)
    }

    @Test("can be used as Dictionary key")
    func dictionaryKey() {
        let tokens = TokenCounts(input: 100, output: 50)
        var dict: [TokenCounts: String] = [:]

        dict[tokens] = "test"

        #expect(dict[tokens] == "test")
    }

    @Test("can be used in Set")
    func setMembership() {
        let a = TokenCounts(input: 100, output: 50)
        let b = TokenCounts(input: 100, output: 50)
        let c = TokenCounts(input: 200, output: 100)

        let set: Set<TokenCounts> = [a, b, c]

        #expect(set.count == 2) // a and b are equal
    }

    // MARK: - Protocol Conformance: Equatable

    @Test("is Equatable - compares all properties")
    func equatable() {
        let a = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        let b = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        let c = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 11)

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - Protocol Conformance: Codable

    @Test("is Codable - can encode to JSON")
    func encodable() throws {
        let tokens = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        let encoder = JSONEncoder()

        let data = try encoder.encode(tokens)
        let json = String(data: data, encoding: .utf8)

        #expect(json != nil)
        #expect(json!.contains("100"))
    }

    @Test("is Codable - can decode from JSON")
    func decodable() throws {
        let json = """
        {"input":100,"output":50,"cacheCreation":25,"cacheRead":10}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()

        let tokens = try decoder.decode(TokenCounts.self, from: data)

        #expect(tokens.input == 100)
        #expect(tokens.output == 50)
        #expect(tokens.cacheCreation == 25)
        #expect(tokens.cacheRead == 10)
    }

    @Test("is Codable - roundtrip preserves values")
    func codableRoundtrip() throws {
        let original = TokenCounts(input: 100, output: 50, cacheCreation: 25, cacheRead: 10)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TokenCounts.self, from: data)

        #expect(decoded == original)
    }
}
