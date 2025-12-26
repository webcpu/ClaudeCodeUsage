//
//  ModernDashboardView.swift
//  NavigationSplitView implementation for multi-column dashboard
//

import SwiftUI
import Charts
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Navigation Items

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case usage = "Usage"
    case costs = "Costs"
    case sessions = "Sessions"
    case projects = "Projects"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .usage: return "chart.bar"
        case .costs: return "dollarsign.circle"
        case .sessions: return "clock"
        case .projects: return "folder"
        case .settings: return "gear"
        }
    }
}

// MARK: - Main Dashboard View

struct ModernDashboardView: View {
    @State private var viewModel = UsageViewModel()
    @State private var selectedSection: DashboardSection? = .overview
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            SidebarView(
                selectedSection: $selectedSection,
                searchText: $searchText
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            // Content area
            ContentView(
                section: selectedSection ?? .overview,
                viewModel: viewModel,
                searchText: searchText
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            // Detail view
            DetailView(
                section: selectedSection ?? .overview,
                viewModel: viewModel
            )
        }
        .navigationTitle("Claude Usage Dashboard")
        .task {
            await viewModel.loadData()
        }
        .onAppear {
            // Don't perform initial load since we already load in .task
            viewModel.startAutoRefresh(performInitialLoad: false)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedSection: DashboardSection?
    @Binding var searchText: String
    @State private var isSearching = false
    
    var body: some View {
        List(selection: $selectedSection) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            
            // Navigation sections
            Section("Dashboard") {
                ForEach(DashboardSection.allCases.filter { $0 != .settings }) { section in
                    NavigationLink(value: section) {
                        Label(section.rawValue, systemImage: section.icon)
                    }
                }
            }
            
            Divider()
            
            // Settings at bottom
            NavigationLink(value: DashboardSection.settings) {
                Label("Settings", systemImage: "gear")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Claude Usage")
    }
}

// MARK: - Content View

struct ContentView: View {
    let section: DashboardSection
    let viewModel: UsageViewModel
    let searchText: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section header
                Text(section.rawValue)
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                // Section-specific content
                Group {
                    switch section {
                    case .overview:
                        OverviewContent(viewModel: viewModel)
                    case .usage:
                        UsageContent(viewModel: viewModel, searchText: searchText)
                    case .costs:
                        CostsContent(viewModel: viewModel)
                    case .sessions:
                        SessionsContent(viewModel: viewModel)
                    case .projects:
                        ProjectsContent(viewModel: viewModel, searchText: searchText)
                    case .settings:
                        SettingsContent()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .emptyState(when: shouldShowEmptyState) {
            emptyStateView
        }
        .loadingOverlay(isLoading: viewModel.isLoading)
        .errorOverlay(error: viewModel.lastError) {
            await viewModel.loadData()
        }
    }
    
    private var shouldShowEmptyState: Bool {
        !viewModel.isLoading && viewModel.stats == nil
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        switch section {
        case .overview, .usage, .costs:
            NoUsageDataView {
                await viewModel.loadData()
            }
        case .sessions:
            NoActiveSessionView()
        case .projects:
            if searchText.isEmpty {
                NoProjectsView()
            } else {
                NoSearchResultsView(searchQuery: searchText) {
                    // Clear search handled by parent
                }
            }
        case .settings:
            EmptyView()
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    let section: DashboardSection
    let viewModel: UsageViewModel
    @State private var selectedTimeRange = TimeRange.last7Days
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Time range selector
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Detail content based on section
                Group {
                    switch section {
                    case .overview:
                        OverviewCharts(viewModel: viewModel, timeRange: selectedTimeRange)
                    case .usage:
                        UsageCharts(viewModel: viewModel, timeRange: selectedTimeRange)
                    case .costs:
                        CostCharts(viewModel: viewModel, timeRange: selectedTimeRange)
                    case .sessions:
                        SessionDetails(viewModel: viewModel)
                    case .projects:
                        ProjectDetails(viewModel: viewModel)
                    case .settings:
                        SettingsDetails()
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await viewModel.loadData() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh data")
            }
        }
    }
}

// MARK: - Content Views

struct OverviewContent: View {
    let viewModel: UsageViewModel
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: "Today's Cost",
                value: viewModel.todaysCost,
                icon: "calendar",
                color: .blue
            )
            
            StatCard(
                title: "Total Cost",
                value: viewModel.totalCost,
                icon: "dollarsign.circle",
                color: .green
            )
            
            if let stats = viewModel.stats {
                StatCard(
                    title: "Total Tokens",
                    value: "\(stats.totalTokens.formatted())",
                    icon: "text.badge.plus",
                    color: .orange
                )
                
                StatCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "clock",
                    color: .purple
                )
            }
        }
    }
}

struct UsageContent: View {
    let viewModel: UsageViewModel
    let searchText: String
    
