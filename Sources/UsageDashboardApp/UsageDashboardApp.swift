//
//  UsageDashboardApp.swift
//  Minimal SwiftUI App for ClaudeUsageSDK
//

import SwiftUI
import ClaudeCodeUsage
import Combine

@main
struct UsageDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var stats: UsageStats?
    @State private var isLoading = true
    @State private var hasInitiallyLoaded = false
    @State private var selectedTimeRange: TimeRange = .allTime  // Show all data by default
    @State private var errorMessage: String?
    @State private var refreshTimer: Timer?
    @State private var isAppActive = true
    @State private var lastRefreshTime = Date()
    @State private var isManualRefreshing = false
    
    // Use real data from Claude sessions
    private let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
    
    // Refresh intervals
    private let autoRefreshInterval: TimeInterval = 30.0  // 30 seconds instead of 2
    private let minimumRefreshInterval: TimeInterval = 5.0  // Prevent too frequent refreshes
    
    var body: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView {
            // Sidebar
            List {
                NavigationLink {
                    OverviewView(stats: stats, isLoading: isLoading)
                } label: {
                    Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
                }
                
                NavigationLink {
                    ModelUsageView(stats: stats)
                } label: {
                    Label("Models", systemImage: "cpu")
                }
                
                NavigationLink {
                    DailyUsageView(stats: stats)
                } label: {
                    Label("Daily Usage", systemImage: "calendar")
                }
                
                NavigationLink {
                    AnalyticsView(stats: stats)
                } label: {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
            }
            .navigationTitle("Usage Dashboard")
            .frame(minWidth: 200)
        } detail: {
            OverviewView(stats: stats, isLoading: isLoading)
        }
        .task {
            await loadData()
            startRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // App became active (foreground)
            isAppActive = true
            
            // Only refresh if enough time has passed since last refresh
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
            if timeSinceLastRefresh >= minimumRefreshInterval {
                Task {
                    await loadData()
                }
            }
            startRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            // App became inactive (background)
            isAppActive = false
            stopRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // Window gained focus - only refresh if enough time has passed
            let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
            if timeSinceLastRefresh >= minimumRefreshInterval {
                Task {
                    await loadData()
                }
            }
        }
        .onDisappear {
            stopRefreshTimer()
        }
        } else {
            // Fallback for macOS 12
            NavigationView {
                List {
                    NavigationLink("Overview", destination: OverviewView(stats: stats, isLoading: isLoading))
                    NavigationLink("Models", destination: ModelUsageView(stats: stats))
                    NavigationLink("Daily Usage", destination: DailyUsageView(stats: stats))
                    NavigationLink("Analytics", destination: AnalyticsView(stats: stats))
                }
                .navigationTitle("Usage Dashboard")
                .frame(minWidth: 200)
                
                OverviewView(stats: stats, isLoading: isLoading)
            }
            .task {
                await loadData()
                startRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                isAppActive = true
                
                // Only refresh if enough time has passed since last refresh
                let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
                if timeSinceLastRefresh >= minimumRefreshInterval {
                    Task {
                        await loadData()
                    }
                }
                startRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                isAppActive = false
                stopRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                // Window gained focus - only refresh if enough time has passed
                let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
                if timeSinceLastRefresh >= minimumRefreshInterval {
                    Task {
                        await loadData()
                    }
                }
            }
            .onDisappear {
                stopRefreshTimer()
            }
        }
    }
    
    func loadData() async {
        // Only show loading indicator on initial load
        if !hasInitiallyLoaded {
            isLoading = true
        }
        errorMessage = nil
        
        // Update last refresh time
        lastRefreshTime = Date()
        
        do {
            // Only use real data - no mock fallback
            let range = selectedTimeRange.dateRange
            stats = try await client.getUsageByDateRange(
                startDate: range.start,
                endDate: range.end
            )
            
            if stats?.totalSessions == 0 {
                print("No usage data found in ~/.claude/projects/ for the selected time range")
                errorMessage = "No usage data found. Run Claude Code sessions to generate usage data."
            } else {
                let refreshType = hasInitiallyLoaded ? "Refreshed" : "Loaded"
                print("\(refreshType) \(stats?.totalSessions ?? 0) sessions with total cost: $\(stats?.totalCost ?? 0)")
            }
        } catch {
            print("Error loading data: \(error)")
            errorMessage = "Error loading data: \(error.localizedDescription)"
        }
        
        // Mark initial load as complete and hide loading indicator
        if !hasInitiallyLoaded {
            hasInitiallyLoaded = true
            isLoading = false
        }
    }
    
    func startRefreshTimer() {
        // Stop any existing timer first
        stopRefreshTimer()
        
        // Only start timer if app is active
        guard isAppActive else { return }
        
        // Create a new timer that fires every 30 seconds (reduced from 2 seconds to prevent high CPU usage)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { _ in
            // Only refresh if app is still active
            if isAppActive {
                Task {
                    await loadData()
                }
            }
        }
        
        print("Started refresh timer (\(Int(autoRefreshInterval)) second interval)")
    }
    
    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        print("Stopped refresh timer")
    }
}

