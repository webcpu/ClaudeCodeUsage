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
    @EnvironmentObject var dataModel: UsageDataModel
    @State private var selectedDestination: NavigationDestination? = .overview
    
    var body: some View {
        if #available(macOS 13.0, *) {
            ModernNavigationView(
                selectedDestination: $selectedDestination,
                dataModel: dataModel
            )
        } else {
            LegacyNavigationView(
                selectedDestination: $selectedDestination,
                dataModel: dataModel
            )
        }
    }
}

// MARK: - Modern Navigation (macOS 13+)
@available(macOS 13.0, *)
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

// MARK: - Legacy Navigation (macOS 12)
struct LegacyNavigationView: View {
    @Binding var selectedDestination: NavigationDestination?
    let dataModel: UsageDataModel
    
    var body: some View {
        NavigationView {
            NavigationSidebar(selectedDestination: $selectedDestination)
            
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
        if #available(macOS 13.0, *) {
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
        } else {
            List {
                Button(action: { selectedDestination = .overview }) {
                    Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.plain)
                .background(selectedDestination == .overview ? Color.accentColor.opacity(0.2) : Color.clear)
                
                Button(action: { selectedDestination = .models }) {
                    Label("Models", systemImage: "cpu")
                }
                .buttonStyle(.plain)
                .background(selectedDestination == .models ? Color.accentColor.opacity(0.2) : Color.clear)
                
                Button(action: { selectedDestination = .dailyUsage }) {
                    Label("Daily Usage", systemImage: "calendar")
                }
                .buttonStyle(.plain)
                .background(selectedDestination == .dailyUsage ? Color.accentColor.opacity(0.2) : Color.clear)
                
                Button(action: { selectedDestination = .analytics }) {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
                .buttonStyle(.plain)
                .background(selectedDestination == .analytics ? Color.accentColor.opacity(0.2) : Color.clear)
            }
            .navigationTitle("Usage Dashboard")
            .frame(minWidth: 200)
            .listStyle(.sidebar)
        }
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
                .environmentObject(dataModel)
        case .models:
            ModelsScreen()
                .environmentObject(dataModel)
        case .dailyUsage:
            DailyUsageScreen()
                .environmentObject(dataModel)
        case .analytics:
            AnalyticsScreen()
                .environmentObject(dataModel)
        case .liveMetrics:
            if #available(macOS 13.0, *) {
                MenuBarContentView()
                    .environmentObject(dataModel)
            } else {
                Text("Live Metrics requires macOS 13.0 or later")
                    .foregroundColor(.secondary)
            }
        }
    }
}