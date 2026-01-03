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

    // MARK: - Internal State

    private var isCurrentlyLoading = false
    private var hasInitialized = false
    private var lastHistoryLoadDate: Date?

    // MARK: - Initialization

    public convenience init() {
        self.init(repository: nil, sessionMonitorService: nil, configurationService: nil, clock: SystemClock())
    }

    init(
        repository: (any UsageDataSource)? = nil,
        sessionMonitorService: SessionMonitorService? = nil,
        configurationService: ConfigurationService? = nil,
        clock: any ClockProtocol = SystemClock()
    ) {
        let config = configurationService ?? DefaultConfigurationService()
        let repo = repository ?? UsageRepository(basePath: config.configuration.basePath)
        let sessionService = sessionMonitorService ?? DefaultSessionMonitorService(configuration: config.configuration)

        self.dataLoader = UsageDataLoader(repository: repo, sessionMonitorService: sessionService)
        self.clock = clock
        self.defaultThreshold = config.configuration.dailyCostThreshold
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
        _ = await LoadTrace.shared.start()
        defer { isCurrentlyLoading = false }

        do {
            try await load()
            await LoadTrace.shared.complete()
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
            await LoadTrace.shared.skipHistory()
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

// MARK: - Supporting Types

enum ViewState {
    case loading
    case loadedToday(UsageStats)
    case loaded(UsageStats)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var hasLoaded: Bool {
        switch self {
        case .loadedToday, .loaded: return true
        default: return false
        }
    }

    var stats: UsageStats? {
        if case .loaded(let stats) = self { return stats }
        return nil
    }
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
