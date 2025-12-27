//
//  UsageStore.swift
//  Observable state container for usage data
//

import SwiftUI
import Observation
import ClaudeCodeUsageKit
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

// MARK: - View State

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
        let elapsed = clock.now.timeIntervalSince(session.startTime)
        let total = session.endTime.timeIntervalSince(session.startTime)
        return min(elapsed / total, 1.5)
    }

    var averageDailyCost: Double {
        guard let stats = stats, !stats.byDate.isEmpty else { return 0 }
        let recentDays = stats.byDate.suffix(7)
        return recentDays.reduce(0.0) { $0 + $1.totalCost } / Double(recentDays.count)
    }

    var todayHourlyCosts: [Double] {
        UsageAnalytics.todayHourlyCosts(from: todayEntries, referenceDate: clock.now)
    }

    var formattedTodaysCost: String {
        todaysCost.asCurrency
    }

    // MARK: - Dependencies

    private let dataLoader: UsageDataLoader
    private let clock: any ClockProtocol
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
        clock: any ClockProtocol = SystemClock()
    ) {
        let config = configurationService ?? DefaultConfigurationService()
        let repo = repository ?? UsageRepository(basePath: config.configuration.basePath)
        let sessionService = sessionMonitorService ?? DefaultSessionMonitorService(configuration: config.configuration)

        self.dataLoader = UsageDataLoader(repository: repo, sessionMonitorService: sessionService)
        self.clock = clock
        self.defaultThreshold = config.configuration.dailyCostThreshold
        self.refreshCoordinator = RefreshCoordinator(
            clock: clock,
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

        if !state.hasLoaded {
            await loadData()
        }
        refreshCoordinator.start()
    }

    func loadData() async {
        guard !isCurrentlyLoading, !isLoadedRecently else { return }

        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }

        lastLoadStartTime = clock.now
        _ = await LoadTrace.shared.start()

        do {
            let todayResult = try await dataLoader.loadToday()
            apply(todayResult)

            let historyResult = try await dataLoader.loadHistory()
            apply(historyResult)

            await LoadTrace.shared.complete()
        } catch {
            state = .error(error)
        }
    }

    // MARK: - State Transitions

    private func apply(_ result: TodayLoadResult) {
        activeSession = result.session
        burnRate = result.burnRate
        todayEntries = result.todayEntries

        if case .loaded = state { return }
        state = .loadedToday(result.todayStats)
    }

    private func apply(_ result: FullLoadResult) {
        state = .loaded(result.fullStats)
    }

    func refresh() async {
        await loadData()
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
        todayEntries = filterToday(todayEntries, referenceDate: clock.now)

        if activeSession != nil {
            Task { await loadData() }
        }
    }

    // MARK: - Helpers

    private var isLoadedRecently: Bool {
        guard let lastTime = lastLoadStartTime else { return false }
        return clock.now.timeIntervalSince(lastTime) < 0.5
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
