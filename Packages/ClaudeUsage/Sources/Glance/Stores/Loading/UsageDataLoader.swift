//
//  UsageDataLoader.swift
//  Orchestrates data loading from providers
//

import Foundation

// MARK: - Load Pipeline

/// Async load stage that transforms input to output
typealias LoadStage<In, Out> = @Sendable (In) async throws -> Out

/// Forward composition for async load stages: `f >>> g` means "first f, then g"
func >>> <A, B, C>(
    _ f: @escaping LoadStage<A, B>,
    _ g: @escaping LoadStage<B, C>
) -> LoadStage<A, C> {
    { a in try await g(f(a)) }
}

// MARK: - Pipeline Configuration

/// Configuration passed through the load pipeline
struct LoadPipelineInput: Sendable {
    let invalidateCache: Bool

    static let standard = LoadPipelineInput(invalidateCache: false)
    static let refresh = LoadPipelineInput(invalidateCache: true)
}

/// Intermediate result after today phase
struct TodayPhaseOutput: Sendable {
    let input: LoadPipelineInput
    let today: TodayLoadResult
}

// MARK: - UsageDataLoader

actor UsageDataLoader {
    private let usageProvider: any UsageProviding
    private let sessionProvider: any SessionProviding
    private let loadTrace: any LoadTracing

    /// The composed load pipeline: today >>> history >>> combine
    private var loadPipeline: LoadStage<LoadPipelineInput, UsageLoadResult> {
        todayStage >>> historyStage >>> combineStage
    }

    init(
        usageProvider: any UsageProviding,
        sessionProvider: any SessionProviding,
        loadTrace: any LoadTracing = LoadTrace.shared
    ) {
        self.usageProvider = usageProvider
        self.sessionProvider = sessionProvider
        self.loadTrace = loadTrace
    }

    func loadToday(invalidateCache: Bool = false) async throws -> TodayLoadResult {
        if invalidateCache {
            await usageProvider.clearCache()
        }
        return try await tracePhase(.today) {
            try await fetchTodayData()
        }
    }

    func loadHistory() async throws -> FullLoadResult {
        try await tracePhase(.history) {
            FullLoadResult(fullStats: try await usageProvider.getUsageStats())
        }
    }

    func loadAll(invalidateCache: Bool = false) async throws -> UsageLoadResult {
        let input = invalidateCache ? LoadPipelineInput.refresh : LoadPipelineInput.standard
        return try await loadPipeline(input)
    }
}

// MARK: - Pipeline Stages

private extension UsageDataLoader {
    /// Stage 1: Load today's data with optional cache invalidation
    var todayStage: LoadStage<LoadPipelineInput, TodayPhaseOutput> {
        { [self] input in
            let today = try await loadToday(invalidateCache: input.invalidateCache)
            return TodayPhaseOutput(input: input, today: today)
        }
    }

    /// Stage 2: Load historical data
    var historyStage: LoadStage<TodayPhaseOutput, (TodayLoadResult, FullLoadResult)> {
        { [self] phaseOutput in
            let history = try await loadHistory()
            return (phaseOutput.today, history)
        }
    }

    /// Stage 3: Combine results into final output
    var combineStage: LoadStage<(TodayLoadResult, FullLoadResult), UsageLoadResult> {
        { pair in
            let (today, history) = pair
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
}

// MARK: - Data Fetching

private extension UsageDataLoader {
    func fetchTodayData() async throws -> TodayLoadResult {
        async let entriesTask = usageProvider.getTodayEntries()
        async let sessionTask = fetchSessionWithTracing()

        let entries = try await entriesTask
        let (session, burnRate) = await sessionTask

        return buildTodayResult(entries: entries, session: session, burnRate: burnRate)
    }

    func fetchSessionWithTracing() async -> (UsageSession?, BurnRate?) {
        let (session, timing) = await timed { await sessionProvider.getActiveSession() }
        await recordSessionTrace(session: session, timing: timing)
        return (session, session?.burnRate)
    }
}

// MARK: - Result Building

private extension UsageDataLoader {
    func buildTodayResult(
        entries: [UsageEntry],
        session: UsageSession?,
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
}

// MARK: - Tracing Infrastructure

private extension UsageDataLoader {
    private enum TracingThreshold {
        static let cachedResponseTime: TimeInterval = 0.05
    }

    func tracePhase<T>(_ phase: LoadPhase, operation: () async throws -> T) async rethrows -> T {
        await loadTrace.phaseStart(phase)
        let result = try await operation()
        await loadTrace.phaseComplete(phase)
        return result
    }

    func recordSessionTrace(session: UsageSession?, timing: TimeInterval) async {
        await loadTrace.recordSession(
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
    let session: UsageSession?
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
    let session: UsageSession?
    let burnRate: BurnRate?
    let autoTokenLimit: Int?
}
