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

    @Test("active session has valid structure")
    func activeSessionHasValidStructure() async {
        let monitor = SessionMonitor(basePath: basePath)
        guard let session = await monitor.getActiveSession() else {
            // No active session is valid state
            return
        }

        #expect(!session.id.isEmpty)
        #expect(session.isActive)
        #expect(session.startTime < Date())
        #expect(session.endTime > session.startTime)
        #expect(session.entries.count > 0)
        #expect(session.tokens.total > 0)
        #expect(!session.models.isEmpty)
    }

    @Test("clearCache allows fresh data fetch")
    func clearCacheAllowsFreshFetch() async {
        let monitor = SessionMonitor(basePath: basePath)

        // Load data
        _ = await monitor.getActiveSession()

        // Clear cache
        await monitor.clearCache()

        // Should be able to reload without error
        let session = await monitor.getActiveSession()

        // Verify structure if session exists
        if let session = session {
            #expect(!session.id.isEmpty)
            #expect(session.entries.count > 0)
        }
    }

    @Test("token limit returns value when session exists")
    func tokenLimitReturnsValueWhenSessionExists() async {
        let monitor = SessionMonitor(basePath: basePath)
        let session = await monitor.getActiveSession()
        let limit = await monitor.getAutoTokenLimit()

        if session != nil {
            #expect(limit != nil, "Should have token limit when session exists")
        }
    }
}
