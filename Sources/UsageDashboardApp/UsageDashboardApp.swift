//
//  UsageDashboardApp.swift
//  Minimal SwiftUI App for ClaudeUsageSDK
//

import SwiftUI
import ClaudeCodeUsage
import Combine

@main
struct UsageDashboardApp: App {
    @StateObject private var dataModel = UsageDataModel()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(dataModel)
        }
        
        // Menu bar icon for macOS 13+
        if #available(macOS 13.0, *) {
            MenuBarExtra {
                MenuBarContentView()
                    .environmentObject(dataModel)
            } label: {
                HStack(spacing: 4) {
                    if let session = dataModel.activeSession, session.isActive {
                        // Show live indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(session.costUSD.asCurrency)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "dollarsign.circle.fill")
                        Text(dataModel.todaysCost)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .menuBarExtraStyle(.menu)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @State private var selectedTimeRange: TimeRange = .allTime  // Show all data by default
    
    var body: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView {
            // Sidebar
            List {
                NavigationLink {
                    OverviewView(stats: dataModel.stats, isLoading: dataModel.isLoading)
                } label: {
                    Label("Overview", systemImage: "chart.line.uptrend.xyaxis")
                }
                
                NavigationLink {
                    ModelUsageView(stats: dataModel.stats)
                } label: {
                    Label("Models", systemImage: "cpu")
                }
                
                NavigationLink {
                    DailyUsageView(stats: dataModel.stats)
                } label: {
                    Label("Daily Usage", systemImage: "calendar")
                }
                
                NavigationLink {
                    AnalyticsView(stats: dataModel.stats)
                } label: {
                    Label("Analytics", systemImage: "chart.bar.xaxis")
                }
            }
            .navigationTitle("Usage Dashboard")
            .frame(minWidth: 200)
        } detail: {
            OverviewView(stats: dataModel.stats, isLoading: dataModel.isLoading)
        }
        .task {
            await dataModel.loadData()
            dataModel.startRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            dataModel.handleAppBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            dataModel.handleAppResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            dataModel.handleWindowFocus()
        }
        .onDisappear {
            dataModel.stopRefreshTimer()
        }
        } else {
            // Fallback for macOS 12
            NavigationView {
                List {
                    NavigationLink("Overview", destination: OverviewView(stats: dataModel.stats, isLoading: dataModel.isLoading))
                    NavigationLink("Models", destination: ModelUsageView(stats: dataModel.stats))
                    NavigationLink("Daily Usage", destination: DailyUsageView(stats: dataModel.stats))
                    NavigationLink("Analytics", destination: AnalyticsView(stats: dataModel.stats))
                }
                .navigationTitle("Usage Dashboard")
                .frame(minWidth: 200)
                
                OverviewView(stats: dataModel.stats, isLoading: dataModel.isLoading)
            }
            .task {
                await dataModel.loadData()
                dataModel.startRefreshTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                dataModel.handleAppBecameActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                dataModel.handleAppResignActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                dataModel.handleWindowFocus()
            }
            .onDisappear {
                dataModel.stopRefreshTimer()
            }
        }
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