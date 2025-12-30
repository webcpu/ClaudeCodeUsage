//
//  SessionMonitorService.swift
//  Service for monitoring active Claude sessions
//

import Foundation
import ClaudeUsageCore
import ClaudeUsageData

// MARK: - Protocol

protocol SessionMonitorService: Sendable {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Default Implementation

actor DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: SessionMonitor
    private var cachedSession: (session: SessionBlock?, timestamp: Date)?

    init(configuration: AppConfiguration) {
        self.monitor = SessionMonitor(
            basePath: configuration.basePath,
            sessionDurationHours: configuration.sessionDurationHours
        )
    }

    func getActiveSession() async -> SessionBlock? {
        if let cached = cachedSession, isCacheValid(timestamp: cached.timestamp) {
            return cached.session
        }

        let session = await monitor.getActiveSession()
        cachedSession = (session, Date())
        return session
    }

    func getBurnRate() async -> BurnRate? {
        await getActiveSession()?.burnRate
    }

    func getAutoTokenLimit() async -> Int? {
        // Derive from session to avoid redundant monitor call
        // (SessionBlock.tokenLimit is populated by getActiveSession)
        await getActiveSession()?.tokenLimit
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
