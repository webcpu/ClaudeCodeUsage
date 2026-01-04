//
//  AnalyticsView.swift
//  Analytics and insights view
//

import SwiftUI

struct AnalyticsView: View {
    @Environment(InsightsStore.self) private var store

    var body: some View {
        CaptureCompatibleScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AnalyticsHeader()
                ContentStateRouterView(
                    state: contentState(from: store),
                    router: AnalyticsRouter()
                )
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840)
    }

    private func contentState(from store: InsightsStore) -> RoutableState<UsageStats> {
        if store.isLoading { return .loading }
        guard let stats = store.stats else { return .error }
        return .loaded(stats)
    }
}

// MARK: - Router

private struct AnalyticsRouter: ContentStateRouting {
    var loadingMessage: String { "Analyzing data..." }

    var errorDisplay: ErrorDisplay {
        ErrorDisplay(
            icon: "chart.bar.xaxis",
            title: "No Analytics Available",
            message: "Analytics will appear once you have usage data."
        )
    }

    func loadedView(for stats: UsageStats) -> some View {
        AnalyticsCards(stats: stats)
    }
}

private struct AnalyticsCards: View {
    let stats: UsageStats

    var body: some View {
        VStack(spacing: 16) {
            YearlyCostHeatmapCard(stats: stats)
            TokenDistributionCard(stats: stats)
            PredictionsCard(stats: stats)
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

