//
//  FormatterService.swift
//  Formatting utilities for display values
//

import Foundation

struct FormatterService {
    
    // MARK: - Token Formatting
    static func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
    
    // MARK: - Percentage Formatting
    static func formatPercentage(_ percentage: Double) -> String {
        return "\(Int(percentage))%"
    }
    
    // MARK: - Time Duration Formatting
    static func formatTimeInterval(_ interval: TimeInterval, totalInterval: TimeInterval) -> String {
        let hours = interval / 3600
        let totalHours = totalInterval / 3600
        return String(format: "%.1fh / %.0fh", hours, totalHours)
    }
    
    // MARK: - Currency Formatting
    static func formatCurrency(_ amount: Double) -> String {
        return String(format: "$%.2f", amount)
    }
    
    // MARK: - Rate Formatting
    static func formatTokenRate(_ tokensPerMinute: Int) -> String {
        return "\(formatTokenCount(tokensPerMinute)) tokens/min"
    }
    
    static func formatCostRate(_ costPerHour: Double) -> String {
        return "\(formatCurrency(costPerHour))/hr"
    }
    
    // MARK: - Session Count Formatting
    static func formatSessionCount(_ count: Int) -> String {
        return count > 0 ? "\(count) active" : "No active"
    }
    
    // MARK: - Value with Limit Formatting
    static func formatValueWithLimit<T: BinaryInteger>(_ current: T, limit: T) -> String {
        return "\(formatTokenCount(Int(current))) / \(formatTokenCount(Int(limit)))"
    }
    
    // MARK: - Daily Average Formatting
    static func formatDailyAverage(_ average: Double) -> String {
        return formatCurrency(average)
    }
}