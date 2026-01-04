import SwiftUI
import Charts

struct CostMetricsSection: View {
    @Environment(GlanceStore.self) private var store

    @State private var cachedTodaysCostColor: Color = GlanceTheme.Colors.Status.normal
    @State private var lastCostProgress: Double = 0

    var body: some View {
        VStack(spacing: GlanceTheme.Layout.sectionSpacing) {
            todaysCostView
        }
        .onAppear(perform: initializeCachedValues)
    }

    private func initializeCachedValues() {
        cachedTodaysCostColor = GlanceTheme.Colors.Status.normal
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
        .padding(.vertical, GlanceTheme.Layout.verticalPadding)
    }

    var todaysCostLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(GlanceTheme.Typography.metricTitle)
                .foregroundColor(GlanceTheme.Colors.UI.secondaryText)
            costValueWithWarning
        }
        .layoutPriority(1)
    }

    var costValueWithWarning: some View {
        Text(store.formattedTodaysCost)
            .font(GlanceTheme.Typography.metricValue)
            .foregroundColor(cachedTodaysCostColor)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    var hourlyCostChartIfAvailable: some View {
        if !store.todayHourlyCosts.isEmpty {
            HourlyCostChartSimple(hourlyData: store.todayHourlyCosts)
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
