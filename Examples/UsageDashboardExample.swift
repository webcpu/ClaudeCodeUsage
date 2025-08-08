//
//  UsageDashboardExample.swift
//  ClaudeUsageSDK Example
//
//  Example SwiftUI application demonstrating the SDK
//

import SwiftUI
import ClaudeCodeUsage

// MARK: - Main App

@main
struct UsageDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var viewModel = UsageDashboardViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTab(viewModel: viewModel)
                .tabItem {
                    Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(0)
            
            ModelsTab(viewModel: viewModel)
                .tabItem {
                    Label("By Model", systemImage: "cpu")
                }
                .tag(1)
            
            ProjectsTab(viewModel: viewModel)
                .tabItem {
                    Label("By Project", systemImage: "folder")
                }
                .tag(2)
            
            TimelineTab(viewModel: viewModel)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(3)
            
            AnalyticsTab(viewModel: viewModel)
                .tabItem {
                    Label("Analytics", systemImage: "waveform.path.ecg")
                }
                .tag(4)
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - View Model

@MainActor
class UsageDashboardViewModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var projects: [ProjectUsage] = []
    @Published var entries: [UsageEntry] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedTimeRange: TimeRange = .last7Days
    
    private let client = ClaudeUsageClient()
    
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            // Load main stats
            let range = selectedTimeRange.dateRange
            stats = try await client.getUsageByDateRange(
                startDate: range.start,
                endDate: range.end
            )
            
            // Load project data
            projects = try await client.getSessionStats(
                since: range.start,
                until: range.end,
                order: .descending
            )
            
            // Load detailed entries
            entries = try await client.getUsageDetails(limit: 100)
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadData()
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    @ObservedObject var viewModel: UsageDashboardViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let stats = viewModel.stats {
                    VStack(spacing: 20) {
                        // Time Range Picker
                        TimeRangePicker(selection: $viewModel.selectedTimeRange)
                            .onChange(of: viewModel.selectedTimeRange) { _ in
                                Task { await viewModel.loadData() }
                            }
                        
                        // Key Metrics
                        MetricsGrid(stats: stats)
                        
                        // Daily Chart
                        DailyUsageChart(dailyUsage: stats.byDate)
                        
                        // Cost Breakdown
                        CostBreakdownView(stats: stats)
                    }
                    .padding()
                } else if let error = viewModel.error {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .navigationTitle("Usage Dashboard")
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Models Tab

struct ModelsTab: View {
    @ObservedObject var viewModel: UsageDashboardViewModel
    
    var body: some View {
        NavigationView {
            List {
                if let stats = viewModel.stats {
                    ForEach(stats.byModel) { model in
                        ModelRowView(model: model, totalCost: stats.totalCost)
                    }
                }
            }
            .navigationTitle("Model Usage")
        }
    }
}

struct ModelRowView: View {
    let model: ModelUsage
    let totalCost: Double
    
    private var percentage: Double {
        totalCost > 0 ? (model.totalCost / totalCost) * 100 : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.model.components(separatedBy: "-").prefix(3).joined(separator: "-"))
                    .font(.headline)
                Spacer()
                Text(model.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
            }
            
            ProgressView(value: percentage, total: 100)
                .tint(colorForModel(model.model))
            
            HStack {
                Label("\(model.sessionCount) sessions", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(model.totalTokens.abbreviated) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorForModel(_ model: String) -> Color {
        if model.contains("opus") {
            return .purple
        } else if model.contains("sonnet") {
            return .blue
        } else {
            return .green
        }
    }
}

// MARK: - Projects Tab

struct ProjectsTab: View {
    @ObservedObject var viewModel: UsageDashboardViewModel
    @State private var sortCriteria: [ProjectUsage].SortCriteria = .cost
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("Sort by", selection: $sortCriteria) {
                        Text("Cost").tag([ProjectUsage].SortCriteria.cost)
                        Text("Tokens").tag([ProjectUsage].SortCriteria.tokens)
                        Text("Sessions").tag([ProjectUsage].SortCriteria.sessions)
                        Text("Last Used").tag([ProjectUsage].SortCriteria.lastUsed)
                        Text("Name").tag([ProjectUsage].SortCriteria.name)
                    }
                    .pickerStyle(.segmented)
                }
                
                ForEach(viewModel.projects.sorted(by: sortCriteria)) { project in
                    ProjectRowView(project: project)
                }
            }
            .navigationTitle("Project Usage")
        }
    }
}

