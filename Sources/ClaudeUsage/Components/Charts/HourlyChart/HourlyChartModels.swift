//
//  HourlyChartModels.swift
//  Data models for TDD hourly chart functionality
//

import Foundation
import ClaudeUsageCore

// MARK: - TDD Hourly Chart Data Models

/// Represents a single bar in the TDD hourly chart
public struct HourlyBar: Identifiable, Equatable {
    /// Unique identifier based on hour
    public var id: String { "hour-\(hour)" }
    
    /// Hour of the day (0-23)
    public let hour: Int
    
    /// Total cost for this hour
    public let cost: Double
    
    /// Number of entries for this hour
    public let entryCount: Int
    
    /// Pre-formatted cost string for display
    public var formattedCost: String {
        cost.asCurrency
    }
    
    /// Whether this hour has no usage
    public var isEmpty: Bool {
        cost == 0 && entryCount == 0
    }
    
    public init(hour: Int, cost: Double, entryCount: Int) {
        self.hour = hour
        self.cost = cost
        self.entryCount = entryCount
    }
}

/// Complete dataset for TDD hourly chart visualization
public struct HourlyChartDataset: Equatable {
    /// Array of 24 bars representing each hour
    public let bars: [HourlyBar]
    
    /// Total cost across all hours
    public let totalCost: Double
    
    /// Peak usage hour (hour with highest cost)
    public let peakHour: Int?
    
    /// Peak cost value
    public let peakCost: Double
    
    /// Whether an error occurred during data generation
    public let hasError: Bool
    
    /// Error message if hasError is true
    public let errorMessage: String
    
    public init(
        bars: [HourlyBar],
        totalCost: Double = 0,
        peakHour: Int? = nil,
        peakCost: Double = 0,
        hasError: Bool = false,
        errorMessage: String = ""
    ) {
        self.bars = bars
        self.totalCost = totalCost == 0 ? bars.reduce(0) { $0 + $1.cost } : totalCost
        
        // Calculate peak hour and cost if not provided
        if let peakHour = peakHour {
            self.peakHour = peakHour
            self.peakCost = peakCost
        } else {
            let maxBar = bars.max { $0.cost < $1.cost }
            self.peakHour = maxBar?.cost ?? 0 > 0 ? maxBar?.hour : nil
            self.peakCost = maxBar?.cost ?? 0
        }
        
        self.hasError = hasError
        self.errorMessage = errorMessage
    }
    
    /// Create an error state chart data
    public static func error(_ message: String) -> HourlyChartDataset {
        // Create empty bars for all 24 hours
        let emptyBars = (0..<24).map { HourlyBar(hour: $0, cost: 0, entryCount: 0) }
        return HourlyChartDataset(
            bars: emptyBars,
            totalCost: 0,
            peakHour: nil,
            peakCost: 0,
            hasError: true,
            errorMessage: message
        )
    }
}

/// Tooltip data for hourly chart bars
public struct HourlyTooltip: Equatable {
    /// Time range string (e.g., "2:00 PM - 3:00 PM")
    public let timeRange: String
    
    /// Formatted cost string (e.g., "$25.50" or "No usage")
    public let cost: String
    
    /// Entry count string (e.g., "3 requests" or "No requests")
    public let entryCount: String
    
    public init(timeRange: String, cost: String, entryCount: String) {
        self.timeRange = timeRange
        self.cost = cost
        self.entryCount = entryCount
    }
}