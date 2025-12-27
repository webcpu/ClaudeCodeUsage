//
//  OverviewView.swift
//  Overview dashboard view
//

import SwiftUI
import ClaudeCodeUsageKit

struct OverviewView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            OverviewContent(state: ContentState.from(store: store))
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

private struct OverviewContent: View {
    let state: ContentState

    var body: some View {
        switch state {
        case .loading:
            LoadingView(message: "Loading...")
        case .loaded(let stats):
            LoadedContent(stats: stats)
        case .error:
            EmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "No Data Available",
                message: "Run Claude Code sessions to generate usage data."
            )
        }
    }
}

private struct LoadedContent: View {
    let stats: UsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OverviewHeader()
            MetricsGrid(stats: stats)
            CostBreakdownSection(stats: stats)
        }
        .padding()
    }
}

// MARK: - Header

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

// MARK: - Loading View

private struct LoadingView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
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
            MetricCard(title: "Total Cost", value: stats.totalCost.asCurrency, icon: "dollarsign.circle", color: .green)
            MetricCard(title: "Total Sessions", value: "\(stats.totalSessions)", icon: "doc.text", color: .blue)
            MetricCard(title: "Total Tokens", value: stats.totalTokens.abbreviated, icon: "number", color: .purple)
            MetricCard(title: "Avg Cost/Session", value: stats.averageCostPerSession.asCurrency, icon: "chart.line.uptrend.xyaxis", color: .orange)
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
            Text(ModelNameFormatter.format(item.model))
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
}

// MARK: - Pure Transformations

private enum ModelNameFormatter {
    static func format(_ model: String) -> String {
        model.components(separatedBy: "-").prefix(3).joined(separator: "-")
    }
}
