//
//  UsageEntry.swift
//  ClaudeUsageCore
//
//  Single source of truth for Claude usage entries
//

import Foundation

// MARK: - UsageEntry

public struct UsageEntry: Sendable, Hashable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let model: String
    public let tokens: TokenCounts
    public let costUSD: Double
    public let project: String
    public let sourceFile: String
    public let sessionId: String?
    public let messageId: String?
    public let requestId: String?

    public init(
        id: String? = nil,
        timestamp: Date,
        model: String,
        tokens: TokenCounts,
        costUSD: Double,
        project: String,
        sourceFile: String,
        sessionId: String? = nil,
        messageId: String? = nil,
        requestId: String? = nil
    ) {
        self.id = id ?? "\(timestamp.timeIntervalSince1970)-\(messageId ?? UUID().uuidString)"
        self.timestamp = timestamp
        self.model = model
        self.tokens = tokens
        self.costUSD = costUSD
        self.project = project
        self.sourceFile = sourceFile
        self.sessionId = sessionId
        self.messageId = messageId
        self.requestId = requestId
    }
}

// MARK: - Convenience

public extension UsageEntry {
    var totalTokens: Int { tokens.total }
}

// MARK: - Comparable (by timestamp)

extension UsageEntry: Comparable {
    public static func < (lhs: UsageEntry, rhs: UsageEntry) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
