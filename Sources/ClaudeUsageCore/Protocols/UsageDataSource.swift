//
//  UsageDataSource.swift
//  ClaudeUsageCore
//
//  Protocols defining usage data access capabilities
//

import Foundation

// MARK: - UsageDataSource

/// Provides access to usage data
public protocol UsageDataSource: Sendable {
    /// Get all usage entries for today
    func getTodayEntries() async throws -> [UsageEntry]

    /// Get aggregated usage statistics
    func getUsageStats() async throws -> UsageStats

    /// Get all raw usage entries (for detailed analysis)
    func getAllEntries() async throws -> [UsageEntry]
}

// MARK: - SessionDataSource

/// Provides access to live session data
public protocol SessionDataSource: Sendable {
    /// Get the currently active session block, if any
    func getActiveSession() async -> SessionBlock?

    /// Get the current burn rate
    func getBurnRate() async -> BurnRate?

    /// Get the auto-detected token limit
    func getAutoTokenLimit() async -> Int?
}
