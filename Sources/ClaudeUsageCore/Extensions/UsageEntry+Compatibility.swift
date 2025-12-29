//
//  UsageEntry+Compatibility.swift
//  ClaudeUsageCore
//
//  Compatibility extensions for Kit API parity
//  Allows views to use familiar property names during migration
//

import Foundation

// MARK: - Kit API Compatibility

public extension UsageEntry {
    /// Kit-compatible cost property
    var cost: Double { costUSD }

    /// Kit-compatible date property (returns optional for API parity)
    var date: Date? { timestamp }

    /// Kit-compatible individual token accessors
    var inputTokens: Int { tokens.input }
    var outputTokens: Int { tokens.output }
    var cacheWriteTokens: Int { tokens.cacheCreation }
    var cacheReadTokens: Int { tokens.cacheRead }
}
