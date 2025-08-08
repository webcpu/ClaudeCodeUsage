//
//  ChartDataService.swift
//  Service for fetching and processing chart data
//

import Foundation
import Observation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

@Observable
@MainActor
final class ChartDataService {
    
    private(set) var todayHourlyCosts: [Double] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?
    
    // MARK: - Data Loading
    func loadTodayHourlyCosts() async {
        isLoading = true
        error = nil
        
        do {
            let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
            let todayEntries = try await client.getTodayUsageEntries()
            let hourlyData = UsageAnalytics.todayHourlyCosts(from: todayEntries)
            
            self.todayHourlyCosts = hourlyData
            self.isLoading = false
        } catch {
            self.error = error
            self.todayHourlyCosts = []
            self.isLoading = false
            print("Failed to load real hourly costs: \(error)")
        }
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