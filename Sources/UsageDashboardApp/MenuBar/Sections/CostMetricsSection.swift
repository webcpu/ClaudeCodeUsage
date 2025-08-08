//
//  CostMetricsSection.swift
//  Cost metrics section component
//

import SwiftUI
import ClaudeCodeUsage

@available(macOS 13.0, *)
struct CostMetricsSection: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @StateObject private var chartDataService = ChartDataService()
    
    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            // Today's cost with hourly graph
            todaysCostView
            
            // Summary stats
            if let stats = dataModel.stats {
                summaryStatsView(stats)
            }
        }
        .onAppear {
            Task {
                await chartDataService.loadTodayHourlyCosts()
            }
        }
    }
    
    // MARK: - Today's Cost View
    private var todaysCostView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(MenuBarTheme.Typography.metricTitle)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                
                HStack(spacing: 6) {
                    Text(dataModel.todaysCost)
                        .font(MenuBarTheme.Typography.metricValue)
                        .foregroundColor(todaysCostColor)
                        .monospacedDigit()
                    
                    if dataModel.todaysCostProgress > 1.0 {
                        Image(systemName: "flame.fill")
                            .font(MenuBarTheme.Typography.warningIcon)
                            .foregroundColor(MenuBarTheme.Colors.Status.critical)
                    }
                }
            }
            
            Spacer()
            
            // Hourly cost graph
            if !chartDataService.todayHourlyCosts.isEmpty {
                GraphView(
                    dataPoints: chartDataService.todayHourlyCosts,
                    color: todaysCostColor
                )
                .frame(
                    width: MenuBarTheme.Layout.largeGraphWidth,
                    height: MenuBarTheme.Layout.costGraphHeight
                )
            }
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
    }
    
    // MARK: - Summary Stats View
    private func summaryStatsView(_ stats: UsageStats) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total")
                    .font(MenuBarTheme.Typography.summaryLabel)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                Text(stats.totalCost.asCurrency)
                    .font(MenuBarTheme.Typography.summaryValue)
                    .monospacedDigit()
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Daily Avg")
                    .font(MenuBarTheme.Typography.summaryLabel)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                Text(FormatterService.formatDailyAverage(dataModel.averageDailyCost))
                    .font(MenuBarTheme.Typography.summaryValue)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.bottom, MenuBarTheme.Layout.verticalPadding)
    }
    
    // MARK: - Helper Properties
    private var todaysCostColor: Color {
        ColorService.colorForCostProgress(dataModel.todaysCostProgress)
    }
}