//
//  SessionMonitorTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsageData
@testable import ClaudeUsageCore

@Suite("SessionMonitor")
struct SessionMonitorTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("initializes with default parameters")
    func initializesWithDefaults() async {
        let monitor = SessionMonitor()
        let session = await monitor.getActiveSession()

        // May or may not have an active session
        print("Active session: \(session != nil ? "yes" : "no")")
        if let session = session {
            print("  Start: \(session.startTime)")
            print("  Tokens: \(session.tokens.total)")
            print("  Cost: $\(String(format: "%.2f", session.costUSD))")
            print("  Token limit: \(session.tokenLimit.map { String($0) } ?? "none")")
        }
    }

    @Test("measures getActiveSession performance")
    func measuresGetActiveSessionPerformance() async {
        let monitor = SessionMonitor(basePath: basePath)

        // First call - cold cache
        let start1 = Date()
        _ = await monitor.getActiveSession()
        let coldDuration = Date().timeIntervalSince(start1)

        // Second call - warm cache (file timestamps cached)
        let start2 = Date()
        _ = await monitor.getActiveSession()
        let warmDuration = Date().timeIntervalSince(start2)

        print("SessionMonitor.getActiveSession() performance:")
        print("  Cold: \(String(format: "%.3f", coldDuration))s")
        print("  Warm: \(String(format: "%.3f", warmDuration))s")
        print("  Speedup: \(String(format: "%.1f", coldDuration / warmDuration))x")

        #expect(warmDuration < coldDuration, "Warm cache should be faster")
    }

    @Test("measures getAutoTokenLimit performance")
    func measuresGetAutoTokenLimitPerformance() async {
        let monitor = SessionMonitor(basePath: basePath)

        // Pre-warm cache
        _ = await monitor.getActiveSession()

        let start = Date()
        let limit = await monitor.getAutoTokenLimit()
        let duration = Date().timeIntervalSince(start)

        print("SessionMonitor.getAutoTokenLimit():")
        print("  Duration: \(String(format: "%.3f", duration))s")
        print("  Limit: \(limit.map { String($0) } ?? "none")")

        // Should be fast since session is cached internally
        #expect(duration < 0.5, "Token limit should use cached data")
    }

    @Test("verifies session block structure")
    func verifiesSessionBlockStructure() async {
        let monitor = SessionMonitor(basePath: basePath)
        guard let session = await monitor.getActiveSession() else {
            print("No active session to verify")
            return
        }

        // Verify structure
        #expect(!session.id.isEmpty)
        #expect(session.isActive)
        #expect(session.startTime < Date())
        #expect(session.endTime > session.startTime)
        #expect(session.entries.count > 0)
        #expect(session.tokens.total > 0)
        #expect(!session.models.isEmpty)

        print("Session block verified:")
        print("  ID: \(session.id.prefix(8))...")
        print("  Duration: \(String(format: "%.1f", session.duration / 60)) min")
        print("  Entries: \(session.entries.count)")
        print("  Models: \(session.models.joined(separator: ", "))")
        print("  Burn rate: \(session.burnRate.tokensPerMinute) tok/min")
    }

    @Test("clearCache resets state")
    func clearCacheResetsState() async {
        let monitor = SessionMonitor(basePath: basePath)

        // Load data
        _ = await monitor.getActiveSession()

        // Clear
        await monitor.clearCache()

        // Re-load should work
        let session = await monitor.getActiveSession()
        print("Session after clearCache: \(session != nil ? "found" : "none")")
    }
}