struct ProjectRowView: View {
    let project: ProjectUsage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.projectName)
                .font(.headline)
            
            HStack {
                Label(project.totalCost.asCurrency, systemImage: "dollarsign.circle")
                Spacer()
                Label("\(project.sessionCount) sessions", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            if let lastUsed = project.lastUsedDate {
                Text("Last used: \(lastUsed, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Timeline Tab

struct TimelineTab: View {
    @ObservedObject var viewModel: UsageDashboardViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let stats = viewModel.stats {
                    VStack(spacing: 20) {
                        // Daily Usage Chart
                        DailyUsageChart(dailyUsage: stats.byDate)
                            .frame(height: 300)
                        
                        // Daily List
                        ForEach(stats.byDate.reversed()) { daily in
                            DailyRowView(daily: daily)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Timeline")
        }
    }
}

struct DailyRowView: View {
    let daily: DailyUsage
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(formatDate(daily.date))
                    .font(.headline)
                Text("\(daily.modelCount) models used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(daily.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
                Text("\(daily.totalTokens.abbreviated) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Analytics Tab

struct AnalyticsTab: View {
    @ObservedObject var viewModel: UsageDashboardViewModel
    @State private var weeklyTrend: WeeklyTrend?
    @State private var cacheSavings: CacheSavings?
    @State private var predictedMonthlyCost: Double = 0
    
    var body: some View {
        NavigationView {
            List {
                if let stats = viewModel.stats {
                    Section("Trends") {
                        if let trend = weeklyTrend {
                            Label(trend.description, systemImage: "chart.line.uptrend.xyaxis")
                        }
                        
                        Label("Predicted monthly: \(predictedMonthlyCost.asCurrency)",
                              systemImage: "calendar")
                    }
                    
                    Section("Efficiency") {
                        if let savings = cacheSavings {
                            Label(savings.description, systemImage: "memorychip")
                        }
                        
                        Label("Avg cost/session: \(stats.averageCostPerSession.asCurrency)",
                              systemImage: "dollarsign.circle")
                        
                        Label("Cost per million tokens: \(stats.costPerMillionTokens.asCurrency)",
                              systemImage: "chart.bar")
                    }
                    
                    Section("Token Breakdown") {
                        let breakdown = UsageAnalytics.tokenBreakdown(from: stats)
                        Label("Input: \(breakdown.inputPercentage.asPercentage)",
                              systemImage: "arrow.right.circle")
                        Label("Output: \(breakdown.outputPercentage.asPercentage)",
                              systemImage: "arrow.left.circle")
                        Label("Cache Write: \(breakdown.cacheWritePercentage.asPercentage)",
                              systemImage: "square.and.pencil")
                        Label("Cache Read: \(breakdown.cacheReadPercentage.asPercentage)",
                              systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
            .navigationTitle("Analytics")
            .onAppear {
                calculateAnalytics()
            }
        }
    }
    
    private func calculateAnalytics() {
        guard let stats = viewModel.stats else { return }
        
        weeklyTrend = UsageAnalytics.weeklyTrends(from: stats.byDate)
        cacheSavings = UsageAnalytics.cacheSavings(from: stats)
        predictedMonthlyCost = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: 7)
    }
}

// MARK: - Supporting Views

struct TimeRangePicker: View {
    @Binding var selection: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selection) {
            Text("Last 7 Days").tag(TimeRange.last7Days)
            Text("Last 30 Days").tag(TimeRange.last30Days)
            Text("Last Month").tag(TimeRange.lastMonth)
            Text("All Time").tag(TimeRange.allTime)
        }
        .pickerStyle(.segmented)
    }
}

struct MetricsGrid: View {
    let stats: UsageStats
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            MetricCard(title: "Total Cost", value: stats.totalCost.asCurrency, icon: "dollarsign.circle")
            MetricCard(title: "Total Sessions", value: "\(stats.totalSessions)", icon: "doc.text")
            MetricCard(title: "Total Tokens", value: stats.totalTokens.abbreviated, icon: "chart.bar")
            MetricCard(title: "Avg Cost/Session", value: stats.averageCostPerSession.asCurrency, icon: "chart.line.uptrend.xyaxis")
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DailyUsageChart: View {
    let dailyUsage: [DailyUsage]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Daily Usage")
                .font(.headline)
            
            // Simple bar chart representation
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(dailyUsage) { daily in
                        BarView(
                            value: daily.totalCost,
                            maxValue: dailyUsage.map(\.totalCost).max() ?? 1,
                            width: geometry.size.width / CGFloat(dailyUsage.count) - 2,
                            height: geometry.size.height
                        )
                    }
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct BarView: View {
    let value: Double
    let maxValue: Double
    let width: CGFloat
    let height: CGFloat
    
    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value / maxValue) * height
    }
    
    var body: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .bottom,
                    endPoint: .top
                ))
                .frame(width: width, height: barHeight)
                .cornerRadius(4)
        }
    }
}

struct CostBreakdownView: View {
    let stats: UsageStats
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Cost Breakdown")
                .font(.headline)
            
            ForEach(UsageAnalytics.costBreakdown(from: stats), id: \.model) { item in
                HStack {
                    Text(item.model.components(separatedBy: "-").prefix(3).joined(separator: "-"))
                        .font(.subheadline)
                    Spacer()
                    Text(item.percentage.asPercentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.cost.asCurrency)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Error Loading Data")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
