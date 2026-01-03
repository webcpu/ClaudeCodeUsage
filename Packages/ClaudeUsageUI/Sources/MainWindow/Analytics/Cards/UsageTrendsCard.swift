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
        if let trend = calculateTrend(stats, windowSize: 7) {
            TrendRow(trend: trend)
        }
    }

    @ViewBuilder
    private var peakDaySection: some View {
        if let peak = findPeakDay(stats.byDate) {
            InfoRow(
                label: "Peak Usage Day",
                value: DateFormatting.formatMedium(peak.date),
                detail: peak.totalCost.asCurrency
            )
        }
    }
}

// MARK: - Trend Calculation Pipeline

/// Configuration for trend window comparison
private struct TrendWindow: Sendable {
    let recentDays: ArraySlice<DailyUsage>
    let previousDays: ArraySlice<DailyUsage>
}

/// Result of comparing two windows
private struct WindowComparison: Sendable {
    let recentAverage: Double
    let previousAverage: Double
    let percentageChange: Double
}

// MARK: - Pure Pipeline Steps

/// Extract windows from daily usage data
private func extractWindows(_ windowSize: Int) -> @Sendable ([DailyUsage]) -> TrendWindow? {
    { days in
        guard days.count >= 2 else { return nil }

        let recent = days.suffix(windowSize)
        let previous = days.dropLast(windowSize).suffix(windowSize)

        guard !recent.isEmpty, !previous.isEmpty else { return nil }

        return TrendWindow(recentDays: recent, previousDays: previous)
    }
}

/// Calculate averages for both windows
private let calculateAverages: @Sendable (TrendWindow) -> WindowComparison = { window in
    let recentAvg = window.recentDays.map(\.totalCost).reduce(0, +) / Double(window.recentDays.count)
    let previousAvg = window.previousDays.map(\.totalCost).reduce(0, +) / Double(window.previousDays.count)
    let change = previousAvg > 0 ? ((recentAvg - previousAvg) / previousAvg) * 100 : 0

    return WindowComparison(
        recentAverage: recentAvg,
        previousAverage: previousAvg,
        percentageChange: change
    )
}

/// Map comparison to trend direction
private let mapToTrend: @Sendable (WindowComparison) -> UsageTrend = { comparison in
    UsageTrend(
        direction: comparison.percentageChange > 0 ? .up : .down,
        percentage: abs(comparison.percentageChange)
    )
}

// MARK: - Composed Pipeline

/// Calculate trend by composing: extractWindows >>> calculateAverages >>> mapToTrend
private func calculateTrend(_ stats: UsageStats, windowSize: Int) -> UsageTrend? {
    let transform: (TrendWindow) -> UsageTrend = calculateAverages >>> mapToTrend
    return extractWindows(windowSize)(stats.byDate).map(transform)
}

/// Find peak day by maximum cost
private let findPeakDay: @Sendable ([DailyUsage]) -> DailyUsage? = { days in
    days.max { $0.totalCost < $1.totalCost }
}

// MARK: - Date Formatting

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

struct UsageTrend: Sendable {
    enum Direction: Sendable { case up, down }

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
