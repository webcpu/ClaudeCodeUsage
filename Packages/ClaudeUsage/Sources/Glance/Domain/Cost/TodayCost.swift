//
//  TodayCost.swift
//  Today's cumulative spending with hourly breakdown
//

import Foundation

public struct TodayCost: Sendable, Equatable {
    public let total: Double
    public let hourlyCosts: [Double]

    public var formatted: String { total.asCurrency }

    public init(total: Double, hourlyCosts: [Double]) {
        self.total = total
        self.hourlyCosts = hourlyCosts
    }

    public init(entries: [UsageEntry], referenceDate: Date = Date()) {
        self.total = entries.reduce(0.0) { $0 + $1.costUSD }
        self.hourlyCosts = Self.calculateHourlyCosts(from: entries)
    }

    public static var zero: TodayCost {
        TodayCost(total: 0, hourlyCosts: Array(repeating: 0, count: 24))
    }

    private static func calculateHourlyCosts(from entries: [UsageEntry]) -> [Double] {
        entries.reduce(into: Array(repeating: 0.0, count: 24)) { costs, entry in
            let hour = Calendar.current.component(.hour, from: entry.timestamp)
            costs[hour] += entry.costUSD
        }
    }
}
