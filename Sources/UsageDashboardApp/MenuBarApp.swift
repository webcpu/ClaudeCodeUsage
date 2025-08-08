//
//  MenuBarApp.swift
//  Refactored data model using @Observable macro
//

import SwiftUI
import Observation
import Combine
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Modern Observable Data Model
@Observable
@MainActor
final class UsageDataModel {
    private let viewModel: UsageViewModel
    
    // Observable state properties
    var isLoading = true
    var hasInitiallyLoaded = false
    var errorMessage: String?
    var lastRefreshTime = Date()
    
    // Stored properties that sync with view model
    var stats: UsageStats?
    var activeSession: SessionBlock?
    var burnRate: BurnRate?
    var autoTokenLimit: Int?
    var todaysCost: String = "$0.00"
    var todaysCostValue: Double = 0.0
    var todaysCostProgress: Double = 0.0
    var sessionTimeProgress: Double = 0.0
    var sessionTokenProgress: Double = 0.0
    var averageDailyCost: Double = 0.0
    var dailyCostThreshold: Double = 10.0
    var todaySessionCount: Int = 0
    var estimatedDailySessions: Int = 0
    
    // Chart data
    var chartDataService = ChartDataService()
    
    private var cancellables = Set<AnyCancellable>()
    
    init(container: DependencyContainer = ProductionContainer.shared) {
        self.viewModel = UsageViewModel(container: container)
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to view model state changes
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                
                switch state {
                case .loading:
                    self.isLoading = true
                case .loaded(let stats):
                    self.isLoading = false
                    self.hasInitiallyLoaded = true
                    self.errorMessage = nil
                    self.stats = stats
                case .error(let error):
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to activeSession changes
        viewModel.$activeSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.activeSession = session
            }
            .store(in: &cancellables)
        
        // Subscribe to burnRate changes
        viewModel.$burnRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.burnRate = rate
            }
            .store(in: &cancellables)
        
        // Subscribe to autoTokenLimit changes
        viewModel.$autoTokenLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] limit in
                self?.autoTokenLimit = limit
            }
            .store(in: &cancellables)
        
        // Subscribe to todaysCost changes - THIS IS THE KEY FIX
        viewModel.$todaysCost
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cost in
                self?.todaysCost = cost
            }
            .store(in: &cancellables)
        
        // Subscribe to progress indicators
        viewModel.$todaysCostProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.todaysCostProgress = progress
            }
            .store(in: &cancellables)
        
        viewModel.$sessionTimeProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.sessionTimeProgress = progress
            }
            .store(in: &cancellables)
        
        viewModel.$sessionTokenProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.sessionTokenProgress = progress
            }
            .store(in: &cancellables)
        
        // Subscribe to daily metrics
        viewModel.$averageDailyCost
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cost in
                self?.averageDailyCost = cost
            }
            .store(in: &cancellables)
        
        viewModel.$dailyCostThreshold
            .receive(on: DispatchQueue.main)
            .sink { [weak self] threshold in
                self?.dailyCostThreshold = threshold
            }
            .store(in: &cancellables)
        
        viewModel.$todaySessionCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.todaySessionCount = count
            }
            .store(in: &cancellables)
        
        viewModel.$estimatedDailySessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.estimatedDailySessions = sessions
            }
            .store(in: &cancellables)
        
        // Compute todaysCostValue from stats
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case .loaded(let stats) = state {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    let todayString = formatter.string(from: Date())
                    
                    if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
                        self.todaysCostValue = todayUsage.totalCost
                    } else {
                        self.todaysCostValue = 0.0
                    }
                }
            }
            .store(in: &cancellables)
    }
    
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