//
//  ModelUsage.swift
//  ClaudeUsageCore
//

import Foundation

// MARK: - ModelUsage

public struct ModelUsage: Sendable, Hashable, Identifiable {
    public let model: String
    public let totalCost: Double
    public let tokens: TokenCounts
    public let sessionCount: Int

    public var id: String { model }

    public init(
        model: String,
        totalCost: Double,
        tokens: TokenCounts,
        sessionCount: Int
    ) {
        self.model = model
        self.totalCost = totalCost
        self.tokens = tokens
        self.sessionCount = sessionCount
    }

    public var averageCostPerSession: Double {
        sessionCount > 0 ? totalCost / Double(sessionCount) : 0
    }
}
