//
//  UsageProviding.swift
//  Protocol for usage data access
//

import Foundation

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
