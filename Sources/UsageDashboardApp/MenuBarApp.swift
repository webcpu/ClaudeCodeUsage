//
//  MenuBarApp.swift
//  Menu bar functionality for UsageDashboard
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// Shared data model for both main window and menu bar
@MainActor
class UsageDataModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var isLoading = true
    @Published var hasInitiallyLoaded = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime = Date()
    @Published var activeSession: SessionBlock?
    @Published var burnRate: BurnRate?
    @Published var autoTokenLimit: Int?
    @Published var dailyCostThreshold: Double = 10.0 // Default $10/day threshold
    @Published var averageDailyCost: Double = 0.0
    
    private var refreshTimer: Timer?
    private var isAppActive = true
    private var isCurrentlyLoading = false // Prevent concurrent loads
    
    let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
    let liveMonitor = LiveMonitor(config: LiveMonitorConfig(
        claudePaths: [NSHomeDirectory() + "/.claude"],
        sessionDurationHours: 5,
        tokenLimit: nil,
        refreshInterval: 2.0,
        order: .descending
    ))
    
    private let autoRefreshInterval: TimeInterval = 30.0  // Reduced frequency to avoid conflicts
    private let minimumRefreshInterval: TimeInterval = 5.0   // Increased minimum to prevent rapid refreshes
    
    var todaysCostValue: Double {
        guard let stats = stats else { return 0.0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
            return todayUsage.totalCost
        }
        
        return 0.0
    }
    
    var todaysCost: String {
        return todaysCostValue.asCurrency
    }
    
    var todaysCostProgress: Double {
        guard dailyCostThreshold > 0 else { return 0 }
        return min(todaysCostValue / dailyCostThreshold, 1.0)
    }
    
    var sessionTimeProgress: Double {
        guard let session = activeSession else { return 0 }
        let elapsed = Date().timeIntervalSince(session.startTime)
        let total = session.endTime.timeIntervalSince(session.startTime)
        return min(elapsed / total, 1.0)
    }
    
    var sessionTokenProgress: Double {
        guard let session = activeSession,
              let limit = autoTokenLimit,
              limit > 0 else { return 0 }
        return min(Double(session.tokenCounts.total) / Double(limit), 1.0)
    }
    
    var todaySessionCount: Int {
        // Count active sessions from live monitor if available
        if let _ = activeSession {
            return 1 // At least one active session today
        }
        return 0 // No active sessions currently
    }
    
    var estimatedDailySessions: Int {
        guard let stats = stats, stats.byDate.count > 0 else { return 0 }
        // Calculate average sessions per day based on historical data
        return max(1, stats.totalSessions / stats.byDate.count)
    }
    
    func loadData() async {
        // Prevent concurrent loads
        guard !isCurrentlyLoading else {
            print("Skipping load - already loading")
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        if !hasInitiallyLoaded {
            isLoading = true
        }
        errorMessage = nil
        lastRefreshTime = Date()
        
        do {
            let range = TimeRange.allTime.dateRange
            stats = try await client.getUsageByDateRange(
                startDate: range.start,
                endDate: range.end
            )
            
            // Get active session from live monitor
            activeSession = liveMonitor.getActiveBlock()
            if let session = activeSession {
                burnRate = session.burnRate
            }
            
            // Get auto token limit from live monitor
            autoTokenLimit = liveMonitor.getAutoTokenLimit()
            
            // Calculate average daily cost from last 7 days
            if let stats = stats, !stats.byDate.isEmpty {
                let recentDays = stats.byDate.suffix(7)
                let totalRecentCost = recentDays.reduce(0) { $0 + $1.totalCost }
                averageDailyCost = totalRecentCost / Double(recentDays.count)
                
                // Use average as threshold, with a minimum of $10
                if averageDailyCost > 0 {
                    dailyCostThreshold = max(averageDailyCost * 1.5, 10.0) // 150% of average or $10 minimum
                }
            }
            
            if stats?.totalSessions == 0 {
                print("No usage data found in ~/.claude/projects/")
                errorMessage = "No usage data found. Run Claude Code sessions to generate usage data."
            } else {
                let refreshType = hasInitiallyLoaded ? "Refreshed" : "Loaded"
                print("\(refreshType) \(stats?.totalSessions ?? 0) sessions, today's cost: \(todaysCost)")
                if let session = activeSession {
                    print("Active session: \(session.costUSD.asCurrency) | Burn: \(session.burnRate.tokensPerMinute) tokens/min")
                }
            }
        } catch {
            print("Error loading data: \(error)")
            errorMessage = "Error loading data: \(error.localizedDescription)"
        }
        
        if !hasInitiallyLoaded {
            hasInitiallyLoaded = true
            isLoading = false
        }
    }
    
    func startRefreshTimer() {
        // First stop any existing timer
        stopRefreshTimer()
        
        // Only start if app is active
        guard isAppActive else { 
            print("Not starting timer - app is not active")
            return 
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isAppActive && !self.isCurrentlyLoading {
                    await self.loadData()
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
    
    func handleAppBecameActive() {
        isAppActive = true
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        
        // Only refresh if enough time has passed and not currently loading
        if timeSinceLastRefresh >= minimumRefreshInterval && !isCurrentlyLoading {
            Task {
                await loadData()
            }
        }
        
        // Only start timer if one isn't already running
        if refreshTimer == nil {
            startRefreshTimer()
        }
    }
    
    func handleAppResignActive() {
        isAppActive = false
        stopRefreshTimer()
    }
    
    func handleWindowFocus() {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        
        // Only refresh if enough time has passed and not currently loading
        if timeSinceLastRefresh >= minimumRefreshInterval && !isCurrentlyLoading {
            Task {
                await loadData()
            }
        }
    }
}

// Helper function to format token counts
func formatTokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    } else {
        return "\(count)"
    }
}

// Custom progress bar view with proper rendering
@available(macOS 13.0, *)
struct UsageProgressBar: View {
    let value: Double
    let label: String
    let currentValue: String
    let maxValue: String
    let percentage: Int
    
    init(value: Double, label: String, currentValue: String, maxValue: String) {
        self.value = min(max(value, 0), 1)
        self.label = label
        self.currentValue = currentValue
        self.maxValue = maxValue
        self.percentage = Int(self.value * 100)
    }
    
    var progressColor: Color {
        switch value {
        case 0..<0.5: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case 0.5..<0.8: return Color(red: 0.9, green: 0.7, blue: 0.2)
        case 0.8..<0.95: return Color(red: 0.9, green: 0.5, blue: 0.2)
        default: return Color(red: 0.9, green: 0.3, blue: 0.3)
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Label and percentage on the left
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("\(percentage)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(progressColor)
            }
            .frame(width: 80, alignment: .leading)
            
            // Progress bar and values on the right
            VStack(alignment: .leading, spacing: 4) {
                // Values
                Text("\(currentValue) / \(maxValue)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                
                // Visual progress bar
                HStack(spacing: 0) {
                    // Filled portion
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: max(2, 140 * value), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: value)
                    
                    // Empty portion
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: max(0, 140 * (1 - value)), height: 8)
                }
                .frame(width: 140, height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

// Menu bar content view
@available(macOS 13.0, *)
struct MenuBarContentView: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Active session indicator
            if let session = dataModel.activeSession, session.isActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.green.opacity(0.3), lineWidth: 3)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        )
                    Text("LIVE SESSION")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Spacer()
                    Text(session.costUSD.asCurrency)
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
                
                // Burn rate
                if let burnRate = dataModel.burnRate {
                    HStack {
                        Label("\(burnRate.tokensPerMinute) tokens/min", systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("$\(String(format: "%.2f", burnRate.costPerHour))/hr")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 4)
                }
                
                // Session progress bars
                VStack(alignment: .leading, spacing: 8) {
                    // Time progress
                    UsageProgressBar(
                        value: dataModel.sessionTimeProgress,
                        label: "Session Time",
                        currentValue: String(format: "%.1fh", Date().timeIntervalSince(session.startTime) / 3600),
                        maxValue: String(format: "%.0fh", session.endTime.timeIntervalSince(session.startTime) / 3600)
                    )
                    
                    // Token progress (if limit available)
                    if let tokenLimit = dataModel.autoTokenLimit {
                        UsageProgressBar(
                            value: dataModel.sessionTokenProgress,
                            label: "Token Usage",
                            currentValue: formatTokenCount(session.tokenCounts.total),
                            maxValue: formatTokenCount(tokenLimit)
                        )
                    }
                }
                .padding(8)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal, 4)
                
                Divider()
            }
            
            // Today's cost header
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(.blue)
                Text("Today's Cost")
                    .font(.headline)
                Spacer()
                Text(dataModel.todaysCost)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            // Daily cost progress bar
            VStack(alignment: .leading, spacing: 4) {
                UsageProgressBar(
                    value: dataModel.todaysCostProgress,
                    label: "Daily Budget",
                    currentValue: dataModel.todaysCost,
                    maxValue: "$\(String(format: "%.0f", dataModel.dailyCostThreshold))"
                )
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)
            .padding(.horizontal, 4)
            
            Divider()
            
            // Quick stats
            if let stats = dataModel.stats {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Total Cost:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(stats.totalCost.asCurrency)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Sessions Today:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(dataModel.todaySessionCount)")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Divider()
            
            // Actions
            Button("Open Dashboard") {
                if #available(macOS 13.0, *) {
                    openWindow(id: "main")
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            
            Button("Refresh") {
                Task {
                    await dataModel.loadData()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
        .frame(width: 320, height: nil)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            // Refresh data when menu window opens
            Task {
                await dataModel.loadData()
            }
        }
    }
}