//
//  ModelPricing.swift
//  ClaudeUsageCore
//

import Foundation

// MARK: - Model Pricing

public struct ModelPricing: Sendable, Hashable {
    public let inputPerToken: Double
    public let outputPerToken: Double
    public let cacheWritePerToken: Double
    public let cacheReadPerToken: Double

    public init(
        inputPerMillion: Double,
        outputPerMillion: Double,
        cacheWritePerMillion: Double,
        cacheReadPerMillion: Double
    ) {
        self.inputPerToken = inputPerMillion / 1_000_000
        self.outputPerToken = outputPerMillion / 1_000_000
        self.cacheWritePerToken = cacheWritePerMillion / 1_000_000
        self.cacheReadPerToken = cacheReadPerMillion / 1_000_000
    }

    // Claude 4/4.5 pricing (December 2025)
    // Cache: write = 1.25x input, read = 0.1x input
    public static let opus = ModelPricing(
        inputPerMillion: 5.0,
        outputPerMillion: 25.0,
        cacheWritePerMillion: 6.25,
        cacheReadPerMillion: 0.50
    )

    public static let sonnet = ModelPricing(
        inputPerMillion: 3.0,
        outputPerMillion: 15.0,
        cacheWritePerMillion: 3.75,
        cacheReadPerMillion: 0.30
    )

    public static let haiku = ModelPricing(
        inputPerMillion: 1.0,
        outputPerMillion: 5.0,
        cacheWritePerMillion: 1.25,
        cacheReadPerMillion: 0.10
    )
}
