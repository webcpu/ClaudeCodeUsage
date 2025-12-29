//
//  LiveMonitorConversion.swift
//  ClaudeUsage
//
//  Converts ClaudeLiveMonitorLib types to ClaudeUsageCore types
//  Used at the boundary between LiveMonitor and the app
//

import Foundation
import ClaudeUsageCore
import ClaudeLiveMonitorLib

// MARK: - SessionBlock Conversion

extension ClaudeUsageCore.SessionBlock {
    /// Convert from ClaudeLiveMonitorLib.SessionBlock
    init(from lm: ClaudeLiveMonitorLib.SessionBlock) {
        self.init(
            id: lm.id,
            startTime: lm.startTime,
            endTime: lm.endTime,
            actualEndTime: lm.actualEndTime,
            isActive: lm.isActive,
            entries: lm.entries.map { ClaudeUsageCore.UsageEntry(from: $0) },
            tokens: ClaudeUsageCore.TokenCounts(from: lm.tokenCounts),
            costUSD: lm.costUSD,
            models: lm.models,
            burnRate: ClaudeUsageCore.BurnRate(from: lm.burnRate),
            tokenLimit: nil
        )
    }
}

// MARK: - BurnRate Conversion

extension ClaudeUsageCore.BurnRate {
    /// Convert from ClaudeLiveMonitorLib.BurnRate
    init(from lm: ClaudeLiveMonitorLib.BurnRate) {
        self.init(
            tokensPerMinute: lm.tokensPerMinute,
            costPerHour: lm.costPerHour
        )
    }
}

// MARK: - TokenCounts Conversion

extension ClaudeUsageCore.TokenCounts {
    /// Convert from ClaudeLiveMonitorLib.TokenCounts
    init(from lm: ClaudeLiveMonitorLib.TokenCounts) {
        self.init(
            input: lm.inputTokens,
            output: lm.outputTokens,
            cacheCreation: lm.cacheCreationInputTokens,
            cacheRead: lm.cacheReadInputTokens
        )
    }
}

// MARK: - UsageEntry Conversion

extension ClaudeUsageCore.UsageEntry {
    /// Convert from ClaudeLiveMonitorLib.UsageEntry
    init(from lm: ClaudeLiveMonitorLib.UsageEntry) {
        self.init(
            timestamp: lm.timestamp,
            model: lm.model,
            tokens: ClaudeUsageCore.TokenCounts(from: lm.usage),
            costUSD: lm.costUSD,
            project: "",  // LiveMonitor entries don't have project
            sourceFile: lm.sourceFile,
            messageId: lm.messageId,
            requestId: lm.requestId
        )
    }
}
