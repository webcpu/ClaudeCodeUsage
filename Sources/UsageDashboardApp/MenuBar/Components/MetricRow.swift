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
    let percentage: Double // Can be > 100
    let segments: [ProgressSegment]
    let trendData: [Double]?
    let showWarning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: MenuBarTheme.Layout.itemSpacing) {
            // Title and value
            HStack {
                titleSection
                Spacer()
                
                // Graph (if available)
                if let trendData = trendData, trendData.count > 1 {
                    GraphView(
                        dataPoints: trendData,
                        color: percentageColor
                    )
                    .frame(
                        width: MenuBarTheme.Layout.graphWidth,
                        height: MenuBarTheme.Layout.graphHeight
                    )
                    .padding(.trailing, 6)
                }
                
                valueSection
            }
            
            // Progress bar
            ProgressBar(
                value: min(percentage / 100.0, 1.5), // Allow up to 150% visual
                segments: segments,
                showOverflow: percentage > 100
            )
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(MenuBarTheme.Typography.metricTitle)
                .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
            
            HStack(spacing: 6) {
                Text(FormatterService.formatPercentage(percentage))
                    .font(MenuBarTheme.Typography.metricValue)
                    .foregroundColor(percentageColor)
                    .monospacedDigit()
                
                if showWarning && percentage >= 100 {
                    Image(systemName: "flame.fill")
                        .font(MenuBarTheme.Typography.warningIcon)
                        .foregroundColor(MenuBarTheme.Colors.Status.critical)
                }
            }
        }
    }
    
    // MARK: - Value Section
    private var valueSection: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(MenuBarTheme.Typography.metricValue.weight(.medium))
                .foregroundColor(MenuBarTheme.Colors.UI.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let subvalue = subvalue {
                Text(subvalue)
                    .font(MenuBarTheme.Typography.metricSubvalue)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Helper Properties
    private var percentageColor: Color {
        ColorService.colorForPercentage(percentage)
    }
}