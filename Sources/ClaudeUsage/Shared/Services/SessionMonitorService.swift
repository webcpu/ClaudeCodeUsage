//
//  SessionMonitorService.swift
//  Service for monitoring active Claude sessions
//

import Foundation
import ClaudeUsageCore
import ClaudeLiveMonitorLib

// MARK: - Protocol

protocol SessionMonitorService: Sendable {
    func getActiveSession() async -> ClaudeUsageCore.SessionBlock?
    func getBurnRate() async -> ClaudeUsageCore.BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Default Implementation

actor DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: LiveMonitor

    private var cachedSession: (session: ClaudeUsageCore.SessionBlock?, timestamp: Date)?
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

    func getActiveSession() async -> ClaudeUsageCore.SessionBlock? {
        if let cached = cachedSession, isCacheValid(timestamp: cached.timestamp) {
            return cached.session
        }

        let lmSession = await monitor.getActiveBlock()
        let session = lmSession.map { ClaudeUsageCore.SessionBlock(from: $0) }
        cachedSession = (session, Date())
        return session
    }

    func getBurnRate() async -> ClaudeUsageCore.BurnRate? {
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
    var mockSession: ClaudeUsageCore.SessionBlock?
    var mockBurnRate: ClaudeUsageCore.BurnRate?
    var mockTokenLimit: Int?

    func getActiveSession() async -> ClaudeUsageCore.SessionBlock? { mockSession }
    func getBurnRate() async -> ClaudeUsageCore.BurnRate? { mockBurnRate }
    func getAutoTokenLimit() async -> Int? { mockTokenLimit }
}
#endif
