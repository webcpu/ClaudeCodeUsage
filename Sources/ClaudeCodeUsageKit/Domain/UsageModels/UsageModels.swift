//
//  UsageModels.swift
//  ClaudeCodeUsage
//
//  Data models for Claude Code usage statistics
//
//  Split into extensions for focused responsibilities:
//    - +TimeRange: Time range filtering enum
//    - +Pricing: Model pricing information
//

import Foundation

// MARK: - Cached Date Formatters

/// Static formatters to avoid re-allocation on every date parse (16,600+ calls)
enum DateFormatters {
    nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Usage Entry

/// Represents a single usage entry
public struct UsageEntry: Codable, Sendable {
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

// MARK: - Model Usage

/// Usage statistics aggregated by model
public struct ModelUsage: Codable, Sendable {
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

// MARK: - Daily Usage

/// Daily usage statistics
public struct DailyUsage: Codable, Sendable {
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

// MARK: - Project Usage

/// Project usage statistics
public struct ProjectUsage: Codable, Sendable {
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

// MARK: - Usage Stats

/// Overall usage statistics
public struct UsageStats: Codable, Sendable {
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

// MARK: - Identifiable Conformance

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
