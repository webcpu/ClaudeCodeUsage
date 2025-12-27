//
//  UsageStore.swift
//  Observable state container for usage data
//

import SwiftUI
import Observation
import ClaudeCodeUsageKit
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
import OSLog

private let performanceLogger = Logger(subsystem: "com.claudecodeusage", category: "StorePerformance")

// MARK: - View State

enum ViewState {
    case loading
    case loadedToday(UsageStats)  // Today's data loaded, history loading
    case loaded(UsageStats)       // All data loaded
    case error(Error)
}

// MARK: - Computed State (All Derived Values)

private struct ComputedState {
    let cost: CostMetrics
    let session: SessionMetrics
    let counts: SessionCounts
    let threshold: ThresholdMetrics

    static func from(
        entries: [UsageEntry],
        session: SessionBlock?,
        tokenLimit: Int?,
        stats: UsageStats,
        threshold: Double,
        now: Date
    ) -> ComputedState {
        ComputedState(
            cost: CostMetrics.from(entries: entries, threshold: threshold),
            session: SessionMetrics.from(session: session, tokenLimit: tokenLimit, now: now),
            counts: SessionCounts.from(hasActiveSession: session != nil, stats: stats),
            threshold: ThresholdMetrics.from(stats: stats, currentThreshold: threshold)
        )
    }
}

// MARK: - Pure Computed Values

private struct CostMetrics {
    let formattedCost: String
    let progress: Double

    static func from(entries: [UsageEntry], threshold: Double) -> CostMetrics {
        let totalCost = entries.reduce(0.0) { $0 + $1.cost }
        return CostMetrics(
            formattedCost: totalCost.asCurrency,
            progress: min(totalCost / threshold, 1.5)
        )
    }
}

private struct SessionMetrics {
    let timeProgress: Double
    let tokenProgress: Double

    static func from(session: SessionBlock?, tokenLimit: Int?, now: Date) -> SessionMetrics {
        guard let session = session else {
            return SessionMetrics(timeProgress: 0, tokenProgress: 0)
        }
        return SessionMetrics(
            timeProgress: calculateTimeProgress(session: session, now: now),
            tokenProgress: calculateTokenProgress(session: session, tokenLimit: tokenLimit)
        )
    }

    private static func calculateTimeProgress(session: SessionBlock, now: Date) -> Double {
        let elapsed = now.timeIntervalSince(session.startTime)
        let total = session.endTime.timeIntervalSince(session.startTime)
        return min(elapsed / total, 1.5)
    }

    private static func calculateTokenProgress(session: SessionBlock, tokenLimit: Int?) -> Double {
        guard let limit = tokenLimit, limit > 0 else { return 0 }
        return min(Double(session.tokenCounts.total) / Double(limit), 1.5)
    }
}

private struct SessionCounts {
    let todayCount: Int
    let estimatedDaily: Int

    static func from(hasActiveSession: Bool, stats: UsageStats) -> SessionCounts {
        SessionCounts(
            todayCount: hasActiveSession ? 1 : 0,
            estimatedDaily: stats.byDate.isEmpty ? 0 : max(1, stats.totalSessions / stats.byDate.count)
        )
    }
}

private struct ThresholdMetrics {
    let averageDailyCost: Double
    let threshold: Double

    static func from(stats: UsageStats, currentThreshold: Double) -> ThresholdMetrics {
        guard !stats.byDate.isEmpty else {
            return ThresholdMetrics(averageDailyCost: 0, threshold: currentThreshold)
        }
        let recentDays = stats.byDate.suffix(7)
        let average = recentDays.reduce(0.0) { $0 + $1.totalCost } / Double(recentDays.count)
        let newThreshold = average > 0 ? max(average * 1.5, 10.0) : currentThreshold
        return ThresholdMetrics(averageDailyCost: average, threshold: newThreshold)
    }
}

// MARK: - Pure Functions

private func nextState(current: ViewState, todayStats: UsageStats) -> ViewState {
    if case .loaded = current { return current }  // Don't regress during refresh
    return .loadedToday(todayStats)
}

