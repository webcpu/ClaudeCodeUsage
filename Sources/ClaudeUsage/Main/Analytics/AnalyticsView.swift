//
//  AnalyticsView.swift
//  Analytics and insights view
//

import SwiftUI
import ClaudeUsageCore

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
            titleView
            subtitleView
        }
    }

    private var titleView: some View {
        Text("Analytics")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var subtitleView: some View {
        Text("Insights and predictions based on your usage")
            .font(.subheadline)
            .foregroundColor(.secondary)
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
