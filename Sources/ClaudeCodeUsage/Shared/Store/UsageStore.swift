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
        guard !isCurrentlyLoading else { return }
        guard !isLoadedRecently else { return }

        isCurrentlyLoading = true
        lastLoadStartTime = dateProvider.now
        lastRefreshTime = dateProvider.now
        defer { isCurrentlyLoading = false }

        let loadStartTime = dateProvider.now

        do {
            // Phase 1: Load today's data immediately (fast ~0.3s)
            let todayResult = try await dataLoader.loadToday()
            applyTodayResult(todayResult)

            performanceLogger.info("Today's data loaded in \(String(format: "%.2f", self.dateProvider.now.timeIntervalSince(loadStartTime)))s")

            // Phase 2: Load historical data (slower ~2-4s, but UI already showing)
            let historyResult = try await dataLoader.loadHistory()
            applyHistoryResult(historyResult)

            logPerformance(startTime: loadStartTime)
        } catch {
            state = .error(error)
        }
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

    // MARK: - State Updates

    /// Apply today's data immediately - enables fast UI display
    private func applyTodayResult(_ result: TodayLoadResult) {
        activeSession = result.session
        burnRate = result.burnRate
        autoTokenLimit = result.autoTokenLimit
        todayEntries = result.todayEntries

        // Only transition to .loadedToday on first load (cold start)
        // Don't regress from .loaded to .loadedToday during refresh
        if case .loaded = state {
            // Keep existing .loaded state - don't flicker
        } else {
            state = .loadedToday(result.todayStats)
        }

        updateCalculatedProperties(stats: result.todayStats)
        updateChartData()
    }

    /// Apply historical data - updates full stats
    private func applyHistoryResult(_ result: FullLoadResult) {
        state = .loaded(result.fullStats)

        // Update threshold based on full historical data
        updateDailyCostThreshold(stats: result.fullStats)
    }

    private func applyLoadResult(_ result: UsageLoadResult) {
        activeSession = result.session
        burnRate = result.burnRate
        autoTokenLimit = result.autoTokenLimit
        todayEntries = result.todayEntries
        state = .loaded(result.fullStats)

        updateCalculatedProperties(stats: result.todayStats)
        updateChartData()
    }

    private func updateCalculatedProperties(stats: UsageStats) {
        let todayValue = todaysCostValue
        todaysCost = todayValue.asCurrency
        todaysCostProgress = min(todayValue / dailyCostThreshold, 1.5)

        todaySessionCount = activeSession != nil ? 1 : 0
        estimatedDailySessions = stats.byDate.isEmpty ? 0 : max(1, stats.totalSessions / stats.byDate.count)

        updateSessionProgress()
        updateDailyCostThreshold(stats: stats)
    }

    private func updateSessionProgress() {
        guard let session = activeSession else {
            sessionTimeProgress = 0
            sessionTokenProgress = 0
            return
        }

        let elapsed = dateProvider.now.timeIntervalSince(session.startTime)
        let total = session.endTime.timeIntervalSince(session.startTime)
        sessionTimeProgress = min(elapsed / total, 1.5)

        if let limit = autoTokenLimit, limit > 0 {
            sessionTokenProgress = min(Double(session.tokenCounts.total) / Double(limit), 1.5)
        }
    }

    private func updateDailyCostThreshold(stats: UsageStats) {
        guard !stats.byDate.isEmpty else { return }

        let recentDays = stats.byDate.suffix(7)
        let totalRecentCost = recentDays.reduce(0.0) { $0 + $1.totalCost }
        averageDailyCost = totalRecentCost / Double(recentDays.count)

        if averageDailyCost > 0 {
            dailyCostThreshold = max(averageDailyCost * 1.5, 10.0)
        }
    }

    private func updateChartData() {
        todayHourlyCosts = UsageAnalytics.todayHourlyCosts(from: todayEntries, referenceDate: dateProvider.now)
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

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: dateProvider.now)

        todayEntries = todayEntries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.startOfDay(for: date) == today
        }

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
