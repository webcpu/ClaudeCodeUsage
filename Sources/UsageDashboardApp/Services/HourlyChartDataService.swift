//
//  HourlyChartDataService.swift
//  Service for generating hourly chart data
//

import Foundation
import ClaudeCodeUsage

/// Service responsible for generating hourly chart data from usage entries
public final class HourlyChartDataService {
    
    // MARK: - Dependencies
    
    private let repository: UsageRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(repository: UsageRepositoryProtocol) {
        self.repository = repository
    }
    
    // MARK: - Public Interface
    
    /// Generate hourly chart data for a specific date
    /// - Parameter date: The date to generate chart data for
    /// - Returns: Complete hourly chart dataset
    public func generateHourlyChartData(for date: Date) async -> HourlyChartDataset {
        do {
            let entries = try await repository.loadEntriesForDate(date)
            return generateChartData(from: entries, for: date)
        } catch {
            let errorMessage = mapErrorToUserMessage(error)
            return HourlyChartDataset.error(errorMessage)
        }
    }
    
    // MARK: - Private Methods
    
    private func generateChartData(from entries: [UsageEntry], for date: Date) -> HourlyChartDataset {
        let calendar = Calendar.current
        
        // Group entries by hour
        var hourlyData: [Int: (cost: Double, count: Int)] = [:]
        
        for entry in entries {
            guard let entryDate = entry.date else { continue }
            
            // Ensure entry is from the target date
            guard calendar.isDate(entryDate, inSameDayAs: date) else { continue }
            
            let hour = calendar.component(.hour, from: entryDate)
            let current = hourlyData[hour] ?? (cost: 0, count: 0)
            hourlyData[hour] = (cost: current.cost + entry.cost, count: current.count + 1)
        }
        
        // Create bars for all 24 hours
        var bars: [HourlyBar] = []
        for hour in 0..<24 {
            let data = hourlyData[hour] ?? (cost: 0, count: 0)
            bars.append(HourlyBar(hour: hour, cost: data.cost, entryCount: data.count))
        }
        
        return HourlyChartDataset(bars: bars)
    }
    
    private func mapErrorToUserMessage(_ error: Error) -> String {
        if let repoError = error as? RepositoryError {
            switch repoError {
            case .fileNotFound:
                return "Unable to load usage data"
            case .invalidData:
                return "Invalid usage data format"
            case .accessDenied:
                return "Access denied to usage data"
            case .unknown:
                return "Unknown error occurred"
            }
        }
        return "Unable to load usage data"
    }
}