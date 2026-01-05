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
            #expect(hasEntries(session))
        }
    }

    // MARK: - Pure Validation Functions

    private func hasEntries(_ session: UsageSession) -> Bool {
        session.entries.count > 0
    }

    private func hasValidTimeRange(_ session: UsageSession) -> Bool {
        session.startTime < Date() && session.endTime > session.startTime
    }

    private func hasTokenUsage(_ session: UsageSession) -> Bool {
        session.tokens.total > 0
    }

    private func hasModels(_ session: UsageSession) -> Bool {
        !session.models.isEmpty
    }
}
