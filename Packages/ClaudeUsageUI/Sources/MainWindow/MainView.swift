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

// MARK: - Destination Descriptor

/// Holds all properties for a navigation destination, enabling OCP compliance.
/// Adding a new destination requires only adding an entry to the registry.
@MainActor
private struct DestinationDescriptor {
    let title: String
    let icon: String
    let viewBuilder: @MainActor () -> AnyView

    static let registry: [Destination: DestinationDescriptor] = [
        .overview: DestinationDescriptor(
            title: "Overview",
            icon: "chart.line.uptrend.xyaxis",
            viewBuilder: { AnyView(OverviewView()) }
        ),
        .models: DestinationDescriptor(
            title: "Models",
            icon: "cpu",
            viewBuilder: { AnyView(ModelsView()) }
        ),
        .dailyUsage: DestinationDescriptor(
            title: "Daily Usage",
            icon: "calendar",
            viewBuilder: { AnyView(DailyUsageView()) }
        ),
        .analytics: DestinationDescriptor(
            title: "Analytics",
            icon: "chart.bar.xaxis",
            viewBuilder: { AnyView(AnalyticsView()) }
        ),
        .liveMetrics: DestinationDescriptor(
            title: "Live Metrics",
            icon: "arrow.triangle.2.circlepath",
            viewBuilder: { AnyView(MenuBarContentView(viewMode: .liveMetrics)) }
        )
    ]
}

// MARK: - Navigation Destination

public enum Destination: Hashable, CaseIterable, Sendable {
    case overview
    case models
    case dailyUsage
    case analytics
    case liveMetrics

    @MainActor
    private var descriptor: DestinationDescriptor {
        guard let descriptor = DestinationDescriptor.registry[self] else {
            fatalError("Missing descriptor for destination: \(self)")
        }
        return descriptor
    }

    @MainActor var title: String { descriptor.title }

    @MainActor var icon: String { descriptor.icon }

    @MainActor func makeView() -> some View { descriptor.viewBuilder() }
}

