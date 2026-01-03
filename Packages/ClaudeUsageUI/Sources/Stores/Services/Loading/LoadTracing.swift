//
//  LoadTracing.swift
//  Protocol for load operation tracing (DIP)
//

import Foundation

/// Protocol for load operation tracing.
/// Enables dependency injection and testability.
public protocol LoadTracing: Actor {
    /// Start a new load trace, returns unique ID
    func start() -> UUID

    /// Mark start of a phase
    func phaseStart(_ phase: LoadPhase)

    /// Mark completion of a phase
    func phaseComplete(_ phase: LoadPhase)

    /// Record session monitor results
    func recordSession(found: Bool, cached: Bool, duration: TimeInterval, tokenLimit: Int?)

    /// Mark history loading as skipped
    func skipHistory()

    /// Complete the load trace and log summary
    func complete()
}

// MARK: - Default Implementation

extension LoadTrace: LoadTracing {}
