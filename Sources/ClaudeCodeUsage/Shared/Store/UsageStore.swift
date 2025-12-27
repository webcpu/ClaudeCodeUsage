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

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isLoadingHistory: Bool {
        if case .loadedToday = self { return true }
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

    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}

// MARK: - Pure Functions

private func deriveThreshold(from stats: UsageStats?, default defaultThreshold: Double) -> Double {
    guard let stats = stats, !stats.byDate.isEmpty else { return defaultThreshold }
    let recentDays = stats.byDate.suffix(7)
    let average = recentDays.reduce(0.0) { $0 + $1.totalCost } / Double(recentDays.count)
    return average > 0 ? max(average * 1.5, 10.0) : defaultThreshold
}

private func filterToday(_ entries: [UsageEntry], referenceDate: Date) -> [UsageEntry] {
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
    // MARK: - Source State (Single Source of Truth)

    private(set) var state: ViewState = .loading
    private(set) var activeSession: SessionBlock?
    private(set) var burnRate: BurnRate?
    private(set) var autoTokenLimit: Int?
    private(set) var todayEntries: [UsageEntry] = []
    private(set) var lastRefreshTime: Date

    // MARK: - Configuration

    private let defaultThreshold: Double

    // MARK: - Derived Properties (All Computed)

    var isLoading: Bool { state.isLoading }
    var isLoadingHistory: Bool { state.isLoadingHistory }
    var hasInitiallyLoaded: Bool { state.hasLoaded }
    var stats: UsageStats? { state.stats }
    var errorMessage: String? { state.error?.localizedDescription }

    var todaysCost: Double {
        todayEntries.reduce(0.0) { $0 + $1.cost }
    }

    var dailyCostThreshold: Double {
        deriveThreshold(from: stats, default: defaultThreshold)
    }

    var todaysCostProgress: Double {
        min(todaysCost / dailyCostThreshold, 1.5)
    }

    var sessionTimeProgress: Double {
        guard let session = activeSession else { return 0 }
        let elapsed = dateProvider.now.timeIntervalSince(session.startTime)
        let total = session.endTime.timeIntervalSince(session.startTime)
        return min(elapsed / total, 1.5)
    }

    var sessionTokenProgress: Double {
        guard let session = activeSession, let limit = autoTokenLimit, limit > 0 else { return 0 }
        return min(Double(session.tokenCounts.total) / Double(limit), 1.5)
    }

    var todaySessionCount: Int {
        activeSession != nil ? 1 : 0
    }

    var estimatedDailySessions: Int {
        guard let stats = stats, !stats.byDate.isEmpty else { return 0 }
        return max(1, stats.totalSessions / stats.byDate.count)
    }

    var averageDailyCost: Double {
        guard let stats = stats, !stats.byDate.isEmpty else { return 0 }
        let recentDays = stats.byDate.suffix(7)
        return recentDays.reduce(0.0) { $0 + $1.totalCost } / Double(recentDays.count)
    }

    var todayHourlyCosts: [Double] {
        UsageAnalytics.todayHourlyCosts(from: todayEntries, referenceDate: dateProvider.now)
    }

    var formattedTodaysCost: String {
        todaysCost.asCurrency
    }

    var formattedTotalCost: String {
        stats?.totalCost.asCurrency ?? "$0.00"
    }

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
        self.defaultThreshold = config.configuration.dailyCostThreshold

        self.refreshCoordinator = RefreshCoordinator(
            dateProvider: dateProvider,
            refreshInterval: config.configuration.refreshInterval
        )

        setupMemoryCleanupObserver()

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

    // MARK: - State Transitions

    private func apply(_ result: TodayLoadResult) {
        activeSession = result.session
        burnRate = result.burnRate
        autoTokenLimit = result.autoTokenLimit
        todayEntries = result.todayEntries

        // Don't regress from .loaded to .loadedToday during refresh
        if case .loaded = state { return }
        state = .loadedToday(result.todayStats)
    }

    private func apply(_ result: FullLoadResult) {
        state = .loaded(result.fullStats)
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

        todayEntries = filterToday(todayEntries, referenceDate: dateProvider.now)

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
