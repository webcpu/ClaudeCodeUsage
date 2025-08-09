//
//  MenuBarApp.swift
//  Refactored data model using @Observable macro
//

import SwiftUI
import Observation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Modern Observable Data Model
@Observable
@MainActor
final class UsageDataModel {
    private let viewModel: UsageViewModel
    
    // Observable state properties
    var lastRefreshTime = Date()
    
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
    
    // Chart data
    var chartDataService = ChartDataService()
    
    init(container: DependencyContainer = ProductionContainer.shared) {
        self.viewModel = UsageViewModel(container: container)
    }
    
    // With @Observable, we can directly access viewModel properties without manual binding
    
    func loadData() async {
        lastRefreshTime = Date()
        await viewModel.loadData()
        await chartDataService.loadTodayHourlyCosts()
    }
    
    func startRefreshTimer() {
        viewModel.startAutoRefresh()
    }
    
    func stopRefreshTimer() {
        viewModel.stopAutoRefresh()
    }
    
    func handleAppBecameActive() {
        Task {
            await viewModel.refresh()
        }
        viewModel.startAutoRefresh()
    }
    
    func handleAppResignActive() {
        viewModel.stopAutoRefresh()
    }
    
    func handleWindowFocus() {
        Task {
            await viewModel.refresh()
        }
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