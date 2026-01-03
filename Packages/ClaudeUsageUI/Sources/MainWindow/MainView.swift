//
//  MainView.swift
//  Main window with sidebar navigation
//

import SwiftUI
import ClaudeUsageCore

// MARK: - Notification Names

public extension Notification.Name {
    static let refreshData = Notification.Name("refreshData")
}

// MARK: - Main View
public struct MainView: View {
    @Environment(UsageStore.self) private var store
    @State private var selectedDestination: Destination?

    public init(initialDestination: Destination = .overview) {
        self._selectedDestination = State(initialValue: initialDestination)
    }

    public var body: some View {
        NavigationContent(
            selectedDestination: $selectedDestination,
            store: store
        )
        .task { await store.initializeIfNeeded() }
    }
}

// MARK: - Navigation Content
private struct NavigationContent: View {
    @Binding var selectedDestination: Destination?
    @Environment(\.isCaptureMode) private var isCaptureMode
    let store: UsageStore

    var body: some View {
        if isCaptureMode {
            captureLayout
        } else {
            navigationLayout
        }
    }

    private var navigationLayout: some View {
        NavigationSplitView {
            Sidebar(selectedDestination: $selectedDestination)
        } detail: {
            DetailView(destination: selectedDestination ?? .overview, store: store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshData)) { _ in
            Task {
                await store.loadData()
            }
        }
    }

    private var captureLayout: some View {
        HStack(spacing: 0) {
            StaticSidebar(selectedDestination: selectedDestination ?? .overview)
            Divider()
            DetailView(destination: selectedDestination ?? .overview, store: store)
        }
    }
}

// MARK: - Static Sidebar (for capture mode)
private struct StaticSidebar: View {
    let selectedDestination: Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AppMetadata.name)
                .font(.headline)
                .padding()
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Destination.allCases, id: \.self) { dest in
                    row(for: dest)
                }
            }
            .padding(.horizontal, 8)
            Spacer()
        }
        .frame(width: 200)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func row(for dest: Destination) -> some View {
        HStack {
            Label(dest.title, systemImage: dest.icon)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(dest == selectedDestination ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
    }
}

// MARK: - Sidebar
private struct Sidebar: View {
    @Binding var selectedDestination: Destination?

    var body: some View {
        List(selection: $selectedDestination) {
            ForEach(Destination.allCases, id: \.self) { dest in
                NavigationLink(value: dest) {
                    Label(dest.title, systemImage: dest.icon)
                }
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

    var body: some View {
        destination.makeView()
            .environment(store)
            .frame(minWidth: 700)
    }
}

// MARK: - Navigation Destination
public enum Destination: Hashable, CaseIterable {
    case overview
    case models
    case dailyUsage
    case analytics
    case liveMetrics

    var title: String {
        switch self {
        case .overview: "Overview"
        case .models: "Models"
        case .dailyUsage: "Daily Usage"
        case .analytics: "Analytics"
        case .liveMetrics: "Live Metrics"
        }
    }

    var icon: String {
        switch self {
        case .overview: "chart.line.uptrend.xyaxis"
        case .models: "cpu"
        case .dailyUsage: "calendar"
        case .analytics: "chart.bar.xaxis"
        case .liveMetrics: "arrow.triangle.2.circlepath"
        }
    }

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .overview:
            OverviewView()
        case .models:
            ModelsView()
        case .dailyUsage:
            DailyUsageView()
        case .analytics:
            AnalyticsView()
        case .liveMetrics:
            MenuBarContentView(viewMode: .liveMetrics)
        }
    }
}

