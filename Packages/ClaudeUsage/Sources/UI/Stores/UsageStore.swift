//
//  UsageStore.swift
//  Observable state container for usage data
//

import SwiftUI
import Observation
import ClaudeUsageCore
import ClaudeUsageData
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "Store")

// MARK: - Usage Store

@Observable
@MainActor
public final class UsageStore {
    // MARK: - Source State

    private(set) var state: ViewState = .loading
    private(set) var activeSession: SessionBlock?
    private(set) var burnRate: BurnRate?
    private(set) var todayEntries: [UsageEntry] = []

    // MARK: - Configuration

    private let defaultThreshold: Double

    // MARK: - Derived Properties

    var isLoading: Bool { state.isLoading }
    var stats: UsageStats? { state.stats }

    var todaysCost: Double {
        todayEntries.reduce(0.0) { $0 + $1.costUSD }
    }

    var dailyCostThreshold: Double {
        deriveThreshold(from: stats, default: defaultThreshold)
    }

    var todaysCostProgress: Double {
        progressCapped(todaysCost / dailyCostThreshold)
    }

    var sessionTimeProgress: Double {
        activeSession.map { sessionProgress($0, now: clock.now) } ?? 0
    }

    var averageDailyCost: Double {
        stats.flatMap { recentDaysAverage($0.byDate) } ?? 0
    }

    var todayHourlyCosts: [Double] {
        UsageAggregator.todayHourlyCosts(from: todayEntries, referenceDate: clock.now)
    }

    var formattedTodaysCost: String {
        todaysCost.asCurrency
    }

    // MARK: - Dependencies

    private let dataLoader: UsageDataLoader
    private let clock: any ClockProtocol
    private let refreshCoordinator: RefreshCoordinator
    private let loadTrace: any LoadTracing

    // MARK: - Internal State

    private var isCurrentlyLoading = false
    private var hasInitialized = false
    private var lastHistoryLoadDate: Date?

    // MARK: - Initialization

    public convenience init() {
        self.init(
            repository: UsageStoreDefaults.repository,
            sessionDataSource: UsageStoreDefaults.sessionDataSource,
            configurationService: UsageStoreDefaults.configurationService,
            clock: UsageStoreDefaults.clock,
            loadTrace: UsageStoreDefaults.loadTrace
        )
    }

    init(
        repository: (any UsageDataSource)? = nil,
        sessionDataSource: (any SessionDataSource)? = nil,
        configurationService: ConfigurationService? = nil,
        clock: any ClockProtocol = SystemClock(),
        loadTrace: any LoadTracing = LoadTrace.shared
    ) {
        let config = configurationService ?? DefaultConfigurationService()
        let repo = repository ?? UsageRepository(basePath: config.configuration.basePath)
        let sessionSource = sessionDataSource ?? SessionMonitor(
            basePath: config.configuration.basePath,
            sessionDurationHours: config.configuration.sessionDurationHours
        )

        self.dataLoader = UsageDataLoader(repository: repo, sessionDataSource: sessionSource, loadTrace: loadTrace)
        self.clock = clock
        self.defaultThreshold = config.configuration.dailyCostThreshold
        self.loadTrace = loadTrace
        self.refreshCoordinator = RefreshCoordinatorFactory.make(
            clock: clock,
            basePath: config.configuration.basePath
        )

        refreshCoordinator.onRefresh = { [weak self] reason in
            await self?.loadData(invalidateCache: reason.shouldInvalidateCache)
        }
    }

