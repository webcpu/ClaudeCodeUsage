//
//  MetricRow.swift
//  Metric display row with progress bar and optional trend graph
//

import SwiftUI

@available(macOS 13.0, *)
struct MetricRow: View {
    let title: String
    let value: String
    let subvalue: String?
    let percentage: Double
    let segments: [ProgressSegment]
    let trendData: [Double]?
    let showWarning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: GlanceTheme.Layout.itemSpacing) {
            headerRow
            progressBarSection
        }
        .padding(.vertical, GlanceTheme.Layout.verticalPadding)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            titleSection
            Spacer()
            graphSection
            valueSection
        }
    }

    // MARK: - Graph Section

    @ViewBuilder
    private var graphSection: some View {
        if let data = trendData, data.count > 1 {
            GraphView(dataPoints: data, color: percentageColor)
                .frame(
                    width: GlanceTheme.Layout.graphWidth,
                    height: GlanceTheme.Layout.graphHeight
                )
                .padding(.trailing, 6)
        }
    }

    // MARK: - Progress Bar Section

    private var progressBarSection: some View {
        ProgressBar(
            value: progressBarValue,
            segments: segments,
            showOverflow: isOverLimit
        )
    }

    // MARK: - Pure Computations

    private var progressBarValue: Double {
        min(percentage / 100.0, 1.5)
    }

    private var isOverLimit: Bool {
        percentage > 100
    }

    private var shouldShowWarningIcon: Bool {
        showWarning && percentage >= 100
    }

    private var percentageColor: Color {
        ColorService.colorForPercentage(percentage)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            titleLabel
            percentageRow
        }
    }

    private var titleLabel: some View {
        Text(title)
            .font(GlanceTheme.Typography.metricTitle)
            .foregroundColor(GlanceTheme.Colors.UI.secondaryText)
    }

    private var percentageRow: some View {
        HStack(spacing: 6) {
            percentageLabel
            warningIcon
        }
    }

    private var percentageLabel: some View {
        Text(FormatterService.formatPercentage(percentage))
            .font(GlanceTheme.Typography.metricValue)
            .foregroundColor(percentageColor)
            .monospacedDigit()
    }

    @ViewBuilder
    private var warningIcon: some View {
        if shouldShowWarningIcon {
            Image(systemName: "flame.fill")
                .font(GlanceTheme.Typography.warningIcon)
                .foregroundColor(GlanceTheme.Colors.Status.critical)
        }
    }

    // MARK: - Value Section

    private var valueSection: some View {
        VStack(alignment: .trailing, spacing: 2) {
            primaryValueLabel
            subvalueLabel
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryValueLabel: some View {
        Text(value)
            .font(GlanceTheme.Typography.metricValue.weight(.medium))
            .foregroundColor(GlanceTheme.Colors.UI.primaryText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var subvalueLabel: some View {
        if let subvalue {
            Text(subvalue)
                .font(GlanceTheme.Typography.metricSubvalue)
                .foregroundColor(GlanceTheme.Colors.UI.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}