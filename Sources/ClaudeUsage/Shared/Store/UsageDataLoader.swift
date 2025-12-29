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

    func loadToday() async throws -> TodayLoadResult {
        try await tracePhase(.today) {
            try await fetchTodayData()
        }
    }

    func loadHistory() async throws -> FullLoadResult {
        try await tracePhase(.history) {
            FullLoadResult(fullStats: try await repository.getUsageStats())
        }
    }

    func loadAll() async throws -> UsageLoadResult {
        let today = try await loadToday()
        let history = try await loadHistory()
        return combineResults(today: today, history: history)
    }
}

// MARK: - Data Fetching

private extension UsageDataLoader {
    func fetchTodayData() async throws -> TodayLoadResult {
        async let entriesTask = repository.getTodayEntries()
        async let sessionTask = fetchSessionWithTracing()

        let entries = try await entriesTask
        let (session, burnRate) = await sessionTask

        return buildTodayResult(entries: entries, session: session, burnRate: burnRate)
    }

    func fetchSessionWithTracing() async -> (SessionBlock?, BurnRate?) {
        let (session, timing) = await timed { await sessionMonitorService.getActiveSession() }
        await recordSessionTrace(session: session, timing: timing)
        return (session, session?.burnRate)
    }
}

// MARK: - Result Building

private extension UsageDataLoader {
    func buildTodayResult(
        entries: [UsageEntry],
        session: SessionBlock?,
        burnRate: BurnRate?
    ) -> TodayLoadResult {
        TodayLoadResult(
            todayEntries: entries,
            todayStats: UsageAggregator.aggregate(entries),
            session: session,
            burnRate: burnRate,
            autoTokenLimit: session?.tokenLimit
        )
    }

    func combineResults(today: TodayLoadResult, history: FullLoadResult) -> UsageLoadResult {
        UsageLoadResult(
            todayEntries: today.todayEntries,
            todayStats: today.todayStats,
            fullStats: history.fullStats,
            session: today.session,
            burnRate: today.burnRate,
            autoTokenLimit: today.autoTokenLimit
        )
    }
}

// MARK: - Tracing Infrastructure

private extension UsageDataLoader {
    private enum TracingThreshold {
        static let cachedResponseTime: TimeInterval = 0.05
    }

    func tracePhase<T>(_ phase: LoadPhase, operation: () async throws -> T) async rethrows -> T {
        await LoadTrace.shared.phaseStart(phase)
        let result = try await operation()
        await LoadTrace.shared.phaseComplete(phase)
        return result
    }

    func recordSessionTrace(session: SessionBlock?, timing: TimeInterval) async {
        await LoadTrace.shared.recordSession(
            found: session != nil,
            cached: timing < TracingThreshold.cachedResponseTime,
            duration: timing,
            tokenLimit: session?.tokenLimit
        )
    }

    func timed<T>(_ operation: () async -> T) async -> (T, TimeInterval) {
        let start = Date()
        let result = await operation()
        return (result, Date().timeIntervalSince(start))
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
