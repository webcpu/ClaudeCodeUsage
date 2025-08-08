//
//  CostMetricsSection.swift
//  Cost metrics section component
//

import SwiftUI
import ClaudeCodeUsage

struct CostMetricsSection: View {
    @Environment(UsageDataModel.self) private var dataModel
    @State private var chartDataService = ChartDataService()
    
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
            
            // Hourly cost bar chart
            if !chartDataService.todayHourlyCosts.isEmpty {
                BarChartView(
                    dataPoints: chartDataService.todayHourlyCosts
                )
                .frame(
                    width: 220,
                    height: 45
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