import SwiftUI
import Charts
import ClaudeCodeUsageKit

struct CostMetricsSection: View {
    @Environment(UsageStore.self) private var store

    @State private var cachedTodaysCostColor: Color = MenuBarTheme.Colors.Status.normal
    @State private var lastCostProgress: Double = 0

    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            todaysCostView
            summaryStatsViewIfAvailable
        }
        .onChange(of: store.todaysCostProgress) { oldValue, newValue in
            updateCostColorIfChanged(oldValue: oldValue, newValue: newValue)
        }
        .onAppear(perform: initializeCachedValues)
    }

    private var summaryStatsViewIfAvailable: some View {
        Group {
            if let stats = store.stats {
                summaryStatsView(stats)
            }
        }
    }

    private func updateCostColorIfChanged(oldValue: Double, newValue: Double) {
        guard abs(oldValue - newValue) > 0.01 else { return }
        cachedTodaysCostColor = ColorService.colorForCostProgress(newValue)
        lastCostProgress = newValue
    }

    private func initializeCachedValues() {
        cachedTodaysCostColor = ColorService.colorForCostProgress(store.todaysCostProgress)
        lastCostProgress = store.todaysCostProgress
    }
}

// MARK: - Today's Cost View

private extension CostMetricsSection {
    var todaysCostView: some View {
        HStack(spacing: 12) {
            todaysCostLabel
            Spacer()
            hourlyCostChartIfAvailable
        }
        .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
    }

    var todaysCostLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(MenuBarTheme.Typography.metricTitle)
                .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
            costValueWithWarning
        }
        .layoutPriority(1)
    }

    var costValueWithWarning: some View {
        HStack(spacing: 4) {
            Text(store.formattedTodaysCost)
                .font(MenuBarTheme.Typography.metricValue)
                .foregroundColor(cachedTodaysCostColor)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            budgetExceededWarningIfNeeded
        }
    }

    @ViewBuilder
    var budgetExceededWarningIfNeeded: some View {
        if store.todaysCostProgress > 1.0 {
            Image(systemName: "flame.fill")
                .font(MenuBarTheme.Typography.warningIcon)
                .foregroundColor(MenuBarTheme.Colors.Status.critical)
        }
    }

    @ViewBuilder
    var hourlyCostChartIfAvailable: some View {
        if !store.todayHourlyCosts.isEmpty {
            HourlyCostChartSimple(hourlyData: store.todayHourlyCosts)
        }
    }
}

// MARK: - Summary Stats View

private extension CostMetricsSection {
    func summaryStatsView(_ stats: UsageStats) -> some View {
        HStack {
            totalCostStat(stats)
            Spacer()
            dailyAverageStat
        }
        .padding(.bottom, MenuBarTheme.Layout.verticalPadding)
    }

    func totalCostStat(_ stats: UsageStats) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Total")
                .font(MenuBarTheme.Typography.summaryLabel)
                .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
            Text(stats.totalCost.asCurrency)
                .font(MenuBarTheme.Typography.summaryValue)
                .monospacedDigit()
        }
    }

    var dailyAverageStat: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("7d Avg")
                .font(MenuBarTheme.Typography.summaryLabel)
                .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
            Text(FormatterService.formatDailyAverage(store.averageDailyCost))
                .font(MenuBarTheme.Typography.summaryValue)
                .monospacedDigit()
        }
    }
}

// MARK: - Y-Axis Labels Component

private struct YAxisLabels: View {
    let maxValue: Double

    private static let labelMultipliers: [Double] = [1.0, 0.75, 0.5, 0.25, 0.0]

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Self.labelMultipliers, id: \.self) { multiplier in
                axisLabel(value: maxValue * multiplier)
                if multiplier != 0.0 {
                    Spacer()
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func axisLabel(value: Double) -> some View {
        Text(CostFormat.format(value))
            .font(.system(size: 8, weight: .regular, design: .monospaced))
            .foregroundColor(.gray)
    }
}

// MARK: - Cost Format

private enum CostFormat {
    static func format(_ value: Double) -> String {
        switch value {
        case 0:
            "$0"
        case ..<1:
            String(format: "$%.2f", value)
        case ..<10:
            String(format: "$%.1f", value)
        default:
            String(format: "$%.0f", value)
        }
    }
}
