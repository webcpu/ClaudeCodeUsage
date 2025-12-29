//
//  YearlyCostHeatmap.swift
//  Refactored yearly cost heatmap with clean architecture
//
//  Modern SwiftUI heatmap component with MVVM architecture,
//  comprehensive error handling, and performance optimizations.
//
//  Split into extensions for focused responsibilities:
//    - +Factories: Static factory methods and legacy compatibility
//    - +Preview: Preview provider for development
//

import SwiftUI
import ClaudeCodeUsageKit
import Foundation

// MARK: - Yearly Cost Heatmap

/// GitHub-style contribution graph for daily cost visualization
///
/// This component has been completely refactored to follow clean architecture principles:
/// - MVVM architecture with dedicated ViewModel
/// - Separated data models and business logic
/// - Reusable subcomponents (Grid, Legend, Tooltip)
/// - Comprehensive error handling and validation
/// - Performance optimizations with caching
/// - Accessibility support
/// - Backward compatibility maintained
public struct YearlyCostHeatmap: View {

    // MARK: - Properties

    /// Usage statistics to visualize
    let stats: UsageStats

    /// Year parameter (kept for backward compatibility, now ignored in favor of rolling year)
    let year: Int

    /// Configuration for heatmap appearance and behavior
    let configuration: HeatmapConfiguration

    /// View model managing data and state
    @State private var viewModel: HeatmapViewModel

    /// Screen bounds for tooltip positioning
    @State private var screenBounds: CGRect = NSScreen.main?.frame ?? .zero

    // MARK: - Initialization

    /// Initialize with usage statistics and optional configuration
    /// - Parameters:
    ///   - stats: Usage statistics to display
    ///   - year: Year (kept for backward compatibility, ignored)
    ///   - configuration: Heatmap configuration (defaults to standard)
    public init(
        stats: UsageStats,
        year: Int,
        configuration: HeatmapConfiguration = .default
    ) {
        self.stats = stats
        self.year = year
        self.configuration = configuration

        // Initialize view model with configuration
        self._viewModel = State(wrappedValue: HeatmapViewModel(configuration: configuration))
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            contentSection
            legendSectionIfVisible
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(configuration.padding)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .task { await viewModel.updateStats(stats) }
        .onAppear { screenBounds = NSScreen.main?.frame ?? .zero }
    }

    private var shouldShowLegend: Bool {
        configuration.showLegend && viewModel.hasData
    }

    @ViewBuilder
    private var legendSectionIfVisible: some View {
        if shouldShowLegend {
            legendSection
        }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            titleAndSummary
            Spacer()
            costSummary
        }
    }

    private var titleAndSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerTitle
            summarySubtitle
        }
    }

    private var headerTitle: some View {
        HStack {
            Image(systemName: "calendar.badge.plus")
                .foregroundColor(.green)
            Text("Daily Cost Activity")
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var summarySubtitle: some View {
        if let summary = viewModel.summaryStats {
            Text("\(summary.daysWithUsage) days of usage in last 365 days")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if viewModel.isLoading {
            Text("Loading usage data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var costSummary: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let summary = viewModel.summaryStats {
                Text(summary.totalCost.asCurrency)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("Last 365 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error)
            } else if let dataset = viewModel.dataset {
                heatmapContent(dataset)
            } else {
                emptyStateView
            }
        }
        .overlay(tooltipOverlay, alignment: .topLeading)
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Generating heatmap...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: HeatmapError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text("Unable to Display Heatmap")
                .font(.headline)
                .foregroundColor(.primary)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.updateStats(stats)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Empty State View

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 24))
                .foregroundColor(.gray)

            Text("No Usage Data")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Heatmap will appear once you have usage data.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heatmap Content

    @ViewBuilder
    private func heatmapContent(_ dataset: HeatmapDataset) -> some View {
        let gridLayout = HeatmapGridLayout(configuration: configuration, dataset: dataset)

        HeatmapGrid(
            dataset: dataset,
            configuration: configuration,
            hoveredDay: viewModel.hoveredDay,
            onHover: { location in
                viewModel.handleHover(at: location, in: .zero)
            },
            onEndHover: {
                viewModel.endHover()
            }
        )
        .frame(height: gridLayout.totalSize.height)
        .accessibilityLabel("Heatmap showing daily cost activity over the last 365 days")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Legend Section

    @ViewBuilder
    private var legendSection: some View {
        if let dataset = viewModel.dataset {
            HeatmapLegend(
                colorTheme: configuration.colorScheme,
                maxCost: dataset.maxCost,
                style: .horizontal,
                font: configuration.legendFont
            )
        }
    }

    // MARK: - Tooltip Overlay

    @ViewBuilder
    private var tooltipOverlay: some View {
        if let hoveredDay = viewModel.hoveredDay,
           configuration.enableTooltips {
            HeatmapTooltip(
                day: hoveredDay,
                position: viewModel.tooltipPosition,
                style: .standard,
                screenBounds: screenBounds
            )
            .position(viewModel.tooltipPosition)
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.1), value: viewModel.tooltipPosition)
        }
    }
}
