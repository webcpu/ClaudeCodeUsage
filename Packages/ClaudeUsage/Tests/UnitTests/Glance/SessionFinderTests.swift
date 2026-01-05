//
//  SessionFinderTests.swift
//  ClaudeUsageCoreTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("SessionFinder")
struct SessionFinderTests {

    // MARK: - findSessions

    @Test("returns empty array for empty entries")
    func findSessionsEmptyEntries() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let result = finder.findSessions(from: [], now: Date())

        #expect(result.isEmpty)
    }

    @Test("creates single session for continuous entries")
    func findSessionsSingleSession() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 60, from: now),
            TestSessionEntry.entry(minutesAgo: 30, from: now),
            TestSessionEntry.entry(minutesAgo: 5, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].entries.count == 3)
        #expect(result[0].isActive)
    }

    @Test("splits entries at session gaps")
    func findSessionsSplitsAtGaps() {
        let finder = SessionFinder(sessionDurationHours: 1.0) // 1 hour gap threshold
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 300, from: now), // Session 1: 5 hours ago
            TestSessionEntry.entry(minutesAgo: 290, from: now), // Session 1
            TestSessionEntry.entry(minutesAgo: 60, from: now),  // Session 2: 1 hour ago (gap > 1 hour)
            TestSessionEntry.entry(minutesAgo: 30, from: now)   // Session 2
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 2)
        #expect(result[0].entries.count == 2) // Historical session
        #expect(!result[0].isActive)
        #expect(result[1].entries.count == 2) // Recent session
        #expect(result[1].isActive)
    }

    @Test("marks historical sessions as inactive")
    func findSessionsHistoricalInactive() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 180, from: now), // 3 hours ago
            TestSessionEntry.entry(minutesAgo: 170, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(!result[0].isActive) // No recent activity, should be inactive
    }

    // MARK: - findActiveSession

    @Test("returns nil when no active sessions")
    func findActiveSessionNone() {
        let finder = SessionFinder()
        let inactiveSessions = [
            TestSessionEntry.session(isActive: false),
            TestSessionEntry.session(isActive: false)
        ]

        let result = finder.findActiveSession(in: inactiveSessions)

        #expect(result == nil)
    }

    @Test("returns the active session when one exists")
    func findActiveSessionSingle() {
        let finder = SessionFinder()
        let sessions = [
            TestSessionEntry.session(isActive: false),
            TestSessionEntry.session(isActive: true),
            TestSessionEntry.session(isActive: false)
        ]

        let result = finder.findActiveSession(in: sessions)

        #expect(result != nil)
        #expect(result?.isActive == true)
    }

    @Test("returns most recent active session when multiple exist")
    func findActiveSessionMostRecent() {
        let finder = SessionFinder()
        let now = Date()
        let sessions = [
            TestSessionEntry.session(isActive: true, endTime: now.addingTimeInterval(-3600)),
            TestSessionEntry.session(isActive: true, endTime: now)
        ]

        let result = finder.findActiveSession(in: sessions)

        #expect(result?.actualEndTime == now)
    }

    // MARK: - maxTokensFromCompletedSessions

    @Test("returns zero for empty sessions")
    func maxTokensEmpty() {
        let finder = SessionFinder()

        let result = finder.maxTokensFromCompletedSessions([])

        #expect(result == 0)
    }

    @Test("returns zero when only active sessions exist")
    func maxTokensOnlyActive() {
        let finder = SessionFinder()
        let sessions = [
            TestSessionEntry.session(isActive: true, tokens: TokenCounts(input: 1000, output: 500))
        ]

        let result = finder.maxTokensFromCompletedSessions(sessions)

        #expect(result == 0)
    }

    @Test("returns max tokens from completed sessions")
    func maxTokensFromCompleted() {
        let finder = SessionFinder()
        let sessions = [
            TestSessionEntry.session(isActive: false, tokens: TokenCounts(input: 100, output: 50)),
            TestSessionEntry.session(isActive: false, tokens: TokenCounts(input: 500, output: 200)),
            TestSessionEntry.session(isActive: true, tokens: TokenCounts(input: 2000, output: 1000))
        ]

        let result = finder.maxTokensFromCompletedSessions(sessions)

        #expect(result == 700) // 500 + 200 from second completed session
    }

    // MARK: - Session Duration Configuration

    @Test("uses custom session duration for gap detection")
    func customSessionDuration() {
        let finder = SessionFinder(sessionDurationHours: 0.5) // 30 minute gap
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 60, from: now),  // Session 1
            TestSessionEntry.entry(minutesAgo: 10, from: now)   // Session 2 (gap > 30 min)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 2)
    }

    // MARK: - Aggregations

    @Test("aggregates tokens from session entries")
    func aggregatesTokens() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 30, from: now, tokens: TokenCounts(input: 100, output: 50)),
            TestSessionEntry.entry(minutesAgo: 10, from: now, tokens: TokenCounts(input: 200, output: 100))
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].tokens.input == 300)
        #expect(result[0].tokens.output == 150)
    }

    @Test("aggregates cost from session entries")
    func aggregatesCost() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 30, from: now, cost: 1.50),
            TestSessionEntry.entry(minutesAgo: 10, from: now, cost: 2.25)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].costUSD == 3.75)
    }

    @Test("collects unique models from session entries")
    func collectsUniqueModels() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            TestSessionEntry.entry(minutesAgo: 30, from: now, model: "claude-opus"),
            TestSessionEntry.entry(minutesAgo: 20, from: now, model: "claude-sonnet"),
            TestSessionEntry.entry(minutesAgo: 10, from: now, model: "claude-opus")
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].models.count == 2)
        #expect(result[0].models.contains("claude-opus"))
        #expect(result[0].models.contains("claude-sonnet"))
    }
}

// MARK: - Test Helpers

private enum TestSessionEntry {

    static func entry(
        minutesAgo: Int,
        from now: Date,
        model: String = "claude-sonnet",
        tokens: TokenCounts = .zero,
        cost: Double = 0.0
    ) -> UsageEntry {
        UsageEntry(
            id: UUID().uuidString,
            timestamp: now.addingTimeInterval(TimeInterval(-minutesAgo * 60)),
            model: model,
            tokens: tokens,
            costUSD: cost,
            project: "test-project",
            sourceFile: "test.jsonl",
            sessionId: UUID().uuidString
        )
    }

    static func session(
        isActive: Bool,
        tokens: TokenCounts = .zero,
        endTime: Date? = nil
    ) -> UsageSession {
        let now = Date()
        return UsageSession(
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            actualEndTime: endTime ?? now,
            isActive: isActive,
            entries: [],
            tokens: tokens,
            costUSD: 0.0,
            models: [],
            burnRate: .zero
        )
    }
}
