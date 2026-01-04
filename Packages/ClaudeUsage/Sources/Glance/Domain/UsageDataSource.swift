//
//  UsageDataSource.swift
//  Protocols defining data provider capabilities
//

import Foundation

// MARK: - UsageProviding

/// Provides access to usage data.
public protocol UsageProviding: Sendable {
    /// Get all usage entries for today.
    func getTodayEntries() async throws -> [UsageEntry]

    /// Get aggregated usage statistics.
    func getUsageStats() async throws -> UsageStats

    /// Get all raw usage entries (for detailed analysis).
    func getAllEntries() async throws -> [UsageEntry]

    /// Invalidate any cached data to force fresh reads.
    func clearCache() async
}

// MARK: - SessionProviding

/// Provides access to live session data.
public protocol SessionProviding: Sendable {
    /// Get the currently active session block, if any.
    func getActiveSession() async -> SessionBlock?

    /// Get the current burn rate.
    func getBurnRate() async -> BurnRate?

    /// Get the auto-detected token limit.
    func getAutoTokenLimit() async -> Int?
}
