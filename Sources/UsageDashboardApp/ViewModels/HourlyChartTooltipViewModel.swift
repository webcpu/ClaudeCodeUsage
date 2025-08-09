//
//  HourlyChartTooltipViewModel.swift
//  View model for hourly chart tooltip functionality
//

import Foundation

/// View model for managing hourly chart tooltip display
public final class HourlyChartTooltipViewModel {
    
    // MARK: - Public Interface
    
    /// Generate tooltip data for a specific hourly bar
    /// - Parameter bar: The hourly bar to create tooltip for
    /// - Returns: Formatted tooltip data
    public func generateTooltip(for bar: HourlyBar) -> HourlyTooltip {
        let timeRange = formatTimeRange(for: bar.hour)
        let cost = formatCost(bar.cost)
        let entryCount = formatEntryCount(bar.entryCount)
        
        return HourlyTooltip(
            timeRange: timeRange,
            cost: cost,
            entryCount: entryCount
        )
    }
    
    // MARK: - Private Formatting Methods
    
    private func formatTimeRange(for hour: Int) -> String {
        let startHour = hour
        let endHour = (hour + 1) % 24
        
        let startString = formatHourForDisplay(startHour)
        let endString = formatHourForDisplay(endHour)
        
        return "\(startString) - \(endString)"
    }
    
    private func formatHourForDisplay(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Create a date with the specific hour
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var components = calendar.dateComponents([.year, .month, .day], from: today)
        components.hour = hour
        components.minute = 0
        
        let date = calendar.date(from: components) ?? Date()
        
        return formatter.string(from: date)
    }
    
    private func formatCost(_ cost: Double) -> String {
        if cost == 0 {
            return "No usage"
        }
        return cost.asCurrency
    }
    
    private func formatEntryCount(_ count: Int) -> String {
        switch count {
        case 0:
            return "No requests"
        case 1:
            return "1 request"
        default:
            return "\(count) requests"
        }
    }
}