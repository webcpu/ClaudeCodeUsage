//
//  DailyUsage.swift
//  ClaudeUsageCore
//

import Foundation

// MARK: - DailyUsage

public struct DailyUsage: Sendable, Hashable, Identifiable {
    public let date: String
    public let totalCost: Double
    public let totalTokens: Int
    public let modelsUsed: [String]
    public let hourlyCosts: [Double]

    public var id: String { date }

    public init(
        date: String,
        totalCost: Double,
        totalTokens: Int,
        modelsUsed: [String] = [],
        hourlyCosts: [Double] = []
    ) {
        self.date = date
        self.totalCost = totalCost
        self.totalTokens = totalTokens
        self.modelsUsed = modelsUsed
        self.hourlyCosts = hourlyCosts.isEmpty ? Array(repeating: 0, count: 24) : hourlyCosts
    }

    public var parsedDate: Date? {
        Self.dateFormatter.date(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
