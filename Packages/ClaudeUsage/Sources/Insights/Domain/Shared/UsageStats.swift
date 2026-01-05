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
    public let byProject: [ProjectUsage]

    public init(
        totalCost: Double,
        tokens: TokenCounts,
        sessionCount: Int,
        byModel: [ModelUsage] = [],
        byDate: [DailyUsage] = [],
        byProject: [ProjectUsage] = []
    ) {
        self.totalCost = totalCost
        self.tokens = tokens
        self.sessionCount = sessionCount
        self.byModel = byModel
        self.byDate = byDate
        self.byProject = byProject
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

// MARK: - ProjectUsage

public struct ProjectUsage: Sendable, Hashable, Identifiable {
    public let projectPath: String
    public let projectName: String
    public let totalCost: Double
    public let totalTokens: Int
    public let sessionCount: Int
    public let lastUsed: Date

    public var id: String { projectPath }

    public init(
        projectPath: String,
        projectName: String,
        totalCost: Double,
        totalTokens: Int,
        sessionCount: Int,
        lastUsed: Date
    ) {
        self.projectPath = projectPath
        self.projectName = projectName
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.sessionCount = sessionCount
        self.lastUsed = lastUsed
    }

    public var averageCostPerSession: Double {
        sessionCount > 0 ? totalCost / Double(sessionCount) : 0
    }
}
