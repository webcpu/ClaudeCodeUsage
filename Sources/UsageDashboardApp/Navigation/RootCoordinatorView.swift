//
//  RootCoordinatorView.swift
//  Navigation coordinator for the main window
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - Navigation Destination
enum NavigationDestination: Hashable {
    case overview
    case models
    case dailyUsage
    case analytics
    case liveMetrics
}

// MARK: - Root Coordinator View
struct RootCoordinatorView: View {
    @Environment(UsageDataModel.self) private var dataModel
    @State private var selectedDestination: NavigationDestination? = .overview
    
    var body: some View {
        ModernNavigationView(
            selectedDestination: $selectedDestination,
            dataModel: dataModel
        )
    }
}

// MARK: - Modern Navigation
struct ModernNavigationView: View {
    @Binding var selectedDestination: NavigationDestination?
    let dataModel: UsageDataModel
    
    var body: some View {
        NavigationSplitView {
            NavigationSidebar(selectedDestination: $selectedDestination)
        } detail: {
            NavigationDetailView(
                destination: selectedDestination ?? .overview,
                dataModel: dataModel
            )
        }
        .task {
            await dataModel.loadData()
            dataModel.startRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshData)) { _ in
            Task {
                await dataModel.loadData()
            }
        }
        .onDisappear {
            dataModel.stopRefreshTimer()
        }
    }
}


// MARK: - Navigation Sidebar
struct NavigationSidebar: View {
    @Binding var selectedDestination: NavigationDestination?
    
    var body: some View {
        List(selection: $selectedDestination) {
            NavigationLink(value: NavigationDestination.overview) {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            NavigationLink(value: NavigationDestination.models) {
                Label("Models", systemImage: "cpu")
            }
            
            NavigationLink(value: NavigationDestination.dailyUsage) {
                Label("Daily Usage", systemImage: "calendar")
            }
            
            NavigationLink(value: NavigationDestination.analytics) {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }
            
            NavigationLink(value: NavigationDestination.liveMetrics) {
                Label("Live Metrics", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle("Usage Dashboard")
        .frame(minWidth: 200)
        .listStyle(.sidebar)
    }
}

// MARK: - Navigation Detail View
struct NavigationDetailView: View {
    let destination: NavigationDestination
    let dataModel: UsageDataModel
    
    var body: some View {
        switch destination {
        case .overview:
            OverviewScreen()
                .environment(dataModel)
        case .models:
            ModelsScreen()
                .environment(dataModel)
        case .dailyUsage:
            DailyUsageScreen()
                .environment(dataModel)
        case .analytics:
            AnalyticsScreen()
                .environment(dataModel)
        case .liveMetrics:
            MenuBarContentView()
                .environment(dataModel)
        }
    }
}