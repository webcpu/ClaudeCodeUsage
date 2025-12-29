//
//  PricingCalculator.swift
//  ClaudeUsageCore
//
//  Pure functions for cost calculations
//

import Foundation

// MARK: - Pricing Calculator

public enum PricingCalculator {
    /// Calculate cost for token usage on a specific model
    public static func calculateCost(
        tokens: TokenCounts,
        model: String
    ) -> Double {
        let pricing = modelPricing(for: model)
        return calculateCost(tokens: tokens, pricing: pricing)
    }

    /// Calculate cost with explicit pricing
    public static func calculateCost(
        tokens: TokenCounts,
        pricing: ModelPricing
    ) -> Double {
        let inputCost = Double(tokens.input) * pricing.inputPerToken
        let outputCost = Double(tokens.output) * pricing.outputPerToken
        let cacheWriteCost = Double(tokens.cacheCreation) * pricing.cacheWritePerToken
        let cacheReadCost = Double(tokens.cacheRead) * pricing.cacheReadPerToken
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    /// Get pricing for a model
    public static func modelPricing(for model: String) -> ModelPricing {
        let normalizedModel = model.lowercased()

        if normalizedModel.contains("opus") {
            return .opus
        } else if normalizedModel.contains("sonnet") {
            return .sonnet
        } else if normalizedModel.contains("haiku") {
            return .haiku
        }

        // Default to sonnet pricing for unknown models
        return .sonnet
    }
}

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

    // Current pricing as of 2024
    public static let opus = ModelPricing(
        inputPerMillion: 15.0,
        outputPerMillion: 75.0,
        cacheWritePerMillion: 18.75,
        cacheReadPerMillion: 1.50
    )

    public static let sonnet = ModelPricing(
        inputPerMillion: 3.0,
        outputPerMillion: 15.0,
        cacheWritePerMillion: 3.75,
        cacheReadPerMillion: 0.30
    )

    public static let haiku = ModelPricing(
        inputPerMillion: 0.25,
        outputPerMillion: 1.25,
        cacheWritePerMillion: 0.30,
        cacheReadPerMillion: 0.03
    )
}
