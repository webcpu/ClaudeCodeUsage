//
//  UsageViewModel.swift
//  Refactored view model with proper separation of concerns and concurrency
//

import SwiftUI
import Observation
import ClaudeCodeUsage
// Import specific types from ClaudeLiveMonitorLib to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
import OSLog

private let performanceLogger = Logger(subsystem: "com.claudecodeusage", category: "ViewModelPerformance")

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

// MARK: - Refactored View Model
@Observable
@MainActor
final class UsageViewModel {
    // Observable properties for UI binding
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
    var todayEntries: [UsageEntry] = []  // Store today's raw entries for chart sync
    
    // Additional properties for ModernDashboardView
    var isLoading: Bool {
        if case .loading = state { return true }
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
    
    var totalCost: String {
        guard let stats = stats else { return "$0.00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: stats.totalCost)) ?? "$0.00"
    }
    
    // Dependencies
    private let usageDataService: UsageDataService
    let sessionMonitorService: SessionMonitorService  // Made internal for access
    private let configurationService: ConfigurationService
    private let dateProvider: DateProviding
    
    // Callback for when data is loaded (for syncing chart data)
    var onDataLoaded: (() async -> Void)?
    
    // State management
    private let stateManager = UsageStateManager()
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var dayChangeTask: Task<Void, Never>?
    private var lastKnownDay: String = ""
    private var dayChangeObserver: NSObjectProtocol?
    
    // Computed properties
    var stats: UsageStats? {
        if case .loaded(let stats) = state {
            return stats
        }
        return nil
    }
    
    var todaysCostValue: Double {
        // Calculate from today's entries for consistency with chart
        return todayEntries.reduce(0.0) { $0 + $1.cost }
    }
    
    // MARK: - Initialization
    init(container: DependencyContainer = ProductionContainer.shared, 
         dateProvider: DateProviding = SystemDateProvider()) {
        self.usageDataService = container.usageDataService
        self.sessionMonitorService = container.sessionMonitorService
        self.configurationService = container.configurationService
        self.dateProvider = dateProvider
        
        self.dailyCostThreshold = container.configurationService.configuration.dailyCostThreshold
        
        // Initialize last known day
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.lastKnownDay = formatter.string(from: dateProvider.now)
    }
    
    // MARK: - Public Methods
    func loadData() async {
        let loadStartTime = dateProvider.now
        #if DEBUG
        print("[UsageViewModel] loadData() called at \(dateProvider.now)")
        #endif
        
        await stateManager.cancelCurrentLoad()
        
        let task = Task {
            do {
                // Use structured concurrency to load data in parallel
                async let statsLoading = usageDataService.loadStats()
                async let entriesLoading = usageDataService.loadEntries()  // Also load raw entries
                async let sessionLoading = sessionMonitorService.getActiveSession()
                async let burnRateLoading = sessionMonitorService.getBurnRate()
                async let tokenLimitLoading = sessionMonitorService.getAutoTokenLimit()
                
                // Await all results concurrently
                let (stats, entries, session, burnRate, autoTokenLimit) = try await (
                    statsLoading,
                    entriesLoading,
                    sessionLoading,
                    burnRateLoading,
                    tokenLimitLoading
                )
                
                // Filter for today's entries using same logic as chart
                let calendar = Calendar.current
                let today = dateProvider.startOfDay(for: dateProvider.now)
                let todaysEntries = entries.filter { entry in
                    guard let date = entry.date else { return false }
                    return calendar.isDate(date, inSameDayAs: today)
                }
                
                // Log performance metrics
                let loadDuration = dateProvider.now.timeIntervalSince(loadStartTime)
                if loadDuration > 1.0 {
                    performanceLogger.warning("Slow data load: \(String(format: "%.2f", loadDuration))s | entries=\(stats.byDate.count)")
                } else {
                    performanceLogger.debug("Data loaded in \(String(format: "%.2f", loadDuration))s | entries=\(stats.byDate.count)")
                }
                
                #if DEBUG
                print("[UsageViewModel] Stats loaded: totalCost=\(stats.totalCost), entries=\(stats.byDate.count)")
                print("[UsageViewModel] Today's entries: \(todaysEntries.count) entries")
                let todaysCostFromEntries = todaysEntries.reduce(0.0) { $0 + $1.cost }
                print("[UsageViewModel] Today's cost from entries: $\(String(format: "%.2f", todaysCostFromEntries))")
                
                // Also log what stats.byDate says for today
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let todayString = formatter.string(from: dateProvider.now)
                if let todayFromStats = stats.byDate.first(where: { $0.date == todayString }) {
                    print("[UsageViewModel] Today's cost from stats: $\(String(format: "%.2f", todayFromStats.totalCost))")
                }
                #endif
                
                // Update state manager
                await stateManager.updateStats(stats)
                await stateManager.updateSession(session)
                
                // Update all published properties atomically on MainActor
                await MainActor.run {
                    self.state = .loaded(stats)
                    self.activeSession = session
                    self.burnRate = burnRate
                    self.autoTokenLimit = autoTokenLimit
                    self.todayEntries = todaysEntries  // Store today's entries
                    
                    updateCalculatedProperties(stats: stats)
                }
                
                // Notify that data has been loaded (for chart sync)
                if let onDataLoaded = self.onDataLoaded {
                    await onDataLoaded()
                }
                
            } catch {
                #if DEBUG
                print("[UsageViewModel] Error loading data: \(error)")
                #endif
                
                await MainActor.run {
                    self.state = .error(error)
                }
            }
        }
        
        await stateManager.setLoadTask(task)
        // IMPORTANT: Wait for the task to complete before returning
        await task.value
    }
    
    func startAutoRefresh() {
        stopAutoRefresh()
        
        // Start regular refresh using async/await
        let interval = configurationService.configuration.refreshInterval
        
        timerTask = Task { @MainActor in
            // Initial load
            await loadData()
            
            // Use a clock for more precise timing
            var nextFireTime = ContinuousClock.now + .seconds(interval)
            
            while !Task.isCancelled {
                do {
                    // Sleep until next fire time
                    try await Task.sleep(until: nextFireTime, clock: .continuous)
                    
                    // Check cancellation immediately after sleep
                    guard !Task.isCancelled else { break }
                    
                    await loadData()
                    
                    // Calculate next fire time from the previous one to avoid drift
                    nextFireTime = nextFireTime + .seconds(interval)
                } catch {
                    // Task was cancelled during sleep or clock error
                    break
                }
            }
        }
        
        // Start day change monitoring
        startDayChangeMonitoring()
    }
    
    func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
        stopDayChangeMonitoring()
    }
    
    func refresh() async {
        await loadData()
    }
    
    // MARK: - Day Change Detection
    private func startDayChangeMonitoring() {
        // Remove any existing observer
        stopDayChangeMonitoring()
        
        // Method 1: Use significant time change notification (more reliable)
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                #if DEBUG
                print("[UsageViewModel] Day changed detected via notification at \(self.dateProvider.now)")
                #endif
                
                // Update last known day
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                self.lastKnownDay = formatter.string(from: dateProvider.now)
                
                // Refresh data for the new day
                await self.loadData()
            }
        }
        
