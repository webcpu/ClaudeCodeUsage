//
//  MenuBarApp.swift
//  Simplified shared data model using the new architecture
//

import SwiftUI
import Combine
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Legacy UsageDataModel (for backward compatibility)
// This is a thin wrapper around the new UsageViewModel to maintain compatibility
// while we transition to the new architecture
@MainActor
class UsageDataModel: ObservableObject {
    private let viewModel: UsageViewModel
    
    // Delegate published properties to view model
    var stats: UsageStats? { viewModel.stats }
    var activeSession: SessionBlock? { viewModel.activeSession }
    var burnRate: BurnRate? { viewModel.burnRate }
    var autoTokenLimit: Int? { viewModel.autoTokenLimit }
    var todaysCost: String { viewModel.todaysCost }
    var todaysCostValue: Double { viewModel.todaysCostValue }
    var todaysCostProgress: Double { viewModel.todaysCostProgress }
    var sessionTimeProgress: Double { viewModel.sessionTimeProgress }
    var sessionTokenProgress: Double { viewModel.sessionTokenProgress }
    var averageDailyCost: Double { viewModel.averageDailyCost }
    var dailyCostThreshold: Double { viewModel.dailyCostThreshold }
    var todaySessionCount: Int { viewModel.todaySessionCount }
    var estimatedDailySessions: Int { viewModel.estimatedDailySessions }
    
    @Published var isLoading = true
    @Published var hasInitiallyLoaded = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime = Date()
    
    init(container: DependencyContainer = ProductionContainer.shared) {
        self.viewModel = UsageViewModel(container: container)
        
        // Subscribe to view model state changes
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .loading:
                    self?.isLoading = true
                case .loaded:
                    self?.isLoading = false
                    self?.hasInitiallyLoaded = true
                    self?.errorMessage = nil
                case .error(let error):
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Subscribe to other changes
        viewModel.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadData() async {
        lastRefreshTime = Date()
        await viewModel.loadData()
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