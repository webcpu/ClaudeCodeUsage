//
//  UsageModels.swift
//  ClaudeCodeUsage
//
//  Data models for Claude Code usage statistics
//

import Foundation

// MARK: - Cached Date Formatters

/// Static formatters to avoid re-allocation on every date parse (16,600+ calls)
private enum DateFormatters {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Core Usage Models

/// Represents a single usage entry
public struct UsageEntry: Codable {
    public let project: String
    public let timestamp: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheWriteTokens: Int
    public let cacheReadTokens: Int
    public let cost: Double
    public let sessionId: String?
    
    public init(project: String, timestamp: String, model: String, 
                inputTokens: Int, outputTokens: Int, 
                cacheWriteTokens: Int, cacheReadTokens: Int,
                cost: Double, sessionId: String?) {
        self.project = project
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.cacheReadTokens = cacheReadTokens
        self.cost = cost
        self.sessionId = sessionId
    }
    
    private enum CodingKeys: String, CodingKey {
        case project
        case timestamp
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheWriteTokens = "cache_write_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cost
        case sessionId = "session_id"
    }
    
    /// Total tokens used in this entry
    public var totalTokens: Int {
        inputTokens + outputTokens + cacheWriteTokens + cacheReadTokens
    }
    
    /// Parsed timestamp as Date (uses cached formatters for performance)
    public var date: Date? {
        // Try with fractional seconds first (most common format)
        if let date = DateFormatters.withFractionalSeconds.date(from: timestamp) {
            return date
        }

        // Fallback to basic ISO8601
        if let date = DateFormatters.basic.date(from: timestamp) {
            return date
        }

        // Last resort: strip milliseconds and try again
        let cleanTimestamp = timestamp.replacingOccurrences(of: "\\.\\d{3}", with: "", options: .regularExpression)
        return DateFormatters.basic.date(from: cleanTimestamp)
    }
}

/// Usage statistics aggregated by model
public struct ModelUsage: Codable {
    public let model: String
    public let totalCost: Double
    public let totalTokens: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let sessionCount: Int
    
    private enum CodingKeys: String, CodingKey {
        case model
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case sessionCount = "session_count"
    }
    
    /// Average cost per session
    public var averageCostPerSession: Double {
        sessionCount > 0 ? totalCost / Double(sessionCount) : 0
    }
    
    /// Average tokens per session
    public var averageTokensPerSession: Int {
        sessionCount > 0 ? totalTokens / sessionCount : 0
    }
}

/// Daily usage statistics
public struct DailyUsage: Codable {
    public let date: String
    public let totalCost: Double
    public let totalTokens: Int
    public let modelsUsed: [String]
    
    public init(date: String, totalCost: Double, totalTokens: Int, modelsUsed: [String]) {
        self.date = date
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.modelsUsed = modelsUsed
    }
    
    private enum CodingKeys: String, CodingKey {
        case date
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case modelsUsed = "models_used"
    }
    
    /// Parsed date
    public var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
    
    /// Number of different models used
    public var modelCount: Int {
        modelsUsed.count
    }
}

/// Project usage statistics
public struct ProjectUsage: Codable {
    public let projectPath: String
    public let projectName: String
    public let totalCost: Double
    public let totalTokens: Int
    public let sessionCount: Int
    public let lastUsed: String
    
    private enum CodingKeys: String, CodingKey {
        case projectPath = "project_path"
        case projectName = "project_name"
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case sessionCount = "session_count"
        case lastUsed = "last_used"
    }
    
    /// Average cost per session
    public var averageCostPerSession: Double {
        sessionCount > 0 ? totalCost / Double(sessionCount) : 0
    }
    
    /// Last used date
    public var lastUsedDate: Date? {
        ISO8601DateFormatter().date(from: lastUsed)
    }
}

/// Overall usage statistics
public struct UsageStats: Codable {
    public let totalCost: Double
    public let totalTokens: Int
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCacheCreationTokens: Int
    public let totalCacheReadTokens: Int
    public let totalSessions: Int
    public let byModel: [ModelUsage]
    public let byDate: [DailyUsage]
    public let byProject: [ProjectUsage]
    
