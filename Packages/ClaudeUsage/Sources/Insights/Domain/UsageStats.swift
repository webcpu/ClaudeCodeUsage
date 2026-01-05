//
//  UsageStats.swift
//  ClaudeUsageCore
//
//  Aggregated usage statistics
//

import Foundation

// MARK: - UsageStats

public struct UsageStats: Sendable, Hashable {
    public let totalCost: Double
    public let tokens: TokenCounts
    public let sessionCount: Int
    public let byModel: [ModelUsage]
    public let byDate: [DailyUsage]

    public init(
        totalCost: Double,
        tokens: TokenCounts,
        sessionCount: Int,
        byModel: [ModelUsage] = [],
        byDate: [DailyUsage] = []
    ) {
        self.totalCost = totalCost
        self.tokens = tokens
        self.sessionCount = sessionCount
        self.byModel = byModel
        self.byDate = byDate
    }

    public static var empty: UsageStats {
        UsageStats(totalCost: 0, tokens: .zero, sessionCount: 0)
    }
}

// MARK: - Derived Properties

public extension UsageStats {
    var totalTokens: Int { tokens.total }

    var averageCostPerSession: Double {
        sessionCount > 0 ? totalCost / Double(sessionCount) : 0
    }

    var averageTokensPerSession: Int {
        sessionCount > 0 ? totalTokens / sessionCount : 0
    }

    var costPerMillionTokens: Double {
        totalTokens > 0 ? (totalCost / Double(totalTokens)) * 1_000_000 : 0
    }
}
