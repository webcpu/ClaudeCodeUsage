//
//  TokenCounts.swift
//  ClaudeUsageCore
//
//  Unified token counts for all usage tracking
//

import Foundation

// MARK: - TokenCounts

public struct TokenCounts: Sendable, Hashable, Codable {
    public let input: Int
    public let output: Int
    public let cacheCreation: Int
    public let cacheRead: Int

    public var total: Int {
        input + output + cacheCreation + cacheRead
    }

    public init(
        input: Int = 0,
        output: Int = 0,
        cacheCreation: Int = 0,
        cacheRead: Int = 0
    ) {
        self.input = input
        self.output = output
        self.cacheCreation = cacheCreation
        self.cacheRead = cacheRead
    }
}

// MARK: - Arithmetic

public extension TokenCounts {
    static func + (lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
        TokenCounts(
            input: lhs.input + rhs.input,
            output: lhs.output + rhs.output,
            cacheCreation: lhs.cacheCreation + rhs.cacheCreation,
            cacheRead: lhs.cacheRead + rhs.cacheRead
        )
    }

    static var zero: TokenCounts {
        TokenCounts()
    }
}