    public init(totalCost: Double, totalTokens: Int, totalInputTokens: Int, 
                totalOutputTokens: Int, totalCacheCreationTokens: Int, 
                totalCacheReadTokens: Int, totalSessions: Int, 
                byModel: [ModelUsage], byDate: [DailyUsage], byProject: [ProjectUsage]) {
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCacheCreationTokens = totalCacheCreationTokens
        self.totalCacheReadTokens = totalCacheReadTokens
        self.totalSessions = totalSessions
        self.byModel = byModel
        self.byDate = byDate
        self.byProject = byProject
    }
    
    private enum CodingKeys: String, CodingKey {
        case totalCost = "total_cost"
        case totalTokens = "total_tokens"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCacheCreationTokens = "total_cache_creation_tokens"
        case totalCacheReadTokens = "total_cache_read_tokens"
        case totalSessions = "total_sessions"
        case byModel = "by_model"
        case byDate = "by_date"
        case byProject = "by_project"
    }
    
    /// Average cost per session
    public var averageCostPerSession: Double {
        totalSessions > 0 ? totalCost / Double(totalSessions) : 0
    }
    
    /// Average tokens per session
    public var averageTokensPerSession: Int {
        totalSessions > 0 ? totalTokens / totalSessions : 0
    }
    
    /// Cost per million tokens
    public var costPerMillionTokens: Double {
        totalTokens > 0 ? (totalCost / Double(totalTokens)) * 1_000_000 : 0
    }
}

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

// MARK: - Identifiable Conformance for SwiftUI

extension UsageEntry: Identifiable {
    public var id: String { "\(timestamp)-\(sessionId ?? "")" }
}

extension ModelUsage: Identifiable {
    public var id: String { model }
}

extension DailyUsage: Identifiable {
    public var id: String { date }
}

extension ProjectUsage: Identifiable {
    public var id: String { projectPath }
}

// MARK: - Model Pricing

/// Claude model pricing information
public struct ModelPricing {
    public let model: String
    public let inputPricePerMillion: Double
    public let outputPricePerMillion: Double
    public let cacheWritePricePerMillion: Double
    public let cacheReadPricePerMillion: Double
    
    /// Predefined pricing for Claude Opus 4/4.5
    public static let opus4 = ModelPricing(
        model: "claude-opus-4-5-20251101",
        inputPricePerMillion: 5.0,
        outputPricePerMillion: 25.0,
        cacheWritePricePerMillion: 6.25,
        cacheReadPricePerMillion: 0.50
    )

    /// Predefined pricing for Claude Sonnet 4/4.5
    public static let sonnet4 = ModelPricing(
        model: "claude-sonnet-4-5-20250929",
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheWritePricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30
    )

    /// Predefined pricing for Claude Haiku 4.5
    public static let haiku4 = ModelPricing(
        model: "claude-haiku-4-5-20251001",
        inputPricePerMillion: 0.80,
        outputPricePerMillion: 4.0,
        cacheWritePricePerMillion: 1.0,
        cacheReadPricePerMillion: 0.08
    )

    /// All available model pricing
    public static let all = [opus4, sonnet4, haiku4]

    /// Find pricing for a model name
    public static func pricing(for model: String) -> ModelPricing? {
        let modelLower = model.lowercased()

        if modelLower.contains("opus") {
            return opus4
        }

        if modelLower.contains("sonnet") {
            return sonnet4
        }

        if modelLower.contains("haiku") {
            return haiku4
        }

        return sonnet4
    }
    
    /// Calculate cost for given token counts
    /// Note: Cache read tokens are included to match Claude's Rust backend calculation
    public func calculateCost(inputTokens: Int, outputTokens: Int, cacheWriteTokens: Int = 0, cacheReadTokens: Int = 0) -> Double {
        let inputCost = (Double(inputTokens) / 1_000_000) * inputPricePerMillion
        let outputCost = (Double(outputTokens) / 1_000_000) * outputPricePerMillion
        let cacheWriteCost = (Double(cacheWriteTokens) / 1_000_000) * cacheWritePricePerMillion
        let cacheReadCost = (Double(cacheReadTokens) / 1_000_000) * cacheReadPricePerMillion
        
        return inputCost + outputCost + cacheWriteCost + cacheReadCost // Including all costs like Rust backend
    }
}
