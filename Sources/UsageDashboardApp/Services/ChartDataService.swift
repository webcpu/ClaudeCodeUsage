//
//  ChartDataService.swift
//  Service for fetching and processing chart data
//

import Foundation
import Observation
import ClaudeCodeUsage

@Observable
@MainActor
final class ChartDataService {
    
    private(set) var todayHourlyCosts: [Double] = []
    private(set) var detailedHourlyData: [HourlyChartData] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?
    
    // MARK: - Data Loading
    /// Load hourly costs directly from provided entries (preferred method)
    func loadHourlyCostsFromEntries(_ entries: [UsageEntry]) async {
        isLoading = true
        error = nil
        
        let hourlyData = UsageAnalytics.todayHourlyCosts(from: entries)
        let detailedData = UsageAnalytics.detailedHourlyCosts(from: entries)
        
        self.todayHourlyCosts = hourlyData
        self.detailedHourlyData = detailedData
        self.isLoading = false
        
        #if DEBUG
        let totalCost = hourlyData.reduce(0, +)
        print("[ChartDataService] Loaded hourly costs from entries: $\(String(format: "%.2f", totalCost)) from \(entries.count) entries")
        print("[ChartDataService] Hourly breakdown: \(hourlyData.enumerated().compactMap { $1 > 0 ? "Hour \($0): $\(String(format: "%.2f", $1))" : nil }.joined(separator: ", "))")
        #endif
    }
    
    /// Load hourly costs from stats (legacy method, fetches from disk)
    func loadHourlyCostsFromStats(_ stats: UsageStats?) async {
        guard stats != nil else {
            self.todayHourlyCosts = []
            self.detailedHourlyData = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            // Get all entries to extract today's data
            let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
            let allEntries = try await client.getUsageDetails()
            
            // Filter for today's entries
            let calendar = Calendar.current
            let today = Date()
            let todayEntries = allEntries.filter { entry in
                guard let date = entry.date else { return false }
                return calendar.isDate(date, inSameDayAs: today)
            }
            
            let hourlyData = UsageAnalytics.todayHourlyCosts(from: todayEntries)
            let detailedData = UsageAnalytics.detailedHourlyCosts(from: todayEntries)
            
            self.todayHourlyCosts = hourlyData
            self.detailedHourlyData = detailedData
            self.isLoading = false
            
            #if DEBUG
            let totalCost = hourlyData.reduce(0, +)
            print("[ChartDataService] Loaded hourly costs from stats: $\(String(format: "%.2f", totalCost)) from \(todayEntries.count) entries")
            #endif
        } catch {
            self.error = error
            self.todayHourlyCosts = []
            self.detailedHourlyData = []
            self.isLoading = false
            print("Failed to load hourly costs from stats: \(error)")
        }
    }
    
    @available(*, deprecated, message: "Use loadHourlyCostsFromEntries or loadHourlyCostsFromStats instead")
    func loadTodayHourlyCosts() async {
        await loadHourlyCostsFromStats(nil)
    }
    
    // MARK: - Data Access
    func hourlyDataForDisplay() -> [Double] {
        if todayHourlyCosts.isEmpty {
            return []
        }
        
        // Ensure we have exactly 24 hours for display
        var displayData = todayHourlyCosts
        while displayData.count < 24 {
            displayData.append(0)
        }
        return Array(displayData.prefix(24))
    }
    
    func currentHourCost() -> Double {
        let currentHour = Calendar.current.component(.hour, from: Date())
        guard currentHour < todayHourlyCosts.count else { return 0 }
        return todayHourlyCosts[currentHour]
    }
}