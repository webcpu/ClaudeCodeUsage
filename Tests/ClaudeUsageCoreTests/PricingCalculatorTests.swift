//
//  PricingCalculatorTests.swift
//  ClaudeUsageCoreTests
//

import Testing
@testable import ClaudeUsageCore

@Suite("PricingCalculator")
struct PricingCalculatorTests {

    // MARK: - Model Detection

    @Test("detects opus model from various formats")
    func detectsOpusModel() {
        let opusVariants = [
            "claude-opus-4-5-20251101",
            "claude-4-opus",
            "opus",
            "CLAUDE-OPUS",
            "claude-opus"
        ]

        for model in opusVariants {
            let pricing = PricingCalculator.modelPricing(for: model)
            #expect(pricing == .opus, "Should detect opus for: \(model)")
        }
    }

    @Test("detects sonnet model from various formats")
    func detectsSonnetModel() {
        let sonnetVariants = [
            "claude-sonnet-4-20250514",
            "claude-3-5-sonnet",
            "sonnet",
            "CLAUDE-SONNET"
        ]

        for model in sonnetVariants {
            let pricing = PricingCalculator.modelPricing(for: model)
            #expect(pricing == .sonnet, "Should detect sonnet for: \(model)")
        }
    }

    @Test("detects haiku model from various formats")
    func detectsHaikuModel() {
        let haikuVariants = [
            "claude-haiku-3-5-20241022",
            "claude-3-haiku",
            "haiku",
            "HAIKU"
        ]

        for model in haikuVariants {
            let pricing = PricingCalculator.modelPricing(for: model)
            #expect(pricing == .haiku, "Should detect haiku for: \(model)")
        }
    }

    @Test("defaults to sonnet for unknown models")
    func defaultsToSonnet() {
        let unknownModels = [
            "gpt-4",
            "unknown-model",
            "claude-new",
            ""
        ]

        for model in unknownModels {
            let pricing = PricingCalculator.modelPricing(for: model)
            #expect(pricing == .sonnet, "Should default to sonnet for: \(model)")
        }
    }

    // MARK: - Cost Calculation

    @Test("calculates zero cost for zero tokens")
    func calculatesZeroCost() {
        let cost = PricingCalculator.calculateCost(tokens: .zero, model: "sonnet")
        #expect(cost == 0.0)
    }

    @Test("calculates input token cost correctly")
    func calculatesInputCost() {
        let tokens = TokenCounts(input: 1_000_000, output: 0)

        let opusCost = PricingCalculator.calculateCost(tokens: tokens, model: "opus")
        #expect(opusCost == 5.0) // $5 per million input

        let sonnetCost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
        #expect(sonnetCost == 3.0) // $3 per million input

        let haikuCost = PricingCalculator.calculateCost(tokens: tokens, model: "haiku")
        #expect(haikuCost == 1.0) // $1 per million input
    }

    @Test("calculates output token cost correctly")
    func calculatesOutputCost() {
        let tokens = TokenCounts(input: 0, output: 1_000_000)

        let opusCost = PricingCalculator.calculateCost(tokens: tokens, model: "opus")
        #expect(opusCost == 25.0) // $25 per million output

        let sonnetCost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
        #expect(sonnetCost == 15.0) // $15 per million output

        let haikuCost = PricingCalculator.calculateCost(tokens: tokens, model: "haiku")
        #expect(haikuCost == 5.0) // $5 per million output
    }

    @Test("calculates cache write cost correctly")
    func calculatesCacheWriteCost() {
        let tokens = TokenCounts(input: 0, output: 0, cacheCreation: 1_000_000, cacheRead: 0)

        let sonnetCost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
        #expect(sonnetCost == 3.75) // $3.75 per million (1.25x input)
    }

    @Test("calculates cache read cost correctly")
    func calculatesCacheReadCost() {
        let tokens = TokenCounts(input: 0, output: 0, cacheCreation: 0, cacheRead: 1_000_000)

        let sonnetCost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
        #expect(sonnetCost == 0.30) // $0.30 per million (0.1x input)
    }

    @Test("calculates combined token costs")
    func calculatesCombinedCosts() {
        let tokens = TokenCounts(
            input: 500_000,
            output: 100_000,
            cacheCreation: 200_000,
            cacheRead: 1_000_000
        )

        let sonnetCost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")

        // Expected: (0.5M * $3) + (0.1M * $15) + (0.2M * $3.75) + (1M * $0.30)
        // = $1.50 + $1.50 + $0.75 + $0.30 = $4.05
        #expect(abs(sonnetCost - 4.05) < 0.001)
    }

    // MARK: - ModelPricing Values

    @Test("opus pricing values are correct")
    func opusPricingValues() {
        let pricing = ModelPricing.opus

        #expect(pricing.inputPerToken == 5.0 / 1_000_000)
        #expect(pricing.outputPerToken == 25.0 / 1_000_000)
        #expect(pricing.cacheWritePerToken == 6.25 / 1_000_000)
        #expect(pricing.cacheReadPerToken == 0.50 / 1_000_000)
    }

    @Test("sonnet pricing values are correct")
    func sonnetPricingValues() {
        let pricing = ModelPricing.sonnet

        #expect(pricing.inputPerToken == 3.0 / 1_000_000)
        #expect(pricing.outputPerToken == 15.0 / 1_000_000)
        #expect(pricing.cacheWritePerToken == 3.75 / 1_000_000)
        #expect(pricing.cacheReadPerToken == 0.30 / 1_000_000)
    }

    @Test("haiku pricing values are correct")
    func haikuPricingValues() {
        let pricing = ModelPricing.haiku

        #expect(pricing.inputPerToken == 1.0 / 1_000_000)
        #expect(pricing.outputPerToken == 5.0 / 1_000_000)
        #expect(pricing.cacheWritePerToken == 1.25 / 1_000_000)
        #expect(pricing.cacheReadPerToken == 0.10 / 1_000_000)
    }

    // MARK: - Edge Cases

    @Test("handles very large token counts")
    func handlesLargeTokenCounts() {
        let tokens = TokenCounts(input: 100_000_000, output: 50_000_000) // 150M tokens

        let cost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")

        // (100M * $3) + (50M * $15) = $300 + $750 = $1050
        #expect(cost == 1050.0)
    }

    @Test("cost is additive across token types")
    func costIsAdditive() {
        let inputOnly = TokenCounts(input: 1000, output: 0)
        let outputOnly = TokenCounts(input: 0, output: 1000)
        let combined = TokenCounts(input: 1000, output: 1000)

        let inputCost = PricingCalculator.calculateCost(tokens: inputOnly, model: "sonnet")
        let outputCost = PricingCalculator.calculateCost(tokens: outputOnly, model: "sonnet")
        let combinedCost = PricingCalculator.calculateCost(tokens: combined, model: "sonnet")

        #expect(abs(combinedCost - (inputCost + outputCost)) < 0.0001)
    }
}
