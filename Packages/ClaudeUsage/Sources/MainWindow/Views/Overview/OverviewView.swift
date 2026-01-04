//
//  OverviewView.swift
//  Overview dashboard view
//

import SwiftUI

struct OverviewView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        CaptureCompatibleScrollView {
            OverviewContent(state: ContentState.from(store: store))
        }
        .frame(minWidth: 600, idealWidth: 840)
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
            titleView
            subtitleView
        }
    }

    private var titleView: some View {
        Text("Overview")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var subtitleView: some View {
        Text("Your Claude Code usage at a glance")
            .font(.subheadline)
            .foregroundColor(.secondary)
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
            totalCostCard
            totalSessionsCard
            totalTokensCard
            avgCostCard
        }
    }

    private var totalCostCard: some View {
        MetricCard(title: "Total Cost", value: stats.totalCost.asCurrency, icon: "dollarsign.circle", color: .green)
    }

    private var totalSessionsCard: some View {
        MetricCard(title: "Total Sessions", value: "\(stats.sessionCount)", icon: "doc.text", color: .blue)
    }

    private var totalTokensCard: some View {
        MetricCard(title: "Total Tokens", value: stats.totalTokens.abbreviated, icon: "number", color: .purple)
    }

    private var avgCostCard: some View {
        MetricCard(title: "Avg Cost/Session", value: stats.averageCostPerSession.asCurrency, icon: "chart.line.uptrend.xyaxis", color: .orange)
    }
}

// MARK: - Cost Breakdown Section

private struct CostBreakdownSection: View {
    let stats: UsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle
            breakdownList
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var sectionTitle: some View {
        Text("Cost Breakdown by Model")
            .font(.headline)
    }

    private var breakdownList: some View {
        VStack(spacing: 8) {
            ForEach(UsageAnalytics.costBreakdown(from: stats), id: \.model) { item in
                CostBreakdownRow(item: item)
            }
        }
    }
}

// MARK: - Cost Breakdown Row

private struct CostBreakdownRow: View {
    let item: (model: String, cost: Double, percentage: Double)

    var body: some View {
        HStack {
            modelNameText
            Spacer()
            percentageText
            costText
        }
        .padding(.vertical, 4)
    }

    private var modelNameText: some View {
        Text(ModelNameFormatter.format(item.model))
            .font(.subheadline)
    }

    private var percentageText: some View {
        Text(item.percentage.asPercentage)
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private var costText: some View {
        Text(item.cost.asCurrency)
            .font(.system(.body, design: .monospaced))
            .frame(minWidth: 80, alignment: .trailing)
    }
}

// ModelNameFormatter is now provided by ClaudeUsageCore
