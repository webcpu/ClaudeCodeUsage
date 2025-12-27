//
//  PredictionsCard.swift
//  Cost predictions based on usage data
//

import SwiftUI
import ClaudeCodeUsageKit

struct PredictionsCard: View {
    let stats: UsageStats

    private var metrics: PredictionMetrics { PredictionMetrics.from(stats: stats) }

    var body: some View {
        AnalyticsCard(title: "Predictions", icon: "calendar", color: .green) {
            VStack(alignment: .leading, spacing: 12) {
                monthlyCostRow
                dailyCostRow
            }
        }
    }

    private var monthlyCostRow: some View {
        PredictionRow(
            label: "Predicted Monthly Cost",
            value: metrics.monthlyCost.asCurrency,
            icon: "calendar",
            detail: "Based on \(metrics.daysElapsed) days of data"
        )
    }

    @ViewBuilder
    private var dailyCostRow: some View {
        if let daily = metrics.averageDailyCost {
            PredictionRow(
                label: "Average Daily Cost",
                value: daily.asCurrency,
                icon: "chart.line.uptrend.xyaxis",
                detail: nil
            )
        }
    }
}

// MARK: - Pure Transformation

private struct PredictionMetrics {
    let daysElapsed: Int
    let monthlyCost: Double
    let averageDailyCost: Double?

    static func from(stats: UsageStats) -> PredictionMetrics {
        let days = max(1, stats.byDate.count)
        let monthly = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: days)
        let daily = stats.byDate.isEmpty ? nil : stats.totalCost / Double(stats.byDate.count)
        return PredictionMetrics(daysElapsed: days, monthlyCost: monthly, averageDailyCost: daily)
    }
}