    // MARK: - Public API

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if !state.hasLoaded {
            await loadData(invalidateCache: true)
        }
    }

    func loadData(invalidateCache: Bool = true) async {
        guard !isCurrentlyLoading else {
            logger.debug("Load blocked: already loading")
            return
        }
        logger.info("Loading data (invalidateCache=\(invalidateCache))")
        await trackLoadExecution { try await executeLoad(invalidateCache: invalidateCache) }
    }

    // MARK: - Load Execution

    private func trackLoadExecution(_ load: () async throws -> Void) async {
        isCurrentlyLoading = true
        _ = await loadTrace.start()
        defer { isCurrentlyLoading = false }

        do {
            try await load()
            await loadTrace.complete()
        } catch {
            state = .error(error)
        }
    }

    private func executeLoad(invalidateCache: Bool) async throws {
        let todayResult = try await dataLoader.loadToday(invalidateCache: invalidateCache)
        apply(todayResult)
        try await loadHistoryIfNeeded()
    }

    private func loadHistoryIfNeeded() async throws {
        guard shouldLoadHistory else {
            await loadTrace.skipHistory()
            return
        }
        let historyResult = try await dataLoader.loadHistory()
        apply(historyResult)
        lastHistoryLoadDate = clock.now
    }

    private var shouldLoadHistory: Bool {
        guard let lastDate = lastHistoryLoadDate else { return true }
        return !Calendar.current.isDate(lastDate, inSameDayAs: clock.now)
    }

    // MARK: - State Transitions

    private func apply(_ result: TodayLoadResult) {
        let oldCost = todaysCost
        let oldCount = todayEntries.count

        activeSession = result.session
        burnRate = result.burnRate
        todayEntries = result.todayEntries

        let newCost = todaysCost
        logger.info("Entries: \(oldCount) → \(result.todayEntries.count), Cost: $\(oldCost, format: .fixed(precision: 2)) → $\(newCost, format: .fixed(precision: 2))")

        if case .loaded = state { return }
        state = .loadedToday(result.todayStats)
    }

    private func apply(_ result: FullLoadResult) {
        state = .loaded(result.fullStats)
    }

    // MARK: - Lifecycle

    func handleAppBecameActive() {
        refreshCoordinator.handleAppBecameActive()
    }

    func handleAppResignActive() {
        refreshCoordinator.handleAppResignActive()
    }

    func handleWindowFocus() {
        refreshCoordinator.handleWindowFocus()
    }
}

// MARK: - Factory

/// Provides default dependencies for UsageStore construction.
/// Separates construction policy from the UsageStore class itself.
@MainActor
enum UsageStoreDefaults {
    static var clock: any ClockProtocol { SystemClock() }
    static var loadTrace: any LoadTracing { LoadTrace.shared }
    static var repository: (any UsageDataSource)? { nil }
    static var sessionDataSource: (any SessionDataSource)? { nil }
    static var configurationService: ConfigurationService? { nil }
}

// MARK: - Supporting Types

/// Describes the derived properties for a ViewState case.
/// Each case provides its own values, eliminating pattern matching.
struct ViewStateDescriptor {
    let isLoading: Bool
    let hasLoaded: Bool
    let stats: UsageStats?
    let error: Error?

    static let loading = ViewStateDescriptor(
        isLoading: true,
        hasLoaded: false,
        stats: nil,
        error: nil
    )

    static func loadedToday(_ stats: UsageStats) -> ViewStateDescriptor {
        ViewStateDescriptor(
            isLoading: false,
            hasLoaded: true,
            stats: nil,
            error: nil
        )
    }

    static func loaded(_ stats: UsageStats) -> ViewStateDescriptor {
        ViewStateDescriptor(
            isLoading: false,
            hasLoaded: true,
            stats: stats,
            error: nil
        )
    }

    static func error(_ error: Error) -> ViewStateDescriptor {
        ViewStateDescriptor(
            isLoading: false,
            hasLoaded: false,
            stats: nil,
            error: error
        )
    }
}

enum ViewState {
    case loading
    case loadedToday(UsageStats)
    case loaded(UsageStats)
    case error(Error)

    /// Each case maps to its descriptor - no pattern matching in computed properties
    var descriptor: ViewStateDescriptor {
        switch self {
        case .loading:
            return .loading
        case .loadedToday(let stats):
            return .loadedToday(stats)
        case .loaded(let stats):
            return .loaded(stats)
        case .error(let error):
            return .error(error)
        }
    }

    var isLoading: Bool { descriptor.isLoading }
    var hasLoaded: Bool { descriptor.hasLoaded }
    var stats: UsageStats? { descriptor.stats }
}

// MARK: - Pure Functions

private func deriveThreshold(from stats: UsageStats?, default defaultThreshold: Double) -> Double {
    guard let stats = stats, !stats.byDate.isEmpty else { return defaultThreshold }
    let average = recentDaysAverage(stats.byDate) ?? 0
    return average > 0 ? max(average * 1.5, 10.0) : defaultThreshold
}

private func recentDaysAverage(_ byDate: [DailyUsage]) -> Double? {
    guard !byDate.isEmpty else { return nil }
    let recentDays = byDate.suffix(7)
    return recentDays.reduce(0.0) { $0 + $1.totalCost } / Double(recentDays.count)
}

private func progressCapped(_ value: Double) -> Double {
    min(value, 1.5)
}

private func sessionProgress(_ session: SessionBlock, now: Date) -> Double {
    // Progress = time since session started / 5h window
    let elapsed = now.timeIntervalSince(session.startTime)
    let total = session.endTime.timeIntervalSince(session.startTime)
    guard total > 0 else { return 0 }
    return min(elapsed / total, 1.0)
}
