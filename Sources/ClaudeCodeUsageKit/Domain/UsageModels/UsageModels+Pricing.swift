//
//  UsageModels+Pricing.swift
//
//  Model pricing information for cost calculations.
//

import Foundation

// MARK: - Model Pricing

/// Claude model pricing information
public struct ModelPricing: Sendable {
    public let model: String
    public let inputPricePerMillion: Double
    public let outputPricePerMillion: Double
    public let cacheWritePricePerMillion: Double
    public let cacheReadPricePerMillion: Double

    /// Predefined pricing for Claude Opus 4/4.5
    public static let opus4 = ModelPricing(
        model: "claude-opus-4-5-20251101",
        inputPricePerMillion: 5.0,
        outputPricePerMillion: 25.0,
        cacheWritePricePerMillion: 6.25,
        cacheReadPricePerMillion: 0.50
    )

    /// Predefined pricing for Claude Sonnet 4/4.5
    public static let sonnet4 = ModelPricing(
        model: "claude-sonnet-4-5-20250929",
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheWritePricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30
    )

    /// Predefined pricing for Claude Haiku 4.5
    public static let haiku4 = ModelPricing(
        model: "claude-haiku-4-5-20251001",
        inputPricePerMillion: 0.80,
        outputPricePerMillion: 4.0,
        cacheWritePricePerMillion: 1.0,
        cacheReadPricePerMillion: 0.08
    )

    /// All available model pricing
    public static let all = [opus4, sonnet4, haiku4]

    /// Find pricing for a model name
    public static func pricing(for model: String) -> ModelPricing? {
        let modelLower = model.lowercased()

        if modelLower.contains("opus") {
            return opus4
        }

        if modelLower.contains("sonnet") {
            return sonnet4
        }

        if modelLower.contains("haiku") {
            return haiku4
        }

        return sonnet4
    }

    /// Calculate cost for given token counts
    /// Note: Cache read tokens are included to match Claude's Rust backend calculation
    public func calculateCost(inputTokens: Int, outputTokens: Int, cacheWriteTokens: Int = 0, cacheReadTokens: Int = 0) -> Double {
        let inputCost = (Double(inputTokens) / 1_000_000) * inputPricePerMillion
        let outputCost = (Double(outputTokens) / 1_000_000) * outputPricePerMillion
        let cacheWriteCost = (Double(cacheWriteTokens) / 1_000_000) * cacheWritePricePerMillion
        let cacheReadCost = (Double(cacheReadTokens) / 1_000_000) * cacheReadPricePerMillion

        return inputCost + outputCost + cacheWriteCost + cacheReadCost // Including all costs like Rust backend
    }
}
