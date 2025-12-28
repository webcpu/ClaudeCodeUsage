//
//  UsageModels+TimeRange.swift
//
//  Time range filtering enum for usage queries.
//

import Foundation

// MARK: - Time Range Filters

/// Predefined time ranges for filtering
public enum TimeRange: Hashable, Identifiable {
    case allTime
    case last7Days
    case last30Days
    case lastMonth
    case last90Days
    case lastYear
    case custom(start: Date, end: Date)

    public var id: String {
        switch self {
        case .allTime: return "allTime"
        case .last7Days: return "last7Days"
        case .last30Days: return "last30Days"
        case .lastMonth: return "lastMonth"
        case .last90Days: return "last90Days"
        case .lastYear: return "lastYear"
        case .custom(let start, let end): return "custom_\(start.timeIntervalSince1970)_\(end.timeIntervalSince1970)"
        }
    }

    public var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .lastMonth: return "Last Month"
        case .last90Days: return "Last 90 Days"
        case .lastYear: return "Last Year"
        case .custom(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    /// Standard time ranges (without custom)
    public static var allCases: [TimeRange] {
        [.allTime, .last7Days, .last30Days, .lastMonth, .last90Days, .lastYear]
    }

    /// Get the date range for this time period
    public var dateRange: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .allTime:
            return (Date.distantPast, now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .custom(let start, let end):
            return (start, end)
        }
    }

    /// Format dates for API calls
    public var apiDateStrings: (start: String, end: String) {
        let formatter = ISO8601DateFormatter()
        let range = dateRange
        return (formatter.string(from: range.start), formatter.string(from: range.end))
    }
}
