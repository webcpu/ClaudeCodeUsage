//
//  UsageSession.swift
//  Represents a time-bounded usage period with token tracking
//

import Foundation

// MARK: - UsageSession

public struct UsageSession: Sendable, Hashable {
    public let startTime: Date
    public let endTime: Date
    public let actualEndTime: Date?
    public let isActive: Bool
    public let entries: [UsageEntry]
    public let tokens: TokenCounts
    public let costUSD: Double
    public let models: [String]
    public let burnRate: BurnRate
    public let tokenLimit: Int?

    public init(
        startTime: Date,
        endTime: Date,
        actualEndTime: Date? = nil,
        isActive: Bool,
        entries: [UsageEntry],
        tokens: TokenCounts,
        costUSD: Double,
        models: [String],
        burnRate: BurnRate,
        tokenLimit: Int? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.actualEndTime = actualEndTime
        self.isActive = isActive
        self.entries = entries
        self.tokens = tokens
        self.costUSD = costUSD
        self.models = models
        self.burnRate = burnRate
        self.tokenLimit = tokenLimit
    }
}

// MARK: - Transformations

public extension UsageSession {
    /// Returns a copy with updated tokenLimit
    func with(tokenLimit: Int?) -> UsageSession {
        UsageSession(
            startTime: startTime,
            endTime: endTime,
            actualEndTime: actualEndTime,
            isActive: isActive,
            entries: entries,
            tokens: tokens,
            costUSD: costUSD,
            models: models,
            burnRate: burnRate,
            tokenLimit: tokenLimit
        )
    }
}

// MARK: - Derived Properties

public extension UsageSession {
    var duration: TimeInterval {
        (actualEndTime ?? endTime).timeIntervalSince(startTime)
    }

    var durationMinutes: Double {
        duration / 60.0
    }

    var entryCount: Int {
        entries.count
    }

    var projectedTokens: Int? {
        guard isActive, let limit = tokenLimit else { return nil }
        return limit
    }

    var remainingTokens: Int? {
        guard let limit = tokenLimit else { return nil }
        return max(0, limit - tokens.total)
    }

    var tokenProgress: Double? {
        guard let limit = tokenLimit, limit > 0 else { return nil }
        return Double(tokens.total) / Double(limit)
    }
}
