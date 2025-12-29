//
//  HourlyCostChartSimple.swift
//  Simplified Swift Charts implementation for hourly costs
//

import SwiftUI
import Charts
import ClaudeUsageCore

// MARK: - Simple Hourly Cost Chart

struct HourlyCostChartSimple: View {
    let hourlyData: [Double]
    var maxScale: Double? = nil // Optional shared scale for comparing multiple charts
    @State private var selectedHour: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = geometry.size.width - 25
            VStack(spacing: 4) {
                headerRow
                chart
            }
            .overlay(alignment: .top) {
                tooltipOverlay(chartWidth: chartWidth, totalWidth: geometry.size.width)
            }
        }
        .frame(height: 76) // 16 (header) + 60 (chart)
    }
}

// MARK: - Computed Properties

private extension HourlyCostChartSimple {
    var maxValue: Double {
        maxScale ?? hourlyData.max() ?? 1.0
    }

    var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    var yAxisScale: YAxisScale {
        YAxisScale(maxValue: maxValue)
    }

    var headerRow: some View {
        Text("Hourly")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var chart: some View {
        costChart
            .frame(height: 60)
            .padding(.trailing, 25)
    }

    var costChart: some View {
        Chart(Array(hourlyData.enumerated()), id: \.offset) { hour, cost in
            BarMark(
                x: .value("Hour", hour),
                y: .value("Cost", cost)
            )
            .foregroundStyle(CostIntensity(cost: cost, maxValue: maxValue).color)
            .opacity(hour <= currentHour ? 1.0 : 0.3)

            if let selectedHour, selectedHour == hour {
                selectionIndicator(for: hour)
            }
        }
        .chartXSelection(value: $selectedHour)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartYScale(domain: 0...yAxisScale.roundedMax)
    }

    var xAxisMarks: some AxisContent {
        AxisMarks(values: [0, 6, 12, 18, 23]) { value in
            AxisValueLabel {
                if let hour = value.as(Int.self) {
                    Text("\(hour)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var yAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: yAxisScale.tickValues) { value in
            AxisValueLabel {
                if let cost = value.as(Double.self) {
                    Text(CostAxisFormat(cost).formatted)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.25))
                .foregroundStyle(.tertiary)
        }
    }

    func selectionIndicator(for hour: Int) -> some ChartContent {
        RuleMark(x: .value("Hour", hour))
            .foregroundStyle(.primary.opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
    }

    @ViewBuilder
    func tooltipOverlay(chartWidth: CGFloat, totalWidth: CGFloat) -> some View {
        if let selectedHour,
           selectedHour >= 0 && selectedHour < hourlyData.count {
            HourlyTooltipView(
                hour: selectedHour,
                cost: hourlyData[selectedHour],
                isCompact: true
            )
            .offset(x: tooltipXPosition(for: selectedHour, chartWidth: chartWidth, totalWidth: totalWidth))
            .allowsHitTesting(false)
        }
    }

    func tooltipXPosition(for hour: Int, chartWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        // With .top alignment, offset is relative to VStack center
        let barWidth = chartWidth / 24
        let barCenter = (CGFloat(hour) + 0.5) * barWidth
        let vstackCenter = totalWidth / 2
        return barCenter - vstackCenter
    }
}

// MARK: - Preview

struct HourlyCostChartSimple_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HourlyCostChartSimple(hourlyData: sampleHourlyData)
                .padding()
            Spacer()
        }
        .frame(width: 300, height: 200)
        .background(Color(.windowBackgroundColor))
    }

    static var sampleHourlyData: [Double] {
        [
            0, 0, 0, 2.5, 5.0, 3.2, 8.5, 12.0, 15.5, 10.0,
            8.5, 7.2, 6.0, 9.5, 11.0, 8.0, 5.5, 3.0, 2.0, 1.5,
            0.5, 0, 0, 0
        ]
    }
}

// MARK: - Supporting Types

// MARK: Cost Intensity

enum CostIntensity {
    case zero
    case low
    case medium
    case high
    case peak

    init(cost: Double, maxValue: Double) {
        guard cost > 0 else {
            self = .zero
            return
        }
        let intensity = min(cost / max(maxValue, 1.0), 1.0)
        switch intensity {
        case 0.8...: self = .peak
        case 0.5...: self = .high
        case 0.2...: self = .medium
        default: self = .low
        }
    }

    var color: Color {
        switch self {
        case .zero: .gray.opacity(0.2)
        case .low: .mint
        case .medium: .teal
        case .high: .cyan
        case .peak: .blue
        }
    }
}

// MARK: Y-Axis Scale

enum YAxisScale {
    case small(max: Double)
    case medium(max: Double)
    case large(max: Double)
    case extraLarge(max: Double)

    init(maxValue: Double) {
        switch maxValue {
        case ...10: self = .small(max: maxValue)
        case ...50: self = .medium(max: maxValue)
        case ...100: self = .large(max: maxValue)
        default: self = .extraLarge(max: maxValue)
        }
    }

    var roundedMax: Double {
        switch self {
        case .small(let max): ceil(max)
        case .medium(let max): ceil(max / 10) * 10
        case .large(let max): ceil(max / 20) * 20
        case .extraLarge(let max): ceil(max / 50) * 50
        }
    }

    var tickValues: [Double] {
        let max = roundedMax
        switch self {
        case .small: return [0, max / 2, max]
        default: return [0, max / 3, max * 2 / 3, max]
        }
    }
}

// MARK: Cost Formatting

enum CostAxisFormat {
    case zero
    case decimal(Double)
    case whole(Double)

    init(_ value: Double) {
        switch value {
        case 0: self = .zero
        case ..<10: self = .decimal(value)
        default: self = .whole(value)
        }
    }

    var formatted: String {
        switch self {
        case .zero: "$0"
        case .decimal(let value): String(format: "$%.1f", value)
        case .whole(let value): String(format: "$%.0f", value)
        }
    }
}
