//
//  SessionFinderTests.swift
//
//  Specification for SessionFinder - pure domain logic for session detection.
//
//  This test suite serves as the complete specification for SessionFinder.
//  Reading these tests should tell you exactly how to implement SessionFinder.
//

import Testing
import Foundation
@testable import ClaudeUsage

// MARK: - SessionFinder Specification

/// SessionFinder is a struct that finds session boundaries from usage entries.
/// It is pure domain logic with no I/O dependencies.
@Suite("SessionFinder")
struct SessionFinderTests {

    // MARK: - Type Specification

    @Test("is initialized with sessionDurationHours defaulting to 5.0")
    func initialization() {
        let finder = SessionFinder()
        #expect(finder.sessionDurationHours == 5.0)
    }

    @Test("accepts custom sessionDurationHours")
    func customInitialization() {
        let finder = SessionFinder(sessionDurationHours: 2.0)
        #expect(finder.sessionDurationHours == 2.0)
    }
}

// MARK: - findSessions(from:now:) Specification

@Suite("SessionFinder.findSessions")
struct FindSessionsTests {

    // MARK: - Empty Input

    @Test("returns empty array when entries is empty")
    func emptyEntries() {
        let finder = SessionFinder()
        let result = finder.findSessions(from: [], now: Date())
        #expect(result.isEmpty)
    }

    // MARK: - Single Session Detection

