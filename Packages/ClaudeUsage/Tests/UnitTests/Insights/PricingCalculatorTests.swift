//
//  PricingCalculatorTests.swift
//
//  Specification for PricingCalculator - pure functions for cost calculation.
//
//  This test suite specifies:
//  - Model family detection from model strings (case insensitive, first match wins)
//  - Cost calculation formula: sum of (tokens × rate) for each token type
//  - Pricing values for each model family
//

import Testing
@testable import ClaudeUsage

/// PricingCalculator is an enum with static methods for cost calculation.
/// It detects model families from strings and calculates costs based on token usage.
@Suite("PricingCalculator")
struct PricingCalculatorTests {

    // MARK: - Model Detection

    @Test("detects opus model from various formats")
    func detectsOpusModel() {
        assertAllDetectModel(
            ["claude-opus-4-5-20251101", "claude-4-opus", "opus", "CLAUDE-OPUS", "claude-opus"],
            expected: .opus
        )
    }

    @Test("detects sonnet model from various formats")
    func detectsSonnetModel() {
        assertAllDetectModel(
            ["claude-sonnet-4-20250514", "claude-3-5-sonnet", "sonnet", "CLAUDE-SONNET"],
            expected: .sonnet
        )
    }

    @Test("detects haiku model from various formats")
    func detectsHaikuModel() {
        assertAllDetectModel(
            ["claude-haiku-3-5-20241022", "claude-3-haiku", "haiku", "HAIKU"],
            expected: .haiku
        )
    }

    @Test("defaults to sonnet for unknown models")
    func defaultsToSonnet() {
        assertAllDetectModel(
            ["gpt-4", "unknown-model", "claude-new", ""],
            expected: .sonnet
        )
    }

    // MARK: - Cost Calculation

    @Test("calculates zero cost for zero tokens")
    func calculatesZeroCost() {
        let cost = PricingCalculator.calculateCost(tokens: .zero, model: "sonnet")
        #expect(cost == 0.0)
    }

    @Test("calculates input token cost correctly")
    func calculatesInputCost() {
        let tokens = inputOnlyTokens(1_000_000)

        assertCost(tokens, model: "opus", expectedCost: 5.0)
        assertCost(tokens, model: "sonnet", expectedCost: 3.0)
        assertCost(tokens, model: "haiku", expectedCost: 1.0)
    }

    @Test("calculates output token cost correctly")
    func calculatesOutputCost() {
        let tokens = outputOnlyTokens(1_000_000)

        assertCost(tokens, model: "opus", expectedCost: 25.0)
        assertCost(tokens, model: "sonnet", expectedCost: 15.0)
        assertCost(tokens, model: "haiku", expectedCost: 5.0)
    }

    @Test("calculates cache write cost correctly")
    func calculatesCacheWriteCost() {
        let tokens = cacheWriteOnlyTokens(1_000_000)
        assertCost(tokens, model: "sonnet", expectedCost: 3.75)
    }

    @Test("calculates cache read cost correctly")
    func calculatesCacheReadCost() {
        let tokens = cacheReadOnlyTokens(1_000_000)
        assertCost(tokens, model: "sonnet", expectedCost: 0.30)
    }

    @Test("calculates combined token costs")
    func calculatesCombinedCosts() {
        let tokens = TokenCounts(
            input: 500_000,
            output: 100_000,
            cacheCreation: 200_000,
            cacheRead: 1_000_000
        )

        let cost = PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
        let expectedCost = 1.50 + 1.50 + 0.75 + 0.30
        #expect(abs(cost - expectedCost) < 0.001)
    }

    // MARK: - ModelPricing Values

    @Test("opus pricing values are correct")
    func opusPricingValues() {
        assertPricingValues(
            .opus,
            input: 5.0 / 1_000_000,
            output: 25.0 / 1_000_000,
            cacheWrite: 6.25 / 1_000_000,
            cacheRead: 0.50 / 1_000_000
        )
    }

    @Test("sonnet pricing values are correct")
    func sonnetPricingValues() {
        assertPricingValues(
            .sonnet,
            input: 3.0 / 1_000_000,
            output: 15.0 / 1_000_000,
            cacheWrite: 3.75 / 1_000_000,
            cacheRead: 0.30 / 1_000_000
        )
    }

    @Test("haiku pricing values are correct")
    func haikuPricingValues() {
        assertPricingValues(
            .haiku,
            input: 1.0 / 1_000_000,
            output: 5.0 / 1_000_000,
            cacheWrite: 1.25 / 1_000_000,
            cacheRead: 0.10 / 1_000_000
        )
    }

    // MARK: - Edge Cases

    @Test("handles very large token counts")
    func handlesLargeTokenCounts() {
        let tokens = TokenCounts(input: 100_000_000, output: 50_000_000)
        assertCost(tokens, model: "sonnet", expectedCost: 1050.0)
    }

    @Test("cost is additive across token types")
    func costIsAdditive() {
        let inputCost = calculateSonnetCost(inputOnlyTokens(1000))
        let outputCost = calculateSonnetCost(outputOnlyTokens(1000))
        let combinedCost = calculateSonnetCost(TokenCounts(input: 1000, output: 1000))

        #expect(abs(combinedCost - (inputCost + outputCost)) < 0.0001)
    }

    // MARK: - Test Helpers

    private func assertAllDetectModel(_ modelNames: [String], expected: ModelPricing) {
        modelNames.forEach { model in
            let pricing = PricingCalculator.modelPricing(for: model)
            #expect(pricing == expected, "Should detect \(expected) for: \(model)")
        }
    }

    private func assertCost(_ tokens: TokenCounts, model: String, expectedCost: Double) {
        let cost = PricingCalculator.calculateCost(tokens: tokens, model: model)
        #expect(cost == expectedCost)
    }

    private func assertPricingValues(
        _ pricing: ModelPricing,
        input: Double,
        output: Double,
        cacheWrite: Double,
        cacheRead: Double
    ) {
        #expect(pricing.inputPerToken == input)
        #expect(pricing.outputPerToken == output)
        #expect(pricing.cacheWritePerToken == cacheWrite)
        #expect(pricing.cacheReadPerToken == cacheRead)
    }

    private func calculateSonnetCost(_ tokens: TokenCounts) -> Double {
        PricingCalculator.calculateCost(tokens: tokens, model: "sonnet")
    }

    private func inputOnlyTokens(_ count: Int) -> TokenCounts {
        TokenCounts(input: count, output: 0)
    }

    private func outputOnlyTokens(_ count: Int) -> TokenCounts {
        TokenCounts(input: 0, output: count)
    }

    private func cacheWriteOnlyTokens(_ count: Int) -> TokenCounts {
        TokenCounts(input: 0, output: 0, cacheCreation: count, cacheRead: 0)
    }

    private func cacheReadOnlyTokens(_ count: Int) -> TokenCounts {
        TokenCounts(input: 0, output: 0, cacheCreation: 0, cacheRead: count)
    }
}
