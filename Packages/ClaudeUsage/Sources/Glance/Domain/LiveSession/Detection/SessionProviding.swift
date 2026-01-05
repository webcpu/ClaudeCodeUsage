//
//  SessionProviding.swift
//  Protocol for session data access
//

import Foundation

/// Provides access to live session data.
public protocol SessionProviding: Sendable {
    /// Get the currently active session block, if any.
    /// UsageSession contains: time bounds, tokens, burnRate, models, entries.
    func getActiveSession() async -> UsageSession?
}