    @Test("returns single session when all entries within sessionDurationHours")
    func singleSession() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now),
            Fixtures.entry(minutesAgo: 20, from: now),
            Fixtures.entry(minutesAgo: 10, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].entries.count == 3)
    }

    // MARK: - Gap Detection

    @Test("splits into multiple sessions when gap exceeds sessionDurationHours")
    func gapDetection() {
        let finder = SessionFinder(sessionDurationHours: 1.0) // 1 hour threshold
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 180, from: now), // Session 1: 3 hours ago
            Fixtures.entry(minutesAgo: 170, from: now), // Session 1
            Fixtures.entry(minutesAgo: 30, from: now),  // Session 2: gap > 1 hour
            Fixtures.entry(minutesAgo: 20, from: now)   // Session 2
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 2)
        #expect(result[0].entries.count == 2)
        #expect(result[1].entries.count == 2)
    }

    @Test("gap threshold equals sessionDurationHours in seconds")
    func gapThresholdPrecision() {
        let finder = SessionFinder(sessionDurationHours: 0.5) // 30 minutes
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 60, from: now),  // Session 1
            Fixtures.entry(minutesAgo: 10, from: now)   // Session 2: gap = 50min > 30min
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 2)
    }

    // MARK: - Active Session Detection

    @Test("last session is active when last entry within sessionDurationHours of now")
    func activeSessionDetection() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now),
            Fixtures.entry(minutesAgo: 10, from: now) // Within 1 hour of now
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].isActive == true)
    }

    @Test("last session is inactive when last entry exceeds sessionDurationHours from now")
    func inactiveSessionDetection() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 120, from: now), // 2 hours ago
            Fixtures.entry(minutesAgo: 90, from: now)   // 1.5 hours ago > 1 hour threshold
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 1)
        #expect(result[0].isActive == false)
    }

    @Test("historical sessions (not last) are always inactive")
    func historicalSessionsInactive() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 180, from: now), // Session 1
            Fixtures.entry(minutesAgo: 30, from: now),  // Session 2 (gap > 1 hour)
            Fixtures.entry(minutesAgo: 10, from: now)   // Session 2
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result.count == 2)
        #expect(result[0].isActive == false) // Historical = inactive
        #expect(result[1].isActive == true)  // Last = active (recent)
    }

    // MARK: - Token Aggregation

    @Test("session.tokens equals sum of entry tokens")
    func tokenAggregation() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now, tokens: TokenCounts(input: 100, output: 50)),
            Fixtures.entry(minutesAgo: 10, from: now, tokens: TokenCounts(input: 200, output: 100))
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].tokens.input == 300)
        #expect(result[0].tokens.output == 150)
        #expect(result[0].tokens.total == 450)
    }

    // MARK: - Cost Aggregation

    @Test("session.costUSD equals sum of entry costs")
    func costAggregation() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now, cost: 1.50),
            Fixtures.entry(minutesAgo: 10, from: now, cost: 2.25)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].costUSD == 3.75)
    }

    // MARK: - Model Collection

    @Test("session.models contains unique models from entries")
    func modelCollection() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now, model: "opus"),
            Fixtures.entry(minutesAgo: 20, from: now, model: "sonnet"),
            Fixtures.entry(minutesAgo: 10, from: now, model: "opus") // Duplicate
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].models.count == 2)
        #expect(Set(result[0].models) == Set(["opus", "sonnet"]))
    }

    // MARK: - Burn Rate Calculation

    @Test("burnRate is zero when session has fewer than 2 entries")
    func burnRateSingleEntry() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 10, from: now, tokens: TokenCounts(input: 1000, output: 500), cost: 1.0)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].burnRate == .zero)
    }

    @Test("burnRate is zero when session duration less than 60 seconds")
    func burnRateShortDuration() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(secondsAgo: 30, from: now),
            Fixtures.entry(secondsAgo: 10, from: now) // Duration = 20 seconds < 60
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].burnRate == .zero)
    }

    @Test("burnRate.tokensPerMinute equals totalTokens / durationMinutes")
    func burnRateTokens() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 10, from: now, tokens: TokenCounts(input: 300, output: 300)),
            Fixtures.entry(minutesAgo: 0, from: now, tokens: TokenCounts(input: 300, output: 300))
        ]
        // Duration = 10 minutes, totalTokens = 1200
        // Expected: 1200 / 10 = 120 tokens/minute

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].burnRate.tokensPerMinute == 120)
    }

    @Test("burnRate.costPerHour equals totalCost / durationHours")
    func burnRateCost() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now, cost: 1.0),
            Fixtures.entry(minutesAgo: 0, from: now, cost: 1.0)
        ]
        // Duration = 30 minutes = 0.5 hours, totalCost = $2.00
        // Expected: 2.0 / 0.5 = $4.00/hour

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].burnRate.costPerHour == 4.0)
    }

    // MARK: - Time Window Properties

    @Test("session.startTime is set from entries")
    func sessionStartTime() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now),
            Fixtures.entry(minutesAgo: 10, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        // For active sessions with rolling window, startTime uses modulo arithmetic
        // For inactive sessions, startTime equals first entry timestamp
        #expect(result[0].startTime <= now)
    }

    @Test("session.endTime equals startTime plus sessionDurationSeconds")
    func sessionEndTime() {
        let finder = SessionFinder(sessionDurationHours: 1.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 120, from: now),
            Fixtures.entry(minutesAgo: 110, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        let expectedDuration: TimeInterval = 1.0 * 3600 // 1 hour in seconds
        let actualDuration = result[0].endTime.timeIntervalSince(result[0].startTime)
        #expect(actualDuration == expectedDuration)
    }

    @Test("session.actualEndTime equals last entry timestamp")
    func sessionActualEndTime() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let lastEntryTime = now.addingTimeInterval(-600) // 10 minutes ago
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now),
            UsageEntry(
                id: "last",
                timestamp: lastEntryTime,
                model: "sonnet",
                tokens: .zero,
                costUSD: 0,
                project: "test",
                sourceFile: "test.jsonl",
                sessionId: "session"
            )
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].actualEndTime == lastEntryTime)
    }

    @Test("session.entries contains all entries in the session")
    func sessionEntriesPreserved() {
        let finder = SessionFinder(sessionDurationHours: 5.0)
        let now = Date()
        let entries = [
            Fixtures.entry(minutesAgo: 30, from: now),
            Fixtures.entry(minutesAgo: 20, from: now),
            Fixtures.entry(minutesAgo: 10, from: now)
        ]

        let result = finder.findSessions(from: entries, now: now)

        #expect(result[0].entries.count == 3)
    }
}

