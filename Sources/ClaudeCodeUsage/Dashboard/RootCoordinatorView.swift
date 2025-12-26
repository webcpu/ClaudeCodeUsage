//
//  RootCoordinatorView.swift
//  Navigation coordinator for the main window
//

import SwiftUI
import ClaudeCodeUsageKit

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
    @Environment(UsageStore.self) private var store
    @State private var selectedDestination: NavigationDestination? = .overview
    let settingsService: AppSettingsService

    var body: some View {
        ModernNavigationView(
            selectedDestination: $selectedDestination,
            store: store,
            settingsService: settingsService
        )
    }
}

// MARK: - Modern Navigation
struct ModernNavigationView: View {
    @Binding var selectedDestination: NavigationDestination?
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        NavigationSplitView {
            NavigationSidebar(selectedDestination: $selectedDestination)
        } detail: {
            NavigationDetailView(
                destination: selectedDestination ?? .overview,
                store: store,
                settingsService: settingsService
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshData)) { _ in
            Task {
                await store.loadData()
            }
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
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        switch destination {
        case .overview:
            OverviewScreen()
                .environment(store)
        case .models:
            ModelsScreen()
                .environment(store)
        case .dailyUsage:
            DailyUsageScreen()
                .environment(store)
        case .analytics:
            AnalyticsScreen()
                .environment(store)
        case .liveMetrics:
            MenuBarContentView(settingsService: settingsService, viewMode: .liveMetrics)
                .environment(store)
        }
    }
}