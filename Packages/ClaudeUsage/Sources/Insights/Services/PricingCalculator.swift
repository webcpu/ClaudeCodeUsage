//
//  PricingCalculator.swift
//  ClaudeUsageCore
//
//  Pure functions for cost calculations
//

import Foundation

// MARK: - Model Family Registry (OCP: Open for Extension)

/// Registry of known model families and their pricing.
/// Add new models by extending this array, not by modifying pricing logic.
public enum ModelFamilyRegistry {
    /// Each entry: (family name substring, pricing)
    /// Order matters: first match wins
    public static let families: [(family: String, pricing: ModelPricing)] = [
        ("opus", .opus),
        ("sonnet", .sonnet),
        ("haiku", .haiku)
    ]

    /// Known family names for display formatting
    public static let knownFamilyNames: [String] = families.map(\.family)

    /// Default pricing when model family is unknown
    public static let defaultPricing: ModelPricing = .sonnet
}

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

    /// Get pricing for a model using registry lookup
    public static func modelPricing(for model: String) -> ModelPricing {
        let normalizedModel = model.lowercased()
        return ModelFamilyRegistry.families
            .first { normalizedModel.contains($0.family) }?
            .pricing ?? ModelFamilyRegistry.defaultPricing
    }
}

// MARK: - Model Name Formatter

/// Formats model IDs to display names using the model family registry.
/// Example: "claude-opus-4-5-20251101" → "Claude Opus 4.5"
public enum ModelNameFormatter {

    public static func format(_ model: String) -> String {
        let parts = model.lowercased().components(separatedBy: "-")
        let family = extractFamily(from: parts)
        let version = extractVersion(from: parts)
        return buildDisplayName(family: family, version: version, fallback: model)
    }

    private static func extractFamily(from parts: [String]) -> String? {
        parts.first { ModelFamilyRegistry.knownFamilyNames.contains($0) }
    }

    private static func extractVersion(from parts: [String]) -> String {
        let numbers = parts.compactMap { Int($0) }
        return numbers.count >= 2
            ? "\(numbers[0]).\(numbers[1])"
            : numbers.first.map { "\($0)" } ?? ""
    }

    private static func buildDisplayName(family: String?, version: String, fallback: String) -> String {
        guard let family else { return fallback }
        let name = "Claude \(family.capitalized)"
        return version.isEmpty ? name : "\(name) \(version)"
    }
}