// MARK: - findActiveSession(in:) Specification

@Suite("SessionFinder.findActiveSession")
struct FindActiveSessionTests {

    @Test("returns nil when sessions array is empty")
    func emptySessions() {
        let finder = SessionFinder()
        let result = finder.findActiveSession(in: [])
        #expect(result == nil)
    }

    @Test("returns nil when no sessions are active")
    func noActiveSessions() {
        let finder = SessionFinder()
        let sessions = [
            Fixtures.session(isActive: false),
            Fixtures.session(isActive: false)
        ]

        let result = finder.findActiveSession(in: sessions)

        #expect(result == nil)
    }

    @Test("returns the active session when exactly one is active")
    func singleActiveSession() {
        let finder = SessionFinder()
        let activeSession = Fixtures.session(isActive: true)
        let sessions = [
            Fixtures.session(isActive: false),
            activeSession,
            Fixtures.session(isActive: false)
        ]

        let result = finder.findActiveSession(in: sessions)

        #expect(result?.isActive == true)
    }

    @Test("returns most recent active session by actualEndTime when multiple are active")
    func multipleActiveSessions() {
        let finder = SessionFinder()
        let now = Date()
        let older = Fixtures.session(isActive: true, actualEndTime: now.addingTimeInterval(-3600))
        let newer = Fixtures.session(isActive: true, actualEndTime: now)

        let result = finder.findActiveSession(in: [older, newer])

        #expect(result?.actualEndTime == now)
    }
}

// MARK: - maxTokensFromCompletedSessions Specification

@Suite("SessionFinder.maxTokensFromCompletedSessions")
struct MaxTokensTests {

    @Test("returns 0 when sessions array is empty")
    func emptySessions() {
        let finder = SessionFinder()
        let result = finder.maxTokensFromCompletedSessions([])
        #expect(result == 0)
    }

    @Test("returns 0 when all sessions are active")
    func onlyActiveSessions() {
        let finder = SessionFinder()
        let sessions = [
            Fixtures.session(isActive: true, tokens: TokenCounts(input: 1000, output: 500))
        ]

        let result = finder.maxTokensFromCompletedSessions(sessions)

        #expect(result == 0)
    }

    @Test("returns max tokens.total from inactive sessions only")
    func maxFromInactive() {
        let finder = SessionFinder()
        let sessions = [
            Fixtures.session(isActive: false, tokens: TokenCounts(input: 100, output: 50)),   // 150
            Fixtures.session(isActive: false, tokens: TokenCounts(input: 500, output: 200)),  // 700
            Fixtures.session(isActive: true, tokens: TokenCounts(input: 2000, output: 1000))  // Ignored
        ]

        let result = finder.maxTokensFromCompletedSessions(sessions)

        #expect(result == 700)
    }
}

// MARK: - Test Fixtures

private enum Fixtures {

    static func entry(
        minutesAgo: Int = 0,
        secondsAgo: Int? = nil,
        from now: Date,
        model: String = "claude-sonnet",
        tokens: TokenCounts = .zero,
        cost: Double = 0.0
    ) -> UsageEntry {
        let offset = secondsAgo.map { TimeInterval(-$0) } ?? TimeInterval(-minutesAgo * 60)
        return UsageEntry(
            id: UUID().uuidString,
            timestamp: now.addingTimeInterval(offset),
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
        actualEndTime: Date? = nil
    ) -> UsageSession {
        let now = Date()
        return UsageSession(
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            actualEndTime: actualEndTime ?? now,
            isActive: isActive,
            entries: [],
            tokens: tokens,
            costUSD: 0.0,
            models: [],
            burnRate: .zero
        )
    }
}
