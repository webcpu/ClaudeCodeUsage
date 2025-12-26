//
//  SessionMonitorService.swift
//  Service for monitoring active Claude sessions
//

import Foundation
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
import class ClaudeLiveMonitorLib.LiveMonitor
import struct ClaudeLiveMonitorLib.LiveMonitorConfig

// MARK: - Protocol

protocol SessionMonitorService {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Default Implementation

final class DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: LiveMonitor

    // Cache for session data with short TTL
    private var cachedSession: (session: SessionBlock?, timestamp: Date)?
    private var cachedTokenLimit: (limit: Int?, timestamp: Date)?
    private let cacheTTL: TimeInterval = 2.0

    init(configuration: AppConfiguration) {
        let config = LiveMonitorConfig(
            claudePaths: [configuration.basePath],
            sessionDurationHours: configuration.sessionDurationHours,
            tokenLimit: nil,
            refreshInterval: 2.0,
            order: .descending
        )
        self.monitor = LiveMonitor(config: config)
    }

    func getActiveSession() async -> SessionBlock? {
        let startTime = Date()

        // Check cache first
        if let cached = cachedSession,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            #if DEBUG
            print("[SessionMonitorService] getActiveSession returned from cache (age: \(String(format: "%.3f", Date().timeIntervalSince(cached.timestamp)))s)")
            #endif
            return cached.session
        }

        // Load fresh data
        let result = await monitor.getActiveBlock()

        // Update cache
        cachedSession = (result, Date())

        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getActiveSession completed in \(String(format: "%.3f", duration))s - session: \(result != nil ? "found" : "none")")
        #endif
        return result
    }

    func getBurnRate() async -> BurnRate? {
        let startTime = Date()
        let result = await getActiveSession()?.burnRate
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getBurnRate completed in \(String(format: "%.3f", duration))s")
        #endif
        return result
    }

    func getAutoTokenLimit() async -> Int? {
        let startTime = Date()

        // Check cache first
        if let cached = cachedTokenLimit,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            #if DEBUG
            print("[SessionMonitorService] getAutoTokenLimit returned from cache (age: \(String(format: "%.3f", Date().timeIntervalSince(cached.timestamp)))s)")
            #endif
            return cached.limit
        }

        // Load fresh data
        let result = await monitor.getAutoTokenLimit()

        // Update cache
        cachedTokenLimit = (result, Date())

        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getAutoTokenLimit completed in \(String(format: "%.3f", duration))s - limit: \(result ?? 0)")
        #endif
        return result
    }
}

// MARK: - Mock for Testing

#if DEBUG
final class MockSessionMonitorService: SessionMonitorService {
    var mockSession: SessionBlock?
    var mockBurnRate: BurnRate?
    var mockTokenLimit: Int?

    func getActiveSession() -> SessionBlock? { mockSession }
    func getBurnRate() -> BurnRate? { mockBurnRate }
    func getAutoTokenLimit() -> Int? { mockTokenLimit }
}
#endif
