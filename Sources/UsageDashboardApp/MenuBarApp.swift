//
//  MenuBarApp.swift
//  Menu bar functionality for UsageDashboard
//

import SwiftUI
import ClaudeCodeUsage

// Shared data model for both main window and menu bar
@MainActor
class UsageDataModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var isLoading = true
    @Published var hasInitiallyLoaded = false
    @Published var errorMessage: String?
    @Published var lastRefreshTime = Date()
    
    private var refreshTimer: Timer?
    private var isAppActive = true
    
    let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
    private let autoRefreshInterval: TimeInterval = 30.0
    private let minimumRefreshInterval: TimeInterval = 5.0
    
    var todaysCost: String {
        guard let stats = stats else { return "$0.00" }
        
        // Get today's date string
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        // Find today's usage
        if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
            return todayUsage.totalCost.asCurrency
        }
        
        return "$0.00"
    }
    
    var todaySessionCount: Int {
        guard let stats = stats else { return 0 }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        // Count sessions for today from all models
        var sessionCount = 0
        for model in stats.byModel {
            // Since we don't have per-day session count, we'll estimate based on proportion
            if stats.byDate.contains(where: { $0.date == todayString }) {
                // This is a simplified calculation - in reality we'd need per-day session data
                sessionCount += max(1, model.sessionCount / max(1, stats.byDate.count))
            }
        }
        return sessionCount
    }
    
    func loadData() async {
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
            
            if stats?.totalSessions == 0 {
                print("No usage data found in ~/.claude/projects/")
                errorMessage = "No usage data found. Run Claude Code sessions to generate usage data."
            } else {
                let refreshType = hasInitiallyLoaded ? "Refreshed" : "Loaded"
                print("\(refreshType) \(stats?.totalSessions ?? 0) sessions, today's cost: \(todaysCost)")
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
        stopRefreshTimer()
        guard isAppActive else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isAppActive {
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
        if timeSinceLastRefresh >= minimumRefreshInterval {
            Task {
                await loadData()
            }
        }
        startRefreshTimer()
    }
    
    func handleAppResignActive() {
        isAppActive = false
        stopRefreshTimer()
    }
    
    func handleWindowFocus() {
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshTime)
        if timeSinceLastRefresh >= minimumRefreshInterval {
            Task {
                await loadData()
            }
        }
    }
}

// Menu bar content view
@available(macOS 13.0, *)
struct MenuBarContentView: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .frame(width: 220)
    }
}