private func entriesForToday(_ entries: [UsageEntry], referenceDate: Date) -> [UsageEntry] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: referenceDate)
    return entries.filter { entry in
        guard let date = entry.date else { return false }
        return calendar.startOfDay(for: date) == today
    }
}

// MARK: - Usage Store

@Observable
@MainActor
final class UsageStore {
    // MARK: - Observable State

    var state: ViewState = .loading
    var activeSession: SessionBlock?
    var burnRate: BurnRate?
    var autoTokenLimit: Int?
    var todaysCost: String = "$0.00"
    var todaysCostProgress: Double = 0.0
    var sessionTimeProgress: Double = 0.0
    var sessionTokenProgress: Double = 0.0
    var averageDailyCost: Double = 0.0
    var dailyCostThreshold: Double = 10.0
    var todaySessionCount: Int = 0
    var estimatedDailySessions: Int = 0
    var todayEntries: [UsageEntry] = []
    var lastRefreshTime: Date
    var todayHourlyCosts: [Double] = []

    // MARK: - Computed Properties

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isLoadingHistory: Bool {
        if case .loadedToday = state { return true }
        return false
    }

    var hasInitiallyLoaded: Bool {
        switch state {
        case .loadedToday, .loaded: return true
        default: return false
        }
    }

    var lastError: Error? {
        if case .error(let error) = state { return error }
        return nil
    }

    var errorMessage: String? {
        if case .error(let error) = state { return error.localizedDescription }
        return nil
    }

    /// Full historical stats - only available after Phase 2 completes
    var stats: UsageStats? {
        if case .loaded(let stats) = state { return stats }
        return nil
    }

    /// Today's stats - available after Phase 1 (fast path)
    var todayStats: UsageStats? {
        switch state {
        case .loadedToday, .loaded:
            return UsageStats(
                totalCost: todaysCostValue,
                totalTokens: todayEntries.reduce(0) { $0 + $1.totalTokens },
                totalInputTokens: todayEntries.reduce(0) { $0 + $1.inputTokens },
                totalOutputTokens: todayEntries.reduce(0) { $0 + $1.outputTokens },
                totalCacheCreationTokens: todayEntries.reduce(0) { $0 + $1.cacheWriteTokens },
                totalCacheReadTokens: todayEntries.reduce(0) { $0 + $1.cacheReadTokens },
                totalSessions: 1,
                byModel: [],
                byDate: [],
                byProject: []
            )
        default:
            return nil
        }
    }

    var todaysCostValue: Double {
        todayEntries.reduce(0.0) { $0 + $1.cost }
    }

    var totalCost: String {
        guard let stats else { return "$0.00" }
        return FormatterService.formatCurrency(stats.totalCost)
    }

    var formattedTodaysCost: String? {
        FormatterService.formatCurrency(todaysCostValue)
    }

    var formattedTotalCost: String? {
        stats.map { FormatterService.formatCurrency($0.totalCost) } ?? nil
    }

    var lastUpdateTime: Date? { lastRefreshTime }

    // MARK: - Dependencies

    let sessionMonitorService: SessionMonitorService
    private let dataLoader: UsageDataLoader
    private let dateProvider: DateProviding
    private let refreshCoordinator: RefreshCoordinator

    // MARK: - Internal State

    private var memoryCleanupObserver: NSObjectProtocol?
    private var isCurrentlyLoading = false
    private var lastLoadStartTime: Date?
    private var hasInitialized = false

    // MARK: - Initialization

    init(
        repository: UsageRepository? = nil,
        sessionMonitorService: SessionMonitorService? = nil,
        configurationService: ConfigurationService? = nil,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        let config = configurationService ?? DefaultConfigurationService()
        let repo = repository ?? UsageRepository(basePath: config.configuration.basePath)
        let sessionService = sessionMonitorService ?? DefaultSessionMonitorService(configuration: config.configuration)

        self.sessionMonitorService = sessionService
        self.dataLoader = UsageDataLoader(repository: repo, sessionMonitorService: sessionService)
        self.dateProvider = dateProvider
        self.lastRefreshTime = dateProvider.now
        self.dailyCostThreshold = config.configuration.dailyCostThreshold

        // Create coordinator synchronously (callback set after init)
        self.refreshCoordinator = RefreshCoordinator(
            dateProvider: dateProvider,
            refreshInterval: config.configuration.refreshInterval
        )

        setupMemoryCleanupObserver()

        // Set callback after all properties initialized (avoids capturing self before init)
        refreshCoordinator.onRefresh = { [weak self] in
            await self?.loadData()
        }
    }