    var body: some View {
        if let stats = viewModel.stats {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredModels(stats.byModel), id: \.model) { modelUsage in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(modelUsage.model)
                                .font(.headline)
                            Text("\(modelUsage.totalTokens.formatted()) tokens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("$\(modelUsage.totalCost, specifier: "%.2f")")
                            .font(.subheadline)
                            .bold()
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func filteredModels(_ models: [ModelUsage]) -> [ModelUsage] {
        guard !searchText.isEmpty else { return models }
        return models.filter { $0.model.localizedCaseInsensitiveContains(searchText) }
    }
}

struct CostsContent: View {
    let viewModel: UsageViewModel
    
    var body: some View {
        if let stats = viewModel.stats {
            VStack(alignment: .leading, spacing: 16) {
                // Daily costs list
                Text("Recent Daily Costs")
                    .font(.headline)
                
                ForEach(Array(stats.byDate.prefix(7)), id: \.date) { daily in
                    HStack {
                        Text(daily.date)
                            .font(.subheadline)
                        Spacer()
                        Text("$\(daily.totalCost, specifier: "%.2f")")
                            .font(.subheadline)
                            .bold()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct SessionsContent: View {
    let viewModel: UsageViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session = viewModel.activeSession {
                ActiveSessionCard(session: session)
            } else {
                Text("No active session")
                    .foregroundStyle(.secondary)
            }
            
            if let burnRate = viewModel.burnRate {
                BurnRateCard(burnRate: burnRate)
            }
        }
    }
}

struct ProjectsContent: View {
    let viewModel: UsageViewModel
    let searchText: String
    
    var body: some View {
        if let stats = viewModel.stats {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filteredProjects(stats.byProject), id: \.projectName) { project in
                    ProjectCard(project: project)
                }
            }
        }
    }
    
    private func filteredProjects(_ projects: [ProjectUsage]) -> [ProjectUsage] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.projectName.localizedCaseInsensitiveContains(searchText) }
    }
}

struct SettingsContent: View {
    @AppStorage("refreshInterval") private var refreshInterval = 30.0
    @AppStorage("enableNotifications") private var enableNotifications = false
    @AppStorage("dailyCostThreshold") private var dailyCostThreshold = 10.0
    
    var body: some View {
        Form {
            Section("Refresh") {
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Text("\(Int(refreshInterval)) seconds")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $refreshInterval, in: 10...120, step: 10)
            }
            
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $enableNotifications)
                
                HStack {
                    Text("Daily Cost Alert")
                    Spacer()
                    Text("$\(dailyCostThreshold, specifier: "%.0f")")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $dailyCostThreshold, in: 5...100, step: 5)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ActiveSessionCard: View {
    let session: SessionBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Session")
                .font(.headline)
            
            HStack {
                Label("\(session.models.first ?? "Unknown")", systemImage: "cpu")
                Spacer()
                Text("$\(session.costUSD, specifier: "%.4f")")
                    .bold()
            }
            
            Text("Started \(session.startTime.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

struct BurnRateCard: View {
    let burnRate: BurnRate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Burn Rate")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(burnRate.tokensPerMinute) tokens/min")
                    Text("$\(burnRate.costPerHour, specifier: "%.2f")/hour")
                }
                .font(.caption)
                
                Spacer()
                
                Image(systemName: "flame")
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ProjectCard: View {
    let project: ProjectUsage
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(project.projectName)
                    .font(.headline)
                Text("\(project.totalTokens.formatted()) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(project.totalCost, specifier: "%.2f")")
                    .font(.subheadline)
                    .bold()
                Text(project.lastUsedDate?.formatted(.relative(presentation: .named)) ?? project.lastUsed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Chart Views (Placeholders)

struct OverviewCharts: View {
    let viewModel: UsageViewModel
    let timeRange: TimeRange
    
    var body: some View {
        Text("Overview charts for \(timeRange.displayName)")
            .foregroundStyle(.secondary)
    }
}

struct UsageCharts: View {
    let viewModel: UsageViewModel
    let timeRange: TimeRange
    
    var body: some View {
        Text("Usage charts for \(timeRange.displayName)")
            .foregroundStyle(.secondary)
    }
}

struct CostCharts: View {
    let viewModel: UsageViewModel
    let timeRange: TimeRange
    
    var body: some View {
        Text("Cost charts for \(timeRange.displayName)")
            .foregroundStyle(.secondary)
    }
}

struct SessionDetails: View {
    let viewModel: UsageViewModel
    
    var body: some View {
        Text("Session details")
            .foregroundStyle(.secondary)
    }
}

struct ProjectDetails: View {
    let viewModel: UsageViewModel
    
    var body: some View {
        Text("Project details")
            .foregroundStyle(.secondary)
    }
}

struct SettingsDetails: View {
    var body: some View {
        Text("Settings details")
            .foregroundStyle(.secondary)
    }
}

// MARK: - Preview

#if DEBUG
struct ModernDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ModernDashboardView()
    }
}
#endif
