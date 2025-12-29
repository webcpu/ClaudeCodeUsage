//
//  MainView.swift
//  Main window with sidebar navigation
//

import SwiftUI
import ClaudeCodeUsageKit

// MARK: - Main View
struct MainView: View {
    @Environment(UsageStore.self) private var store
    @State private var selectedDestination: Destination? = .overview
    let settingsService: AppSettingsService

    var body: some View {
        NavigationContent(
            selectedDestination: $selectedDestination,
            store: store,
            settingsService: settingsService
        )
    }
}

// MARK: - Navigation Content
private struct NavigationContent: View {
    @Binding var selectedDestination: Destination?
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedDestination: $selectedDestination)
        } detail: {
            DetailView(
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

// MARK: - Sidebar
private struct Sidebar: View {
    @Binding var selectedDestination: Destination?

    var body: some View {
        List(selection: $selectedDestination) {
            NavigationLink(value: Destination.overview) {
                Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationLink(value: Destination.models) {
                Label("Models", systemImage: "cpu")
            }

            NavigationLink(value: Destination.dailyUsage) {
                Label("Daily Usage", systemImage: "calendar")
            }

            NavigationLink(value: Destination.analytics) {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }

            NavigationLink(value: Destination.liveMetrics) {
                Label("Live Metrics", systemImage: "arrow.triangle.2.circlepath")
            }
        }
        .navigationTitle(AppMetadata.name)
        .frame(minWidth: 200)
        .listStyle(.sidebar)
    }
}

// MARK: - Detail View
private struct DetailView: View {
    let destination: Destination
    let store: UsageStore
    let settingsService: AppSettingsService

    var body: some View {
        content
            .frame(minWidth: 700)
    }

    @ViewBuilder
    private var content: some View {
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

// MARK: - Navigation Destination
enum Destination: Hashable {
    case overview
    case models
    case dailyUsage
    case analytics
    case liveMetrics
}
