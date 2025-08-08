//
//  ChartDataService.swift
//  Service for fetching and processing chart data
//

import Foundation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

@available(macOS 13.0, *)
class ChartDataService: ObservableObject {
    
    @Published private(set) var todayHourlyCosts: [Double] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // MARK: - Data Loading
    func loadTodayHourlyCosts() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
            let todayEntries = try await client.getTodayUsageEntries()
            let hourlyData = UsageAnalytics.todayHourlyAccumulation(from: todayEntries)
            
            await MainActor.run {
                self.todayHourlyCosts = hourlyData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.todayHourlyCosts = []
                self.isLoading = false
            }
            print("Failed to load real hourly costs: \(error)")
        }
    }
    
    // MARK: - Data Processing
    static func processDataPoints(_ dataPoints: [Double]) -> ProcessedChartData {
        guard dataPoints.count > 1 else {
            return ProcessedChartData(
                dataPoints: dataPoints,
                maxValue: 1.0,
                minValue: 0.0,
                range: 0.01
            )
        }
        
        let maxValue = dataPoints.max() ?? 1.0
        let minValue = dataPoints.min() ?? 0.0
        let range = max(maxValue - minValue, MenuBarTheme.Graph.minimumRange)
        
        return ProcessedChartData(
            dataPoints: dataPoints,
            maxValue: maxValue,
            minValue: minValue,
            range: range
        )
    }
    
    // MARK: - Coordinate Calculation
    static func calculateChartCoordinates(
        for processedData: ProcessedChartData,
        in geometry: CGSize
    ) -> [CGPoint] {
        guard processedData.dataPoints.count > 1 else { return [] }
        
        let stepX = geometry.width / CGFloat(processedData.dataPoints.count - 1)
        
        return processedData.dataPoints.enumerated().map { index, value in
            let x = CGFloat(index) * stepX
            let normalizedValue = (value - processedData.minValue) / processedData.range
            let y = geometry.height * (1 - normalizedValue)
            return CGPoint(x: x, y: y)
        }
    }
}

// MARK: - Supporting Types
@available(macOS 13.0, *)
struct ProcessedChartData {
    let dataPoints: [Double]
    let maxValue: Double
    let minValue: Double
    let range: Double
}