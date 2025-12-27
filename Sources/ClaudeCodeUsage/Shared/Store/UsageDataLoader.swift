//
//  UsageDataLoader.swift
//  Orchestrates data loading from repository and session services
//

import Foundation
import ClaudeCodeUsageKit
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

// MARK: - Load Results

/// Fast result from Phase 1 - today's data only
struct TodayLoadResult {
    let todayEntries: [UsageEntry]
    let todayStats: UsageStats
    let session: SessionBlock?
    let burnRate: BurnRate?
    let autoTokenLimit: Int?
}

/// Complete result including historical data
struct FullLoadResult {
    let fullStats: UsageStats
}

/// Combined result for backward compatibility
struct UsageLoadResult {
    let todayEntries: [UsageEntry]
    let todayStats: UsageStats
    let fullStats: UsageStats
    let session: SessionBlock?
    let burnRate: BurnRate?
    let autoTokenLimit: Int?
}

// MARK: - Data Loader

actor UsageDataLoader {
    private let repository: UsageRepository
    private let sessionMonitorService: SessionMonitorService

    init(repository: UsageRepository, sessionMonitorService: SessionMonitorService) {
        self.repository = repository
        self.sessionMonitorService = sessionMonitorService
    }

    /// Load today's data only - fast path for immediate UI display
    func loadToday() async throws -> TodayLoadResult {
        async let todayEntriesTask = repository.getTodayUsageEntries()
        async let todayStatsTask = repository.getTodayUsageStats()
        async let sessionTask = sessionMonitorService.getActiveSession()
        async let burnRateTask = sessionMonitorService.getBurnRate()
        async let tokenLimitTask = sessionMonitorService.getAutoTokenLimit()

        let (todayEntries, todayStats, session, burnRate, tokenLimit) = await (
            try todayEntriesTask,
            try todayStatsTask,
            sessionTask,
            burnRateTask,
            tokenLimitTask
        )

        return TodayLoadResult(
            todayEntries: todayEntries,
            todayStats: todayStats,
            session: session,
            burnRate: burnRate,
            autoTokenLimit: tokenLimit
        )
    }

    /// Load full historical data - slower path for complete stats
    func loadHistory() async throws -> FullLoadResult {
        let fullStats = try await repository.getUsageStats()
        return FullLoadResult(fullStats: fullStats)
    }

    /// Load all data at once (backward compatible)
    func loadAll() async throws -> UsageLoadResult {
        let today = try await loadToday()
        let history = try await loadHistory()

        return UsageLoadResult(
            todayEntries: today.todayEntries,
            todayStats: today.todayStats,
            fullStats: history.fullStats,
            session: today.session,
            burnRate: today.burnRate,
            autoTokenLimit: today.autoTokenLimit
        )
    }
}
