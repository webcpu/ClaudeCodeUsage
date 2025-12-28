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
    static let claudeOpus4 = ModelPricing(
        inputCostPerToken: 0.000015,
        outputCostPerToken: 0.000075,
        cacheCreationCostPerToken: 0.00001875,
        cacheReadCostPerToken: 0.0000015
    )

    static let claudeSonnet4 = ModelPricing(
        inputCostPerToken: 0.000003,
        outputCostPerToken: 0.000015,
        cacheCreationCostPerToken: 0.00000375,
        cacheReadCostPerToken: 0.0000003
    )

    static let `default` = claudeOpus4
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
    case unknown

    init(from modelName: String) {
        self = Self.allKnownFamilies.first { $0.matches(modelName) } ?? .unknown
    }

    var pricing: ModelPricing {
        switch self {
        case .opus: .claudeOpus4
        case .sonnet: .claudeSonnet4
        case .unknown: .default
        }
    }
}

// MARK: - ModelFamily Matching

private extension ModelFamily {
    static let allKnownFamilies: [ModelFamily] = [.opus, .sonnet]

    var identifier: String {
        switch self {
        case .opus: "opus"
        case .sonnet: "sonnet"
        case .unknown: ""
        }
    }

    func matches(_ modelName: String) -> Bool {
        modelName.lowercased().contains(identifier)
    }
}
