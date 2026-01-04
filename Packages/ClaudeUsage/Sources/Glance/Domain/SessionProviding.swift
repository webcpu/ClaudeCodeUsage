//
//  SessionProviding.swift
//  Protocol for session data access
//

import Foundation

/// Provides access to live session data.
public protocol SessionProviding: Sendable {
    /// Get the currently active session block, if any.
    func getActiveSession() async -> UsageSession?

    /// Get the current burn rate.
    func getBurnRate() async -> BurnRate?

    /// Get the auto-detected token limit.
    func getAutoTokenLimit() async -> Int?
}
