//
//  TodayCostProviding.swift
//  Protocol for today's cost data access
//

import Foundation

/// Provides access to today's cost data.
public protocol TodayCostProviding: Sendable {
    /// Get today's cumulative cost with hourly breakdown.
    func getTodayCost() async throws -> TodayCost
}
