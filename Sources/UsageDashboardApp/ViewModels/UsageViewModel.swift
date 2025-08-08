//
//  UsageViewModel.swift
//  Refactored view model with proper separation of concerns and concurrency
//

import SwiftUI
import Combine
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

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
@MainActor
final class UsageViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var state: ViewState = .loading
    @Published var activeSession: SessionBlock?
    @Published var burnRate: BurnRate?
    @Published var autoTokenLimit: Int?
    @Published var todaysCost: String = "$0.00"
    @Published var todaysCostProgress: Double = 0.0
    @Published var sessionTimeProgress: Double = 0.0
    @Published var sessionTokenProgress: Double = 0.0
    @Published var averageDailyCost: Double = 0.0
    @Published var dailyCostThreshold: Double = 10.0
    @Published var todaySessionCount: Int = 0
    @Published var estimatedDailySessions: Int = 0
    
    // Dependencies
    private let usageDataService: UsageDataService
    private let sessionMonitorService: SessionMonitorService
    private let configurationService: ConfigurationService
    
    // State management
    private let stateManager = UsageStateManager()
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: AsyncStream<Date>?
    private var timerTask: Task<Void, Never>?
    
    // Computed properties
    var stats: UsageStats? {
        if case .loaded(let stats) = state {
            return stats
        }
        return nil
    }
    
    var todaysCostValue: Double {
        guard let stats = stats else { return 0.0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
            return todayUsage.totalCost
        }
        
        return 0.0
    }
    
    // MARK: - Initialization
    init(container: DependencyContainer = ProductionContainer.shared) {
        self.usageDataService = container.usageDataService
        self.sessionMonitorService = container.sessionMonitorService
        self.configurationService = container.configurationService
        
        self.dailyCostThreshold = container.configurationService.configuration.dailyCostThreshold
    }
    
    // MARK: - Public Methods
    func loadData() async {
        #if DEBUG
        print("[UsageViewModel] loadData() called at \(Date())")
        #endif
        
        await stateManager.cancelCurrentLoad()
        
        let task = Task {
            do {
                // Load usage stats
                let stats = try await usageDataService.loadStats()
                
                #if DEBUG
                print("[UsageViewModel] Stats loaded: totalCost=\(stats.totalCost), entries=\(stats.byDate.count)")
                #endif
                await stateManager.updateStats(stats)
                
                // Load session data
                let session = sessionMonitorService.getActiveSession()
                await stateManager.updateSession(session)
                
                // Update published properties
                await MainActor.run {
                    self.state = .loaded(stats)
                    self.activeSession = session
                    self.burnRate = sessionMonitorService.getBurnRate()
                    self.autoTokenLimit = sessionMonitorService.getAutoTokenLimit()
                    
                    updateCalculatedProperties(stats: stats)
                }
                
            } catch {
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
        
        let interval = configurationService.configuration.refreshInterval
        let stream = AsyncStream<Date> { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                continuation.yield(Date())
            }
            
            continuation.onTermination = { _ in
                timer.invalidate()
            }
        }
        
        timerTask = Task {
            for await _ in stream {
                guard !Task.isCancelled else { break }
                await loadData()
            }
        }
    }
    
    func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    func refresh() async {
        await loadData()
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
            return $0.date == formatter.string(from: Date())
        }) {
            print("[UsageViewModel] Today's entry found: \(todayEntry.date) = $\(todayEntry.totalCost)")
        }
        #endif
        
        // Session counts
        todaySessionCount = activeSession != nil ? 1 : 0
        estimatedDailySessions = stats.byDate.isEmpty ? 0 : max(1, stats.totalSessions / stats.byDate.count)
        
        // Session progress
        if let session = activeSession {
            let elapsed = Date().timeIntervalSince(session.startTime)
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
            let totalRecentCost = recentDays.reduce(0) { $0 + $1.totalCost }
            averageDailyCost = totalRecentCost / Double(recentDays.count)
            
            if averageDailyCost > 0 {
                dailyCostThreshold = max(averageDailyCost * 1.5, 10.0)
            }
        }
    }
    
    deinit {
        // Cancel the timer task directly
        timerTask?.cancel()
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