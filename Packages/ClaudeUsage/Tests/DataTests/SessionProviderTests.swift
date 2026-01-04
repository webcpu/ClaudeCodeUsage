//
//  SessionProviderTests.swift
//  ClaudeUsageDataTests
//

import Testing
import Foundation
@testable import ClaudeUsage

@Suite("SessionProvider")
struct SessionProviderTests {
    private let basePath = NSHomeDirectory() + "/.claude"

    @Test("active session has valid structure")
    func activeSessionHasValidStructure() async {
        let provider = SessionProvider(basePath: basePath)
        guard let session = await provider.getActiveSession() else {
            return
        }

        #expect(hasValidIdentifier(session))
        #expect(session.isActive)
        #expect(hasValidTimeRange(session))
        #expect(hasEntries(session))
        #expect(hasTokenUsage(session))
        #expect(hasModels(session))
    }

    @Test("clearCache allows fresh data fetch")
    func clearCacheAllowsFreshFetch() async {
        let provider = SessionProvider(basePath: basePath)
        _ = await provider.getActiveSession()
        await provider.clearCache()

        let session = await provider.getActiveSession()

        if let session = session {
            #expect(hasValidIdentifier(session))
            #expect(hasEntries(session))
        }
    }

    @Test("token limit returns value when session exists")
    func tokenLimitReturnsValueWhenSessionExists() async {
        let provider = SessionProvider(basePath: basePath)
        let session = await provider.getActiveSession()
        let limit = await provider.getAutoTokenLimit()

        if session != nil {
            #expect(limit != nil, "Should have token limit when session exists")
        }
    }

    // MARK: - Pure Validation Functions

    private func hasValidIdentifier(_ session: SessionBlock) -> Bool {
        !session.id.isEmpty
    }

    private func hasEntries(_ session: SessionBlock) -> Bool {
        session.entries.count > 0
    }

    private func hasValidTimeRange(_ session: SessionBlock) -> Bool {
        session.startTime < Date() && session.endTime > session.startTime
    }

    private func hasTokenUsage(_ session: SessionBlock) -> Bool {
        session.tokens.total > 0
    }

    private func hasModels(_ session: SessionBlock) -> Bool {
        !session.models.isEmpty
    }
}