        // Method 2: Also monitor for significant time changes (handles manual time changes)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignificantTimeChange),
            name: NSNotification.Name.NSSystemClockDidChange,
            object: nil
        )
        
        #if DEBUG
        print("[UsageViewModel] Day change monitoring started")
        #endif
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
            #if DEBUG
            print("[UsageViewModel] Significant time change detected at \(dateProvider.now)")
            #endif
            
            // Check if the day actually changed
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
        // Today's cost
        let todayValue = todaysCostValue
        todaysCost = todayValue.asCurrency
        todaysCostProgress = min(todayValue / dailyCostThreshold, 1.5)
        
        #if DEBUG
        print("[UsageViewModel] Today's cost updated: \(todaysCost) (value: \(todayValue))")
        print("[UsageViewModel] Total stats cost: \(stats.totalCost)")
        print("[UsageViewModel] Number of daily entries: \(stats.byDate.count)")
        if let todayEntry = stats.byDate.first(where: { 
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return $0.date == formatter.string(from: dateProvider.now)
        }) {
            print("[UsageViewModel] Today's entry found: \(todayEntry.date) = $\(todayEntry.totalCost)")
        }
        #endif
        
        // Session counts
        todaySessionCount = activeSession != nil ? 1 : 0
        estimatedDailySessions = stats.byDate.isEmpty ? 0 : max(1, stats.totalSessions / stats.byDate.count)
        
        // Session progress
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
        
        // Average daily cost
        if !stats.byDate.isEmpty {
            let recentDays = stats.byDate.suffix(7)
            // Single-pass reduction for performance
            let totalRecentCost = recentDays.reduce(0.0) { $0 + $1.totalCost }
            averageDailyCost = totalRecentCost / Double(recentDays.count)
            
            if averageDailyCost > 0 {
                dailyCostThreshold = max(averageDailyCost * 1.5, 10.0)
            }
        }
    }
    
    deinit {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        // Note: dayChangeObserver will be cleaned up automatically
        // Tasks are automatically cancelled when the class is deallocated
    }
}

// MARK: - SwiftUI Environment Extension
extension EnvironmentValues {
    var usageViewModel: UsageViewModel? {
        get { self[UsageViewModelKey.self] }
        set { self[UsageViewModelKey.self] = newValue }
    }
}

private struct UsageViewModelKey: EnvironmentKey {
    static let defaultValue: UsageViewModel? = nil
}