    // MARK: - Public API

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if !hasInitiallyLoaded {
            await loadData()
        }
        refreshCoordinator.start()
    }

    func loadData() async {
        guard !isCurrentlyLoading, !isLoadedRecently else { return }

        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }

        let startTime = dateProvider.now
        lastLoadStartTime = startTime
        lastRefreshTime = startTime

        do {
            // Phase 1: Load and apply today's data
            let todayResult = try await dataLoader.loadToday()
            apply(todayResult)

            // Phase 2: Load and apply historical data
            let historyResult = try await dataLoader.loadHistory()
            apply(historyResult)

            logPerformance(startTime: startTime)
        } catch {
            state = .error(error)
        }
    }

    // MARK: - State Application (Single Entry Points)

    private func apply(_ result: TodayLoadResult) {
        // Update raw state
        activeSession = result.session
        burnRate = result.burnRate
        autoTokenLimit = result.autoTokenLimit
        todayEntries = result.todayEntries
        state = nextState(current: state, todayStats: result.todayStats)

        // Derive and apply computed values
        let computed = ComputedState.from(
            entries: todayEntries,
            session: activeSession,
            tokenLimit: autoTokenLimit,
            stats: result.todayStats,
            threshold: dailyCostThreshold,
            now: dateProvider.now
        )
        apply(computed)

        todayHourlyCosts = UsageAnalytics.todayHourlyCosts(from: todayEntries, referenceDate: dateProvider.now)
    }

    private func apply(_ result: FullLoadResult) {
        state = .loaded(result.fullStats)

        let thresholdMetrics = ThresholdMetrics.from(stats: result.fullStats, currentThreshold: dailyCostThreshold)
        averageDailyCost = thresholdMetrics.averageDailyCost
        dailyCostThreshold = thresholdMetrics.threshold
    }

    private func apply(_ computed: ComputedState) {
        todaysCost = computed.cost.formattedCost
        todaysCostProgress = computed.cost.progress
        sessionTimeProgress = computed.session.timeProgress
        sessionTokenProgress = computed.session.tokenProgress
        todaySessionCount = computed.counts.todayCount
        estimatedDailySessions = computed.counts.estimatedDaily
        averageDailyCost = computed.threshold.averageDailyCost
        dailyCostThreshold = computed.threshold.threshold
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Lifecycle Delegation

    func handleAppBecameActive() {
        refreshCoordinator.handleAppBecameActive()
    }

    func handleAppResignActive() {
        refreshCoordinator.handleAppResignActive()
    }

    func handleWindowFocus() {
        refreshCoordinator.handleWindowFocus()
    }

    func startRefreshTimer() {
        refreshCoordinator.start()
    }

    func stopRefreshTimer() {
        refreshCoordinator.stop()
    }

    // MARK: - Memory Management

    private func setupMemoryCleanupObserver() {
        memoryCleanupObserver = NotificationCenter.default.addObserver(
            forName: .performMemoryCleanup,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryCleanup()
            }
        }
    }

    private func performMemoryCleanup() {
        performanceLogger.info("Performing memory cleanup")

        todayEntries = entriesForToday(todayEntries, referenceDate: dateProvider.now)

        if activeSession != nil {
            Task { await loadData() }
        }

        performanceLogger.info("Memory cleanup completed")
    }

    // MARK: - Helpers

    private var isLoadedRecently: Bool {
        guard let lastTime = lastLoadStartTime else { return false }
        return dateProvider.now.timeIntervalSince(lastTime) < 0.5
    }

    private func logPerformance(startTime: Date) {
        let totalTime = dateProvider.now.timeIntervalSince(startTime)
        if totalTime > 2.0 {
            performanceLogger.warning("Slow data load: \(String(format: "%.2f", totalTime))s")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Token Formatting

func formatTokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    } else {
        return "\(count)"
    }
}
