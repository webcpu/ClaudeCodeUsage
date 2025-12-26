//
//  MenuBarApp.swift
//  Refactored data model using @Observable macro
//

import SwiftUI
import Observation
import ClaudeCodeUsage
// Import specific types from ClaudeLiveMonitorLib to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate

// MARK: - Modern Observable Data Model
@Observable
@MainActor
final class UsageDataModel {
    private let viewModel: UsageViewModel
    private let dateProvider: DateProviding
    private var previousStatsUpdateTime: Date?
    
    // Observable state properties
    var lastRefreshTime: Date
    
    // Computed properties that directly access viewModel
    var isLoading: Bool {
        if case .loading = viewModel.state { return true }
        return false
    }
    
    var hasInitiallyLoaded: Bool {
        if case .loaded = viewModel.state { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let error) = viewModel.state { return error.localizedDescription }
        return nil
    }
    
    var stats: UsageStats? {
        return viewModel.stats
    }
    
    var activeSession: SessionBlock? {
        return viewModel.activeSession
    }
    
    var burnRate: BurnRate? {
        return viewModel.burnRate
    }
    
    var autoTokenLimit: Int? {
        return viewModel.autoTokenLimit
    }
    
    var todaysCost: String {
        return viewModel.todaysCost
    }
    
    var todaysCostValue: Double {
        return viewModel.todaysCostValue
    }
    
    var todaysCostProgress: Double {
        return viewModel.todaysCostProgress
    }
    
    var sessionTimeProgress: Double {
        return viewModel.sessionTimeProgress
    }
    
    var sessionTokenProgress: Double {
        return viewModel.sessionTokenProgress
    }
    
    var averageDailyCost: Double {
        return viewModel.averageDailyCost
    }
    
    var dailyCostThreshold: Double {
        return viewModel.dailyCostThreshold
    }
    
    var todaySessionCount: Int {
        return viewModel.todaySessionCount
    }
    
    var estimatedDailySessions: Int {
        return viewModel.estimatedDailySessions
    }
    
    var todayEntries: [UsageEntry] {
        return viewModel.todayEntries
    }
    
    // Formatted values for display
    var formattedTodaysCost: String? {
        return FormatterService.formatCurrency(todaysCostValue)
    }
    
    var formattedTotalCost: String? {
        return stats?.totalCost != nil ? FormatterService.formatCurrency(stats!.totalCost) : nil
    }
    
    var lastUpdateTime: Date? {
        return lastRefreshTime
    }
    
    // Chart data
    var chartDataService: ChartDataService
    
    init(container: DependencyContainer = ProductionContainer.shared,
         dateProvider: DateProviding = SystemDateProvider()) {
        self.dateProvider = dateProvider
        self.lastRefreshTime = dateProvider.now
        self.chartDataService = ChartDataService(dateProvider: dateProvider)
        self.viewModel = UsageViewModel(container: container, dateProvider: dateProvider)
        
        // Set up callback to sync chart data whenever main data loads
        self.viewModel.onDataLoaded = { [weak self] in
            guard let self = self else { return }
            await self.updateChartData()
        }
    }
    
    // With @Observable, we can directly access viewModel properties without manual binding
    
    func loadData() async {
        lastRefreshTime = dateProvider.now
        await viewModel.loadData()
        // Load chart data from the same stats that were just loaded
        await updateChartData()
    }
    
    func startRefreshTimer() {
        // Don't perform initial load - assume data was just loaded by initializeIfNeeded
        viewModel.startAutoRefresh(performInitialLoad: false)
    }
    
    func stopRefreshTimer() {
        viewModel.stopAutoRefresh()
    }
    
    func handleAppBecameActive() {
        #if DEBUG
        print("[UsageDataModel] handleAppBecameActive() called")
        #endif
        // Only refresh if we haven't loaded recently (within last 2 seconds)
        let timeSinceLastRefresh = dateProvider.now.timeIntervalSince(lastRefreshTime)
        #if DEBUG
        print("[UsageDataModel] Time since last refresh: \(timeSinceLastRefresh)s")
        #endif
        if timeSinceLastRefresh > 2.0 {
            // Update refresh time immediately to prevent duplicate calls
            lastRefreshTime = dateProvider.now
            Task {
                await viewModel.refresh()
                // Sync chart data after refresh
                await updateChartData()
            }
        }
        // Don't perform initial load - we may have just refreshed above
        viewModel.startAutoRefresh(performInitialLoad: false)
    }
    
    func handleAppResignActive() {
        viewModel.stopAutoRefresh()
    }
    
    func handleWindowFocus() {
        #if DEBUG
        print("[UsageDataModel] handleWindowFocus() called")
        #endif
        // Only refresh if we haven't loaded recently (within last 2 seconds)
        let timeSinceLastRefresh = dateProvider.now.timeIntervalSince(lastRefreshTime)
        #if DEBUG
        print("[UsageDataModel] Time since last refresh: \(timeSinceLastRefresh)s")
        #endif
        if timeSinceLastRefresh > 2.0 {
            // Update refresh time immediately to prevent duplicate calls
            lastRefreshTime = dateProvider.now
            Task {
                await viewModel.refresh()
                // Sync chart data after refresh
                await updateChartData()
            }
        }
    }
    
    // Update chart data from current entries
    func updateChartData() async {
        // Pass entries directly to chart service - no disk fetch needed!
        await chartDataService.loadHourlyCostsFromEntries(viewModel.todayEntries)
        
        #if DEBUG
        if viewModel.stats != nil {
            let todaysCost = viewModel.todaysCostValue
            let chartTotal = chartDataService.todayHourlyCosts.reduce(0, +)
            print("[UsageDataModel] Chart sync - Today's cost: $\(String(format: "%.2f", todaysCost)), Chart total: $\(String(format: "%.2f", chartTotal))")
            if abs(todaysCost - chartTotal) > 0.01 {
                print("[UsageDataModel] WARNING: Chart total doesn't match today's cost!")
            }
        }
        #endif
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