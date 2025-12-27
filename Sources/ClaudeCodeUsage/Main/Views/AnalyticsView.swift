//
//  AnalyticsView.swift
//  Analytics and insights view
//

import SwiftUI
import ClaudeCodeUsageKit

struct AnalyticsView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AnalyticsHeader()
                AnalyticsContent(state: ContentState.from(store: store))
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content State

@MainActor
private enum ContentState {
    case loading
    case loaded(UsageStats)
    case error

    static func from(store: UsageStore) -> ContentState {
        if store.isLoading { return .loading }
        guard let stats = store.stats else { return .error }
        return .loaded(stats)
    }
}

// MARK: - Content Router

private struct AnalyticsContent: View {
    let state: ContentState

    var body: some View {
        switch state {
        case .loading:
            LoadingView(message: "Analyzing data...")
        case .loaded(let stats):
            AnalyticsCards(stats: stats)
        case .error:
            EmptyStateView(
                icon: "chart.bar.xaxis",
                title: "No Analytics Available",
                message: "Analytics will appear once you have usage data."
            )
        }
    }
}

private struct AnalyticsCards: View {
    let stats: UsageStats

    var body: some View {
        VStack(spacing: 16) {
            YearlyCostHeatmapCard(stats: stats)
            TokenDistributionCard(stats: stats)
            PredictionsCard(stats: stats)
            EfficiencyCard(stats: stats)
            TrendsCard(stats: stats)
        }
    }
}

// MARK: - Header

private struct AnalyticsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Insights and predictions based on your usage")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
    }
}

// MARK: - Token Distribution Card

private struct TokenDistributionCard: View {
    let stats: UsageStats

    var body: some View {
        AnalyticsCard(title: "Token Distribution", icon: "chart.pie", color: .blue) {
            let breakdown = UsageAnalytics.tokenBreakdown(from: stats)
            VStack(spacing: 12) {
                TokenRow(label: "Input", percentage: breakdown.inputPercentage, icon: "arrow.right.circle", color: .blue)
                TokenRow(label: "Output", percentage: breakdown.outputPercentage, icon: "arrow.left.circle", color: .green)
                TokenRow(label: "Cache Write", percentage: breakdown.cacheWritePercentage, icon: "square.and.pencil", color: .orange)
                TokenRow(label: "Cache Read", percentage: breakdown.cacheReadPercentage, icon: "doc.text.magnifyingglass", color: .purple)
            }
        }
    }
}

// MARK: - Predictions Card

private struct PredictionsCard: View {
    let stats: UsageStats

    private var metrics: PredictionMetrics { PredictionMetrics.from(stats: stats) }

    var body: some View {
        AnalyticsCard(title: "Predictions", icon: "calendar", color: .green) {
            VStack(alignment: .leading, spacing: 12) {
                PredictionRow(
                    label: "Predicted Monthly Cost",
                    value: metrics.monthlyCost.asCurrency,
                    icon: "calendar",
                    detail: "Based on \(metrics.daysElapsed) days of data"
                )

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
    }
}

// MARK: - Efficiency Card

private struct EfficiencyCard: View {
    let stats: UsageStats

    var body: some View {
        AnalyticsCard(title: "Efficiency", icon: "memorychip", color: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text(UsageAnalytics.cacheSavings(from: stats).description)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Trends Card

private struct TrendsCard: View {
    let stats: UsageStats

    var body: some View {
        AnalyticsCard(title: "Usage Trends", icon: "chart.line.uptrend.xyaxis", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                if let trend = TrendCalculator.weeklyTrend(from: stats) {
                    TrendRow(trend: trend)
                }

                if let peak = TrendCalculator.peakDay(from: stats) {
                    InfoRow(
                        label: "Peak Usage Day",
                        value: DateFormatting.formatMedium(peak.date),
                        detail: peak.totalCost.asCurrency
                    )
                }
            }
        }
    }
}

// MARK: - Yearly Cost Heatmap Card

private struct YearlyCostHeatmapCard: View {
    let stats: UsageStats
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var availableYears: [Int] { YearExtractor.years(from: stats.byDate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeatmapHeader(years: availableYears, selectedYear: $selectedYear)
            YearlyCostHeatmap(stats: stats, year: selectedYear)
        }
        .onAppear {
            if let mostRecent = availableYears.first {
                selectedYear = mostRecent
            }
        }
    }
}

private struct HeatmapHeader: View {
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        HStack {
            Spacer()
            if years.count > 1 {
                YearSelector(years: years, selectedYear: $selectedYear)
            }
        }
    }
}

private struct YearSelector: View {
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        Menu {
            ForEach(years, id: \.self) { year in
                Button(String(year)) { selectedYear = year }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(selectedYear))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analytics Card Container

private struct AnalyticsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Row Views

private struct TokenRow: View {
    let label: String
    let percentage: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text(percentage.asPercentage)
                .font(.system(.body, design: .monospaced))
        }
    }
}

private struct PredictionRow: View {
    let label: String
    let value: String
    let icon: String
    let detail: String?

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            VStack(alignment: .trailing) {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct TrendRow: View {
    let trend: UsageTrend

    var body: some View {
        HStack {
            Label("7-Day Trend", systemImage: trend.icon)
                .foregroundColor(trend.color)
            Spacer()
            Text(trend.formattedPercentage)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(trend.color)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing) {
                Text(value)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Pure Transformations

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

private enum YearExtractor {
    static func years(from dates: [DailyUsage]) -> [Int] {
        Array(Set(dates.compactMap { Int($0.date.prefix(4)) })).sorted(by: >)
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

private struct UsageTrend {
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
