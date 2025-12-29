//
//  UsageStats+Compatibility.swift
//  ClaudeUsageCore
//
//  Compatibility extensions for Kit API parity
//

import Foundation

// MARK: - UsageStats Kit Compatibility

public extension UsageStats {
    /// Kit-compatible individual token accessors
    var totalInputTokens: Int { tokens.input }
    var totalOutputTokens: Int { tokens.output }
    var totalCacheCreationTokens: Int { tokens.cacheCreation }
    var totalCacheReadTokens: Int { tokens.cacheRead }

    /// Kit-compatible session count accessor
    var totalSessions: Int { sessionCount }

    /// Kit-compatible initializer with individual token fields
    init(
        totalCost: Double,
        totalTokens: Int,
        totalInputTokens: Int,
        totalOutputTokens: Int,
        totalCacheCreationTokens: Int,
        totalCacheReadTokens: Int,
        totalSessions: Int,
        byModel: [ModelUsage],
        byDate: [DailyUsage],
        byProject: [ProjectUsage]
    ) {
        self.init(
            totalCost: totalCost,
            tokens: TokenCounts(
                input: totalInputTokens,
                output: totalOutputTokens,
                cacheCreation: totalCacheCreationTokens,
                cacheRead: totalCacheReadTokens
            ),
            sessionCount: totalSessions,
            byModel: byModel,
            byDate: byDate,
            byProject: byProject
        )
    }
}

// MARK: - ModelUsage Kit Compatibility

public extension ModelUsage {
    /// Kit-compatible individual token accessors
    var inputTokens: Int { tokens.input }
    var outputTokens: Int { tokens.output }
    var cacheCreationTokens: Int { tokens.cacheCreation }
    var cacheReadTokens: Int { tokens.cacheRead }
    var totalTokens: Int { tokens.total }
}

// MARK: - DailyUsage Kit Compatibility

public extension DailyUsage {
    /// Number of different models used (Kit compatibility)
    var modelCount: Int { modelsUsed.count }
}
