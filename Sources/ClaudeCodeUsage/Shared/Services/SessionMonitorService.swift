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

// MARK: - Cache Configuration

private enum CacheConfig {
    static let ttl: TimeInterval = 2.0
}

// MARK: - Pure Functions

private func isCacheValid(timestamp: Date, ttl: TimeInterval = CacheConfig.ttl) -> Bool {
    Date().timeIntervalSince(timestamp) < ttl
}

private func cacheAge(from timestamp: Date) -> TimeInterval {
    Date().timeIntervalSince(timestamp)
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
            logCacheHit("getActiveSession", age: cacheAge(from: cached.timestamp))
            return cached.session
        }

        let start = Date()
        let result = await monitor.getActiveBlock()
        let duration = Date().timeIntervalSince(start)
        cachedSession = (result, Date())
        logFetch("getActiveSession", duration: duration, found: result != nil)
        return result
    }

    func getBurnRate() async -> BurnRate? {
        let start = Date()
        let result = await getActiveSession()?.burnRate
        let duration = Date().timeIntervalSince(start)
        logFetch("getBurnRate", duration: duration, found: result != nil)
        return result
    }

    func getAutoTokenLimit() async -> Int? {
        if let cached = cachedTokenLimit, isCacheValid(timestamp: cached.timestamp) {
            logCacheHit("getAutoTokenLimit", age: cacheAge(from: cached.timestamp))
            return cached.limit
        }

        let start = Date()
        let result = await monitor.getAutoTokenLimit()
        let duration = Date().timeIntervalSince(start)
        cachedTokenLimit = (result, Date())
        logFetch("getAutoTokenLimit", duration: duration, value: result)
        return result
    }
}

// MARK: - Infrastructure Helpers

private func timed<T>(_ operation: () async -> T) async -> (result: T, duration: TimeInterval) {
    let start = Date()
    let result = await operation()
    return (result, Date().timeIntervalSince(start))
}

private func logCacheHit(_ method: String, age: TimeInterval) {
    #if DEBUG
    print("[SessionMonitorService] \(method) returned from cache (age: \(String(format: "%.3f", age))s)")
    #endif
}

private func logFetch(_ method: String, duration: TimeInterval, found: Bool) {
    #if DEBUG
    print("[SessionMonitorService] \(method) completed in \(String(format: "%.3f", duration))s - \(found ? "found" : "none")")
    #endif
}

private func logFetch(_ method: String, duration: TimeInterval, value: Int?) {
    #if DEBUG
    print("[SessionMonitorService] \(method) completed in \(String(format: "%.3f", duration))s - limit: \(value ?? 0)")
    #endif
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
