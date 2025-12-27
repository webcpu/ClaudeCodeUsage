//
//  DashboardView.swift
//  Main dashboard with sidebar navigation
//

import SwiftUI
import ClaudeCodeUsageKit

// MARK: - Navigation Destination
enum DashboardDestination: Hashable {
    case overview
    case models
    case dailyUsage
    case analytics
    case liveMetrics
}

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(UsageStore.self) private var store
    @State private var selectedDestination: DashboardDestination? = .overview
    let settingsService: AppSettingsService

    var body: some View {
        DashboardNavigationView(
            selectedDestination: $selectedDestination,
            store: store,
            settingsService: settingsService
        )
    }
}

// MARK: - Dashboard Navigation
private struct DashboardNavigationView: View {
    @Binding var selectedDestination: DashboardDestination?
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        NavigationSplitView {
            DashboardSidebar(selectedDestination: $selectedDestination)
        } detail: {
            DashboardDetailView(
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

// MARK: - Dashboard Sidebar
private struct DashboardSidebar: View {
    @Binding var selectedDestination: DashboardDestination?

    var body: some View {
        List(selection: $selectedDestination) {
            NavigationLink(value: DashboardDestination.overview) {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationLink(value: DashboardDestination.models) {
                Label("Models", systemImage: "cpu")
            }

            NavigationLink(value: DashboardDestination.dailyUsage) {
                Label("Daily Usage", systemImage: "calendar")
            }

            NavigationLink(value: DashboardDestination.analytics) {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }

            NavigationLink(value: DashboardDestination.liveMetrics) {
                Label("Live Metrics", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle("Usage Dashboard")
        .frame(minWidth: 200)
        .listStyle(.sidebar)
    }
}

// MARK: - Dashboard Detail View
private struct DashboardDetailView: View {
    let destination: DashboardDestination
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        switch destination {
        case .overview:
            OverviewView()
                .environment(store)
        case .models:
            ModelsView()
                .environment(store)
        case .dailyUsage:
            DailyUsageView()
                .environment(store)
        case .analytics:
            AnalyticsView()
                .environment(store)
        case .liveMetrics:
            MenuBarContentView(settingsService: settingsService, viewMode: .liveMetrics)
                .environment(store)
        }
    }
}