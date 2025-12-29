//
//  UsageDataLoader.swift
//  Orchestrates data loading from repository and session services
//

import Foundation
import ClaudeUsageCore

// MARK: - UsageDataLoader

actor UsageDataLoader {
    private let repository: any UsageDataSource
    private let sessionMonitorService: SessionMonitorService

    init(repository: any UsageDataSource, sessionMonitorService: SessionMonitorService) {
        self.repository = repository
        self.sessionMonitorService = sessionMonitorService
    }

    /// Load today's data only - fast path for immediate UI display
    func loadToday() async throws -> TodayLoadResult {
        await LoadTrace.shared.phaseStart(.today)

        // Load entries once, derive stats from them (avoid duplicate fetch)
        async let todayEntriesTask = repository.getTodayEntries()
        async let sessionTask = fetchSession()
        async let tokenLimitTask = fetchTokenLimit()

        let todayEntries = try await todayEntriesTask
        let todayStats = deriveStats(from: todayEntries)
        let (session, burnRate) = await sessionTask
        let tokenLimit = await tokenLimitTask

        await LoadTrace.shared.phaseComplete(.today)

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
        await LoadTrace.shared.phaseStart(.history)
        let fullStats = try await repository.getUsageStats()
        await LoadTrace.shared.phaseComplete(.history)
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

    // MARK: - Session Fetching with Tracing

    private func fetchSession() async -> (SessionBlock?, BurnRate?) {
        let start = Date()
        let session = await sessionMonitorService.getActiveSession()
        let duration = Date().timeIntervalSince(start)

        await LoadTrace.shared.recordSession(
            found: session != nil,
            cached: duration < 0.05,
            duration: duration
        )

        return (session, session?.burnRate)
    }

    private func fetchTokenLimit() async -> Int? {
        let start = Date()
        let limit = await sessionMonitorService.getAutoTokenLimit()
        let duration = Date().timeIntervalSince(start)

        await LoadTrace.shared.recordTokenLimit(
            limit: limit,
            cached: duration < 0.05,
            duration: duration
        )

        return limit
    }

    // MARK: - Stats Derivation

    private func deriveStats(from entries: [UsageEntry]) -> UsageStats {
        UsageAggregator.aggregate(entries)
    }
}

// MARK: - Supporting Types

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
