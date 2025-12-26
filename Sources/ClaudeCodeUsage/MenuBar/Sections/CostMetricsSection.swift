//
//  CostMetricsSection.swift
//  Cost metrics section component
//

import SwiftUI
import Charts
import ClaudeCodeUsageKit

struct CostMetricsSection: View {
    @Environment(UsageStore.self) private var store
    
    // Cache expensive computations
    @State private var cachedTodaysCostColor: Color = MenuBarTheme.Colors.Status.normal
    @State private var lastCostProgress: Double = 0
    
    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            // Today's cost with hourly graph
            todaysCostView
            
            // Summary stats
            if let stats = store.stats {
                summaryStatsView(stats)
            }
        }
        .onChange(of: store.todaysCostProgress) { oldValue, newValue in
            // Only update color when progress actually changes
            if abs(oldValue - newValue) > 0.01 {
                cachedTodaysCostColor = ColorService.colorForCostProgress(newValue)
                lastCostProgress = newValue
            }
        }
        .onAppear {
            // Initialize cached values
            cachedTodaysCostColor = ColorService.colorForCostProgress(store.todaysCostProgress)
            lastCostProgress = store.todaysCostProgress
        }
    }
    
    // MARK: - Today's Cost View
    private var todaysCostView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(MenuBarTheme.Typography.metricTitle)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
                
                HStack(spacing: 4) {
                    Text(store.todaysCost)
                        .font(MenuBarTheme.Typography.metricValue)
                        .foregroundColor(cachedTodaysCostColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)

                    if store.todaysCostProgress > 1.0 {
                        Image(systemName: "flame.fill")
                            .font(MenuBarTheme.Typography.warningIcon)
                            .foregroundColor(MenuBarTheme.Colors.Status.critical)
                    }
                }
            }
            .layoutPriority(1)
            
            Spacer()
            
            // Swift Charts-based hourly cost chart
            if !store.chartDataService.todayHourlyCosts.isEmpty {
                HourlyCostChartSimple(hourlyData: store.chartDataService.todayHourlyCosts)
            } else if !store.chartDataService.detailedHourlyData.isEmpty {
                HourlyCostChartSimple(from: store.chartDataService.detailedHourlyData)
            }
        }
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
                Text(FormatterService.formatDailyAverage(store.averageDailyCost))
                    .font(MenuBarTheme.Typography.summaryValue)
                    .monospacedDigit()
            }
        }
        .padding(.bottom, MenuBarTheme.Layout.verticalPadding)
    }
    
    // MARK: - Helper Properties
    // Removed computed property to avoid repeated calculations
}

// MARK: - Y-Axis Labels Component
private struct YAxisLabels: View {
    let maxValue: Double
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(formatCostValue(maxValue))
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(formatCostValue(maxValue * 0.75))
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(formatCostValue(maxValue * 0.5))
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(formatCostValue(maxValue * 0.25))
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("$0")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.bottom, 12) // Align with chart baseline
    }
    
    private func formatCostValue(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        } else if value < 1 {
            return String(format: "$%.2f", value)
        } else if value < 10 {
            return String(format: "$%.1f", value)
        } else if value < 100 {
            return String(format: "$%.0f", value)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}
