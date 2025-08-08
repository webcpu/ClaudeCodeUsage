//
//  OverviewScreen.swift
//  Overview dashboard screen
//

import SwiftUI
import ClaudeCodeUsage

struct OverviewScreen: View {
    @Environment(UsageDataModel.self) private var dataModel
    
    var body: some View {
        ScrollView {
            if dataModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if let stats = dataModel.stats {
                VStack(alignment: .leading, spacing: 20) {
                    OverviewHeader()
                    
                    MetricsGrid(stats: stats)
                    
                    CostBreakdownSection(stats: stats)
                }
                .padding()
            } else {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Data Available",
                    message: "Run Claude Code sessions to generate usage data."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Overview Header
private struct OverviewHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your Claude Code usage at a glance")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Metrics Grid
private struct MetricsGrid: View {
    let stats: UsageStats
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            MetricCard(
                title: "Total Cost",
                value: stats.totalCost.asCurrency,
                icon: "dollarsign.circle",
                color: .green
            )
            
            MetricCard(
                title: "Total Sessions",
                value: "\(stats.totalSessions)",
                icon: "doc.text",
                color: .blue
            )
            
            MetricCard(
                title: "Total Tokens",
                value: stats.totalTokens.abbreviated,
                icon: "number",
                color: .purple
            )
            
            MetricCard(
                title: "Avg Cost/Session",
                value: stats.averageCostPerSession.asCurrency,
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            )
        }
    }
}

// MARK: - Cost Breakdown Section
private struct CostBreakdownSection: View {
    let stats: UsageStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cost Breakdown by Model")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(UsageAnalytics.costBreakdown(from: stats), id: \.model) { item in
                    CostBreakdownRow(item: item)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Cost Breakdown Row
private struct CostBreakdownRow: View {
    let item: (model: String, cost: Double, percentage: Double)
    
    var body: some View {
        HStack {
            Text(formatModelName(item.model))
                .font(.subheadline)
            
            Spacer()
            
            Text(item.percentage.asPercentage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(item.cost.asCurrency)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    private func formatModelName(_ model: String) -> String {
        model.components(separatedBy: "-").prefix(3).joined(separator: "-")
    }
}