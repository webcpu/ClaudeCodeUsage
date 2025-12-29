//
//  UsageRepository.swift
//  ClaudeUsageCore
//
//  Protocol defining usage data access
//

import Foundation

// MARK: - UsageRepository Protocol

public protocol UsageRepository: Sendable {
    /// Get all usage entries for today
    func getTodayEntries() async throws -> [UsageEntry]

    /// Get aggregated usage statistics
    func getUsageStats() async throws -> UsageStats

    /// Get all raw usage entries (for detailed analysis)
    func getAllEntries() async throws -> [UsageEntry]
}

// MARK: - SessionMonitor Protocol

public protocol SessionMonitor: Sendable {
    /// Get the currently active session block, if any
    func getActiveSession() async -> SessionBlock?

    /// Get the current burn rate
    func getBurnRate() async -> BurnRate?

    /// Get the auto-detected token limit
    func getAutoTokenLimit() async -> Int?
}
