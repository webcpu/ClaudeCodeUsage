//
//  Models.swift
//
//  Core data models for ClaudeLiveMonitor.
//  Split into extensions for focused responsibilities:
//    - +Pricing: Model pricing configurations and cost calculations
//

import Foundation

// MARK: - TokenCounts

public struct TokenCounts: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheReadInputTokens: Int

    public var total: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }

    public init(
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        cacheCreationInputTokens: Int = 0,
        cacheReadInputTokens: Int = 0
    ) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
    }
}

// MARK: - UsageEntry

public struct UsageEntry: Sendable {
    public let timestamp: Date
    public let usage: TokenCounts
    public let costUSD: Double
    public let model: String
    public let sourceFile: String
    public let messageId: String?
    public let requestId: String?
    public let usageLimitResetTime: Date?

    public init(
        timestamp: Date,
        usage: TokenCounts,
        costUSD: Double,
        model: String,
        sourceFile: String,
        messageId: String? = nil,
        requestId: String? = nil,
        usageLimitResetTime: Date? = nil
    ) {
        self.timestamp = timestamp
        self.usage = usage
        self.costUSD = costUSD
        self.model = model
        self.sourceFile = sourceFile
        self.messageId = messageId
        self.requestId = requestId
        self.usageLimitResetTime = usageLimitResetTime
    }
}

// MARK: - BurnRate

public struct BurnRate: Sendable {
    public let tokensPerMinute: Int
    public let tokensPerMinuteForIndicator: Int
    public let costPerHour: Double

    public init(tokensPerMinute: Int, tokensPerMinuteForIndicator: Int, costPerHour: Double) {
        self.tokensPerMinute = tokensPerMinute
        self.tokensPerMinuteForIndicator = tokensPerMinuteForIndicator
        self.costPerHour = costPerHour
    }
}

// MARK: - ProjectedUsage

public struct ProjectedUsage: Sendable {
    public let totalTokens: Int
    public let totalCost: Double
    public let remainingMinutes: Double

    public init(totalTokens: Int, totalCost: Double, remainingMinutes: Double) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.remainingMinutes = remainingMinutes
    }
}

// MARK: - SessionBlock

public struct SessionBlock: Sendable {
    public let id: String
    public let startTime: Date
    public let endTime: Date
    public let actualEndTime: Date?
    public let isActive: Bool
    public let isGap: Bool
    public let entries: [UsageEntry]
    public let tokenCounts: TokenCounts
    public let costUSD: Double
    public let models: [String]
    public let usageLimitResetTime: Date?
    public let burnRate: BurnRate
    public let projectedUsage: ProjectedUsage

    public init(
        id: String,
        startTime: Date,
        endTime: Date,
        actualEndTime: Date?,
        isActive: Bool,
        isGap: Bool,
        entries: [UsageEntry],
        tokenCounts: TokenCounts,
        costUSD: Double,
        models: [String],
        usageLimitResetTime: Date?,
        burnRate: BurnRate,
        projectedUsage: ProjectedUsage
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.actualEndTime = actualEndTime
        self.isActive = isActive
        self.isGap = isGap
        self.entries = entries
        self.tokenCounts = tokenCounts
        self.costUSD = costUSD
        self.models = models
        self.usageLimitResetTime = usageLimitResetTime
        self.burnRate = burnRate
        self.projectedUsage = projectedUsage
    }
}
