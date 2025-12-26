//
//  UsageStore.swift
//  Single source of truth for usage data (View + Store + Service architecture)
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
    case loaded(UsageStats)
    case error(Error)
}

// MARK: - Actor for Thread-Safe State Management
actor UsageStateManager {
    private var stats: UsageStats?
    private var activeSession: SessionBlock?
    private var loadTask: Task<Void, Never>?

    func updateStats(_ newStats: UsageStats) {
        self.stats = newStats
    }

    func updateSession(_ session: SessionBlock?) {
        self.activeSession = session
    }

    func getStats() -> UsageStats? {
        stats
    }

    func getSession() -> SessionBlock? {
        activeSession
    }

    func setLoadTask(_ task: Task<Void, Never>?) {
        loadTask?.cancel()
        loadTask = task
    }

    func cancelCurrentLoad() {
        loadTask?.cancel()
        loadTask = nil
    }
}

// MARK: - Usage Store (Single Source of Truth)
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

    // Chart data service
    var chartDataService: ChartDataService

    // MARK: - Computed Properties
    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var hasInitiallyLoaded: Bool {
        if case .loaded = state { return true }
        return false
    }

    var lastError: Error? {
        if case .error(let error) = state { return error }
        return nil
    }

    var errorMessage: String? {
        if case .error(let error) = state { return error.localizedDescription }
        return nil
    }

    var stats: UsageStats? {
        if case .loaded(let stats) = state {
            return stats
        }
        return nil
    }

    var todaysCostValue: Double {
        todayEntries.reduce(0.0) { $0 + $1.cost }
    }

    var totalCost: String {
        guard let stats = stats else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: stats.totalCost)) ?? "$0.00"
    }

    var formattedTodaysCost: String? {
        FormatterService.formatCurrency(todaysCostValue)
    }

    var formattedTotalCost: String? {
        stats?.totalCost != nil ? FormatterService.formatCurrency(stats!.totalCost) : nil
    }

    var lastUpdateTime: Date? {
        lastRefreshTime
    }

    // MARK: - Dependencies (Services)
    private let usageDataService: UsageDataService
    let sessionMonitorService: SessionMonitorService
    private let configurationService: ConfigurationService
    private let dateProvider: DateProviding

    // MARK: - Internal State
    private let stateManager = UsageStateManager()
    private var memoryCleanupObserver: NSObjectProtocol?
    private var isCurrentlyLoading = false
    private var lastLoadStartTime: Date?
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var dayChangeTask: Task<Void, Never>?
    private var lastKnownDay: String = ""
    private var dayChangeObserver: NSObjectProtocol?
    private var hasInitialized = false

    // MARK: - Initialization
    init(
        usageDataService: UsageDataService? = nil,
        sessionMonitorService: SessionMonitorService? = nil,
        configurationService: ConfigurationService? = nil,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        let config = configurationService ?? DefaultConfigurationService()
        self.configurationService = config
        self.usageDataService = usageDataService
            ?? DefaultUsageDataService(configuration: config.configuration)
        self.sessionMonitorService = sessionMonitorService
            ?? DefaultSessionMonitorService(configuration: config.configuration)
        self.dateProvider = dateProvider
        self.lastRefreshTime = dateProvider.now
        self.chartDataService = ChartDataService(dateProvider: dateProvider)
        self.dailyCostThreshold = config.configuration.dailyCostThreshold

        // Setup memory cleanup observer
        memoryCleanupObserver = NotificationCenter.default.addObserver(
            forName: .performMemoryCleanup,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryCleanup()
            }
        }

        // Initialize last known day
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.lastKnownDay = formatter.string(from: dateProvider.now)
    }

    // MARK: - Initialization (called once at app start)
    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if !hasInitiallyLoaded {
            await loadData()
        }
        startRefreshTimer()
    }

    // MARK: - Data Loading
    @MainActor
    func loadData() async {
        // Deduplication: Check if already loading
        if isCurrentlyLoading {
            #if DEBUG
            print("[UsageStore] loadData() SKIPPED - already loading")
            #endif
            return
        }

        // Deduplication: Check if loaded very recently (within 0.5 seconds)
        if let lastTime = lastLoadStartTime,
           dateProvider.now.timeIntervalSince(lastTime) < 0.5 {
            #if DEBUG
            print("[UsageStore] loadData() SKIPPED - loaded \(dateProvider.now.timeIntervalSince(lastTime))s ago")
            #endif
            return
        }

        // Mark as loading and record time
        isCurrentlyLoading = true
        lastLoadStartTime = dateProvider.now
        lastRefreshTime = dateProvider.now
        defer { isCurrentlyLoading = false }

        let loadStartTime = dateProvider.now
        #if DEBUG
        print("[UsageStore] loadData() called at \(dateProvider.now)")
        #endif

        do {
            // PHASE 1: Load today's data + session info (FAST)
            let phase1Start = dateProvider.now

            async let todayDataLoading = usageDataService.loadTodayEntriesAndStats()
            async let sessionLoading = sessionMonitorService.getActiveSession()
            async let burnRateLoading = sessionMonitorService.getBurnRate()
            async let tokenLimitLoading = sessionMonitorService.getAutoTokenLimit()

            let ((todaysEntries, todayStats), session, burnRate, autoTokenLimit) = await (
                try todayDataLoading,
                sessionLoading,
                burnRateLoading,
                tokenLimitLoading
            )

            #if DEBUG
            let phase1Time = dateProvider.now.timeIntervalSince(phase1Start)
            print("[UsageStore] Phase 1 (today) completed in: \(String(format: "%.3f", phase1Time))s")
            #endif

            // Update UI immediately with today's data
            self.activeSession = session
            self.burnRate = burnRate
            self.autoTokenLimit = autoTokenLimit
            self.todayEntries = todaysEntries
            updateCalculatedProperties(stats: todayStats)

            // PHASE 2: Load full historical data
            let phase2Start = dateProvider.now
            let (_, fullStats) = try await usageDataService.loadEntriesAndStats()

            #if DEBUG
            let phase2Time = dateProvider.now.timeIntervalSince(phase2Start)
            print("[UsageStore] Phase 2 (full) completed in: \(String(format: "%.3f", phase2Time))s")
            #endif

            // Update state manager with full stats
            await stateManager.updateStats(fullStats)
            await stateManager.updateSession(session)

            // Update UI with full historical data
            self.state = .loaded(fullStats)

            // Update chart data
            await updateChartData()

            let totalTime = dateProvider.now.timeIntervalSince(loadStartTime)
            #if DEBUG
            print("[UsageStore] Total load time: \(String(format: "%.3f", totalTime))s")
            #endif

            if totalTime > 2.0 {
                performanceLogger.warning("Slow data load: \(String(format: "%.2f", totalTime))s")
            }

        } catch {
            #if DEBUG
            print("[UsageStore] Error loading data: \(error)")
            #endif
            self.state = .error(error)
        }
    }

    func refresh() async {
        await loadData()
    }

    // MARK: - Chart Data
    func updateChartData() async {
        await chartDataService.loadHourlyCostsFromEntries(todayEntries)

        #if DEBUG
        if stats != nil {
            let cost = todaysCostValue
            let chartTotal = chartDataService.todayHourlyCosts.reduce(0, +)
            print("[UsageStore] Chart sync - Today's cost: $\(String(format: "%.2f", cost)), Chart total: $\(String(format: "%.2f", chartTotal))")
        }
        #endif
    }

    // MARK: - Auto Refresh
    func startRefreshTimer() {
        stopRefreshTimer()

        let interval = configurationService.configuration.refreshInterval

        timerTask = Task { @MainActor in
            var nextFireTime = ContinuousClock.now + .seconds(interval)

            while !Task.isCancelled {
                do {
                    try await Task.sleep(until: nextFireTime, clock: .continuous)
                    guard !Task.isCancelled else { break }
                    await loadData()
                    nextFireTime = nextFireTime + .seconds(interval)
                } catch {
                    break
                }
            }
        }

        startDayChangeMonitoring()
    }

    func stopRefreshTimer() {
        timerTask?.cancel()
        timerTask = nil
        stopDayChangeMonitoring()
    }

    // MARK: - Lifecycle Events
    func handleAppBecameActive() {
        #if DEBUG
        print("[UsageStore] handleAppBecameActive() called")
        #endif
        let timeSinceLastRefresh = dateProvider.now.timeIntervalSince(lastRefreshTime)
        if timeSinceLastRefresh > 2.0 {
            lastRefreshTime = dateProvider.now
            Task {
                await refresh()
            }
        }
        startRefreshTimer()
    }

    func handleAppResignActive() {
        stopRefreshTimer()
    }

    func handleWindowFocus() {
        #if DEBUG
        print("[UsageStore] handleWindowFocus() called")
        #endif
        let timeSinceLastRefresh = dateProvider.now.timeIntervalSince(lastRefreshTime)
        if timeSinceLastRefresh > 2.0 {
            lastRefreshTime = dateProvider.now
            Task {
                await refresh()
            }
        }
    }

    // MARK: - Day Change Detection
    private func startDayChangeMonitoring() {
        stopDayChangeMonitoring()

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                #if DEBUG
                print("[UsageStore] Day changed detected")
                #endif

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                self.lastKnownDay = formatter.string(from: dateProvider.now)

                await self.loadData()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignificantTimeChange),
            name: NSNotification.Name.NSSystemClockDidChange,
            object: nil
        )
    }

    private func stopDayChangeMonitoring() {
        if let observer = dayChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            dayChangeObserver = nil
        }
        dayChangeTask?.cancel()
        dayChangeTask = nil
    }

    @objc private func handleSignificantTimeChange() {
        Task { @MainActor in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currentDay = formatter.string(from: dateProvider.now)

            if currentDay != lastKnownDay {
                lastKnownDay = currentDay
                await loadData()
            }
        }
    }

    // MARK: - Private Methods
    private func updateCalculatedProperties(stats: UsageStats) {
        let todayValue = todaysCostValue
        todaysCost = todayValue.asCurrency
        todaysCostProgress = min(todayValue / dailyCostThreshold, 1.5)

        todaySessionCount = activeSession != nil ? 1 : 0
        estimatedDailySessions = stats.byDate.isEmpty ? 0 : max(1, stats.totalSessions / stats.byDate.count)

        if let session = activeSession {
            let elapsed = dateProvider.now.timeIntervalSince(session.startTime)
            let total = session.endTime.timeIntervalSince(session.startTime)
            sessionTimeProgress = min(elapsed / total, 1.5)

            if let limit = autoTokenLimit, limit > 0 {
                sessionTokenProgress = min(Double(session.tokenCounts.total) / Double(limit), 1.5)
            }
        } else {
            sessionTimeProgress = 0
            sessionTokenProgress = 0
        }

        if !stats.byDate.isEmpty {
            let recentDays = stats.byDate.suffix(7)
            let totalRecentCost = recentDays.reduce(0.0) { $0 + $1.totalCost }
            averageDailyCost = totalRecentCost / Double(recentDays.count)

            if averageDailyCost > 0 {
                dailyCostThreshold = max(averageDailyCost * 1.5, 10.0)
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

        Task {
            await stateManager.cancelCurrentLoad()
            if activeSession != nil {
                await loadData()
            }
        }

        performanceLogger.info("Memory cleanup completed")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Helper function for token formatting
func formatTokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    } else {
        return "\(count)"
    }
}
