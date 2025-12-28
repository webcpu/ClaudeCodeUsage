//
//  Models+Pricing.swift
//
//  Model pricing configurations and cost calculations.
//

import Foundation

// MARK: - ModelPricing

public struct ModelPricing: Sendable {
    public let inputCostPerToken: Double
    public let outputCostPerToken: Double
    public let cacheCreationCostPerToken: Double
    public let cacheReadCostPerToken: Double

    public init(
        inputCostPerToken: Double,
        outputCostPerToken: Double,
        cacheCreationCostPerToken: Double,
        cacheReadCostPerToken: Double
    ) {
        self.inputCostPerToken = inputCostPerToken
        self.outputCostPerToken = outputCostPerToken
        self.cacheCreationCostPerToken = cacheCreationCostPerToken
        self.cacheReadCostPerToken = cacheReadCostPerToken
    }

    public func calculateCost(tokens: TokenCounts) -> Double {
        inputCost(for: tokens) + outputCost(for: tokens) + cacheCost(for: tokens)
    }
}

// MARK: - ModelPricing Pricing Configurations

public extension ModelPricing {
    /// Claude Opus 4.5 pricing (November 2025)
    static let claudeOpus45 = ModelPricing(
        inputCostPerToken: 0.000005,      // $5/MTok
        outputCostPerToken: 0.000025,     // $25/MTok
        cacheCreationCostPerToken: 0.00000625,  // $6.25/MTok
        cacheReadCostPerToken: 0.0000005  // $0.50/MTok
    )

    /// Claude Sonnet 4/4.5 pricing
    static let claudeSonnet4 = ModelPricing(
        inputCostPerToken: 0.000003,      // $3/MTok
        outputCostPerToken: 0.000015,     // $15/MTok
        cacheCreationCostPerToken: 0.00000375,  // $3.75/MTok
        cacheReadCostPerToken: 0.0000003  // $0.30/MTok
    )

    /// Claude Haiku 4.5 pricing
    static let claudeHaiku45 = ModelPricing(
        inputCostPerToken: 0.000001,      // $1/MTok
        outputCostPerToken: 0.000005,     // $5/MTok
        cacheCreationCostPerToken: 0.00000125,  // $1.25/MTok
        cacheReadCostPerToken: 0.0000001  // $0.10/MTok
    )

    static let `default` = claudeSonnet4
}

// MARK: - ModelPricing Lookup

public extension ModelPricing {
    static func getPricing(for model: String) -> ModelPricing {
        ModelFamily(from: model).pricing
    }
}

// MARK: - ModelPricing Cost Calculation

private extension ModelPricing {
    func inputCost(for tokens: TokenCounts) -> Double {
        Double(tokens.inputTokens) * inputCostPerToken
    }

    func outputCost(for tokens: TokenCounts) -> Double {
        Double(tokens.outputTokens) * outputCostPerToken
    }

    func cacheCost(for tokens: TokenCounts) -> Double {
        cacheCreationCost(for: tokens) + cacheReadCost(for: tokens)
    }

    func cacheCreationCost(for tokens: TokenCounts) -> Double {
        Double(tokens.cacheCreationInputTokens) * cacheCreationCostPerToken
    }

    func cacheReadCost(for tokens: TokenCounts) -> Double {
        Double(tokens.cacheReadInputTokens) * cacheReadCostPerToken
    }
}

// MARK: - ModelFamily

private enum ModelFamily {
    case opus
    case sonnet
    case haiku
    case unknown

    init(from modelName: String) {
        self = Self.allKnownFamilies.first { $0.matches(modelName) } ?? .unknown
    }

    var pricing: ModelPricing {
        switch self {
        case .opus: .claudeOpus45
        case .sonnet: .claudeSonnet4
        case .haiku: .claudeHaiku45
        case .unknown: .default
        }
    }
}

// MARK: - ModelFamily Matching

private extension ModelFamily {
    static let allKnownFamilies: [ModelFamily] = [.opus, .sonnet, .haiku]

    var identifier: String {
        switch self {
        case .opus: "opus"
        case .sonnet: "sonnet"
        case .haiku: "haiku"
        case .unknown: ""
        }
    }

    func matches(_ modelName: String) -> Bool {
        modelName.lowercased().contains(identifier)
    }
}
