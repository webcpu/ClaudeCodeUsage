//
//  AnalyticsScreen.swift
//  Analytics and insights screen
//

import SwiftUI
import ClaudeCodeUsage

struct AnalyticsScreen: View {
    @Environment(UsageDataModel.self) private var dataModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AnalyticsHeader()
                
                if let stats = dataModel.stats {
                    VStack(spacing: 16) {
                        YearlyCostHeatmapCard(stats: stats)
                        TokenDistributionCard(stats: stats)
                        PredictionsCard(stats: stats)
                        EfficiencyCard(stats: stats)
                        TrendsCard(stats: stats)
                    }
                } else if dataModel.isLoading {
                    ProgressView("Analyzing data...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    EmptyStateView(
                        icon: "chart.bar.xaxis",
                        title: "No Analytics Available",
                        message: "Analytics will appear once you have usage data."
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analytics Header
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

// MARK: - Token Distribution Card
private struct TokenDistributionCard: View {
    let stats: UsageStats
    
    var body: some View {
        AnalyticsCard(
            title: "Token Distribution",
            icon: "chart.pie",
            color: .blue
        ) {
            let breakdown = UsageAnalytics.tokenBreakdown(from: stats)
            
            VStack(spacing: 12) {
                TokenRow(
                    label: "Input",
                    percentage: breakdown.inputPercentage,
                    icon: "arrow.right.circle",
                    color: .blue
                )
                
                TokenRow(
                    label: "Output",
                    percentage: breakdown.outputPercentage,
                    icon: "arrow.left.circle",
                    color: .green
                )
                
                TokenRow(
                    label: "Cache Write",
                    percentage: breakdown.cacheWritePercentage,
                    icon: "square.and.pencil",
                    color: .orange
                )
                
                TokenRow(
                    label: "Cache Read",
                    percentage: breakdown.cacheReadPercentage,
                    icon: "doc.text.magnifyingglass",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Predictions Card
private struct PredictionsCard: View {
    let stats: UsageStats
    
    var body: some View {
        AnalyticsCard(
            title: "Predictions",
            icon: "calendar",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                let daysElapsed = calculateDaysElapsed(stats: stats)
                let prediction = UsageAnalytics.predictMonthlyCost(from: stats, daysElapsed: daysElapsed)
                
                PredictionRow(
                    label: "Predicted Monthly Cost",
                    value: prediction.asCurrency,
                    icon: "calendar",
                    detail: "Based on \(daysElapsed) days of data"
                )
                
                if let averageDaily = calculateAverageDailyCost(stats: stats) {
                    PredictionRow(
                        label: "Average Daily Cost",
                        value: averageDaily.asCurrency,
                        icon: "chart.line.uptrend.xyaxis",
                        detail: nil
                    )
                }
            }
        }
    }
    
    private func calculateDaysElapsed(stats: UsageStats) -> Int {
        max(1, stats.byDate.count)
    }
    
    private func calculateAverageDailyCost(stats: UsageStats) -> Double? {
        guard !stats.byDate.isEmpty else { return nil }
        return stats.totalCost / Double(stats.byDate.count)
    }
}

// MARK: - Efficiency Card
private struct EfficiencyCard: View {
    let stats: UsageStats
    
    var body: some View {
        AnalyticsCard(
            title: "Efficiency",
            icon: "memorychip",
            color: .purple
        ) {
            let savings = UsageAnalytics.cacheSavings(from: stats)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(savings.description)
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
        AnalyticsCard(
            title: "Usage Trends",
            icon: "chart.line.uptrend.xyaxis",
            color: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let trend = calculateTrend(stats: stats) {
                    TrendRow(trend: trend)
                }
                
                if let peakDay = findPeakUsageDay(stats: stats) {
                    InfoRow(
                        label: "Peak Usage Day",
                        value: formatDate(peakDay.date),
                        detail: peakDay.totalCost.asCurrency
                    )
                }
            }
        }
    }
    
    private func calculateTrend(stats: UsageStats) -> UsageTrend? {
        guard stats.byDate.count >= 2 else { return nil }
        
        let recent = stats.byDate.suffix(7)
        let previous = stats.byDate.dropLast(7).suffix(7)
        
        guard !recent.isEmpty && !previous.isEmpty else { return nil }
        
        let recentAvg = recent.map { $0.totalCost }.reduce(0, +) / Double(recent.count)
        let previousAvg = previous.map { $0.totalCost }.reduce(0, +) / Double(previous.count)
        
        let change = ((recentAvg - previousAvg) / previousAvg) * 100
        
        return UsageTrend(
            direction: change > 0 ? .up : .down,
            percentage: abs(change)
        )
    }
    
    private func findPeakUsageDay(stats: UsageStats) -> DailyUsage? {
        stats.byDate.max(by: { $0.totalCost < $1.totalCost })
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

// MARK: - Supporting Views
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
                
                if let detail = detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

private struct EfficiencyRow: View {
    let label: String
    let value: String
    let percentage: Double?
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(value)
                    .font(.system(.body, design: .monospaced))
                
                if let percentage = percentage {
                    Text("(\(percentage.asPercentage))")
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
            Label("7-Day Trend", systemImage: trend.direction == .up ? "arrow.up.right" : "arrow.down.right")
                .foregroundColor(trend.direction == .up ? .red : .green)
            
            Spacer()
            
            Text("\(trend.direction == .up ? "+" : "-")\(trend.percentage.asPercentage)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(trend.direction == .up ? .red : .green)
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

// MARK: - Yearly Cost Heatmap Card
private struct YearlyCostHeatmapCard: View {
    let stats: UsageStats
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    private var availableYears: [Int] {
        let years = Set<Int>(stats.byDate.compactMap { dailyUsage in
            guard let year = Int(dailyUsage.date.prefix(4)) else { return nil }
            return year
        })
        return Array(years).sorted(by: >)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
//                HStack {
//                    Image(systemName: "calendar.badge.plus")
//                        .foregroundColor(.green)
//                    Text("Daily Cost Activity")
//                        .font(.headline)
//                }
                
                Spacer()
                
                // Year selector
                if availableYears.count > 1 {
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(String(year)) {
                                selectedYear = year
                            }
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
            
            YearlyCostHeatmap(stats: stats, year: selectedYear)
        }
        .onAppear {
            // Set initial year to the most recent year with data
            if let mostRecentYear = availableYears.first {
                selectedYear = mostRecentYear
            }
        }
    }
}

// MARK: - Supporting Types
private struct UsageTrend {
    enum Direction {
        case up, down
    }
    
    let direction: Direction
    let percentage: Double
}
