//
//  TokenDistributionCard.swift
//  Token distribution visualization
//

import SwiftUI

struct TokenDistributionCard: View {
    let stats: UsageStats

    var body: some View {
        AnalyticsCard(title: "Token Distribution", icon: "chart.pie", color: .blue) {
            TokenDistributionRows(breakdown: UsageAnalytics.tokenBreakdown(from: stats))
        }
    }
}

private struct TokenDistributionRows: View {
    let breakdown: (inputPercentage: Double, outputPercentage: Double, cacheWritePercentage: Double, cacheReadPercentage: Double)

    var body: some View {
        VStack(spacing: 12) {
            inputRow
            outputRow
            cacheWriteRow
            cacheReadRow
        }
    }

    private var inputRow: some View {
        TokenRow(label: "Input", percentage: breakdown.inputPercentage, icon: "arrow.right.circle", color: .blue)
    }

    private var outputRow: some View {
        TokenRow(label: "Output", percentage: breakdown.outputPercentage, icon: "arrow.left.circle", color: .green)
    }

    private var cacheWriteRow: some View {
        TokenRow(label: "Cache Write", percentage: breakdown.cacheWritePercentage, icon: "square.and.pencil", color: .orange)
    }

    private var cacheReadRow: some View {
        TokenRow(label: "Cache Read", percentage: breakdown.cacheReadPercentage, icon: "doc.text.magnifyingglass", color: .purple)
    }
}
