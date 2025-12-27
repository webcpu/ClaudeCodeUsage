//
//  UsageDataLoader.swift
//  Orchestrates data loading from repository and session services
//

import Foundation
import ClaudeCodeUsageKit
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

// MARK: - Load Result

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

    func loadAll() async throws -> UsageLoadResult {
        // Phase 1: Load today's data + session info (fast, concurrent)
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

        // Phase 2: Load full historical data
        let fullStats = try await repository.getUsageStats()

        return UsageLoadResult(
            todayEntries: todayEntries,
            todayStats: todayStats,
            fullStats: fullStats,
            session: session,
            burnRate: burnRate,
            autoTokenLimit: tokenLimit
        )
    }
}
