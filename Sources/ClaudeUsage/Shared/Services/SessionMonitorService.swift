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

protocol SessionMonitorService: Sendable {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Default Implementation

actor DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: LiveMonitor

    private var cachedSession: (session: SessionBlock?, timestamp: Date)?
    private var cachedTokenLimit: (limit: Int?, timestamp: Date)?

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
        if let cached = cachedSession, isCacheValid(timestamp: cached.timestamp) {
            return cached.session
        }

        let result = await monitor.getActiveBlock()
        cachedSession = (result, Date())
        return result
    }

    func getBurnRate() async -> BurnRate? {
        await getActiveSession()?.burnRate
    }

    func getAutoTokenLimit() async -> Int? {
        if let cached = cachedTokenLimit, isCacheValid(timestamp: cached.timestamp) {
            return cached.limit
        }

        let result = await monitor.getAutoTokenLimit()
        cachedTokenLimit = (result, Date())
        return result
    }
}

// MARK: - Supporting Types

private enum CacheConfig {
    static let ttl: TimeInterval = 2.0
}

// MARK: - Pure Functions

private func isCacheValid(timestamp: Date, ttl: TimeInterval = CacheConfig.ttl) -> Bool {
    Date().timeIntervalSince(timestamp) < ttl
}

// MARK: - Mock for Testing

#if DEBUG
final class MockSessionMonitorService: SessionMonitorService, @unchecked Sendable {
    var mockSession: SessionBlock?
    var mockBurnRate: BurnRate?
    var mockTokenLimit: Int?

    func getActiveSession() async -> SessionBlock? { mockSession }
    func getBurnRate() async -> BurnRate? { mockBurnRate }
    func getAutoTokenLimit() async -> Int? { mockTokenLimit }
}
#endif