struct OverviewView: View {
    let stats: UsageStats?
    let isLoading: Bool
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let stats = stats {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Metrics Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(
                            title: "Total Cost",
                            value: stats.totalCost.asCurrency,
                            icon: "dollarsign.circle",
                            color: .green
                        )
                        MetricCard(
                            title: "Total Sessions",
                            value: "\(stats.totalSessions)",
                            icon: "doc.text",
                            color: .blue
                        )
                        MetricCard(
                            title: "Total Tokens",
                            value: stats.totalTokens.abbreviated,
                            icon: "number",
                            color: .purple
                        )
                        MetricCard(
                            title: "Avg Cost/Session",
                            value: stats.averageCostPerSession.asCurrency,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .orange
                        )
                    }
                    
                    // Cost Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cost Breakdown by Model")
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
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModelUsageView: View {
    let stats: UsageStats?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Model Usage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let stats = stats {
                    ForEach(stats.byModel) { model in
                        ModelCard(model: model, totalCost: stats.totalCost)
                    }
                }
            }
            .padding()
        }
    }
}

struct DailyUsageView: View {
    let stats: UsageStats?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Daily Usage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let stats = stats {
                    if stats.byDate.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No usage data available")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("Run Claude Code sessions to generate usage data.\nData will appear here from ~/.claude/projects/")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(stats.byDate.reversed()) { daily in
                            DailyCard(daily: daily)
                        }
                    }
                } else {
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
}

struct AnalyticsView: View {
    let stats: UsageStats?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Analytics")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let stats = stats {
                    // Token Breakdown
                    let breakdown = UsageAnalytics.tokenBreakdown(from: stats)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Token Distribution")
                            .font(.headline)
                        
                        Label("Input: \(breakdown.inputPercentage.asPercentage)",
                              systemImage: "arrow.right.circle")
                        Label("Output: \(breakdown.outputPercentage.asPercentage)",
                              systemImage: "arrow.left.circle")
                        Label("Cache Write: \(breakdown.cacheWritePercentage.asPercentage)",
                              systemImage: "square.and.pencil")
                        Label("Cache Read: \(breakdown.cacheReadPercentage.asPercentage)",
                              systemImage: "doc.text.magnifyingglass")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Predictions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Predictions & Trends")
                            .font(.headline)
                        
                        let prediction = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: 7)
                        Label("Predicted Monthly Cost: \(prediction.asCurrency)",
                              systemImage: "calendar")
                        
                        let savings = UsageAnalytics.cacheSavings(from: stats)
                        Label(savings.description,
                              systemImage: "memorychip")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ModelCard: View {
    let model: ModelUsage
    let totalCost: Double
    
    private var percentage: Double {
        totalCost > 0 ? (model.totalCost / totalCost) * 100 : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(model.model.components(separatedBy: "-").prefix(3).joined(separator: "-"))
                    .font(.headline)
                Spacer()
                Text(model.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
            }
            
            ProgressView(value: percentage, total: 100)
                .tint(model.model.contains("opus") ? .purple : .blue)
            
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
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct DailyCard: View {
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
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
