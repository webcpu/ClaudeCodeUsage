//
//  BurnRate.swift
//  ClaudeUsageCore
//
//  Token consumption rate metrics
//

import Foundation

// MARK: - BurnRate

public struct BurnRate: Sendable, Hashable {
    public let tokensPerMinute: Int
    public let costPerHour: Double

    public init(tokensPerMinute: Int, costPerHour: Double) {
        self.tokensPerMinute = tokensPerMinute
        self.costPerHour = costPerHour
    }

    public static var zero: BurnRate {
        BurnRate(tokensPerMinute: 0, costPerHour: 0)
    }
}

// MARK: - Derived Metrics

public extension BurnRate {
    var tokensPerHour: Int {
        tokensPerMinute * 60
    }

    var costPerMinute: Double {
        costPerHour / 60.0
    }

    /// Indicator level (0-4) for UI display
    var indicatorLevel: Int {
        switch tokensPerMinute {
        case 0: return 0
        case 1..<1000: return 1
        case 1000..<5000: return 2
        case 5000..<10000: return 3
        default: return 4
        }
    }
}
