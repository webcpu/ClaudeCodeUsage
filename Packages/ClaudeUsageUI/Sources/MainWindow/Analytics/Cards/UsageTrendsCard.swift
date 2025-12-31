//
//  UsageTrendsCard.swift
//  Usage trends analytics
//

import SwiftUI
import ClaudeUsageCore

// MARK: - Trends Card

struct TrendsCard: View {
    let stats: UsageStats

    var body: some View {
        AnalyticsCard(title: "Usage Trends", icon: "chart.line.uptrend.xyaxis", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                weeklyTrendSection
                peakDaySection
            }
        }
    }

    @ViewBuilder
    private var weeklyTrendSection: some View {
        if let trend = TrendCalculator.weeklyTrend(from: stats) {
            TrendRow(trend: trend)
        }
    }

    @ViewBuilder
    private var peakDaySection: some View {
        if let peak = TrendCalculator.peakDay(from: stats) {
            InfoRow(
                label: "Peak Usage Day",
                value: DateFormatting.formatMedium(peak.date),
                detail: peak.totalCost.asCurrency
            )
        }
    }
}

// MARK: - Pure Transformations

private enum TrendCalculator {
    static func weeklyTrend(from stats: UsageStats) -> UsageTrend? {
        guard stats.byDate.count >= 2 else { return nil }

        let recent = stats.byDate.suffix(7)
        let previous = stats.byDate.dropLast(7).suffix(7)

        guard !recent.isEmpty, !previous.isEmpty else { return nil }

        let recentAvg = recent.map(\.totalCost).reduce(0, +) / Double(recent.count)
        let previousAvg = previous.map(\.totalCost).reduce(0, +) / Double(previous.count)

        let change = ((recentAvg - previousAvg) / previousAvg) * 100
        return UsageTrend(direction: change > 0 ? .up : .down, percentage: abs(change))
    }

    static func peakDay(from stats: UsageStats) -> DailyUsage? {
        stats.byDate.max { $0.totalCost < $1.totalCost }
    }
}

private enum DateFormatting {
    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func formatMedium(_ dateString: String) -> String {
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        let output = DateFormatter()
        output.dateStyle = .medium
        return output.string(from: date)
    }
}

// MARK: - Supporting Types

struct UsageTrend {
    enum Direction { case up, down }

    let direction: Direction
    let percentage: Double

    var icon: String {
        direction == .up ? "arrow.up.right" : "arrow.down.right"
    }

    var color: Color {
        direction == .up ? .red : .green
    }

    var formattedPercentage: String {
        "\(direction == .up ? "+" : "-")\(percentage.asPercentage)"
    }
}
