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
    var maxScale: Double? = nil
    @State private var selectedHour: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            chartLayout(geometry: geometry)
        }
        .frame(height: Layout.totalHeight)
    }
}

// MARK: - Layout Constants

private extension HourlyCostChartSimple {
    enum Layout {
        static let yAxisWidth: CGFloat = 25
        static let chartHeight: CGFloat = 60
        static let headerHeight: CGFloat = 16
        static let totalHeight: CGFloat = headerHeight + chartHeight
        static let chartPadding: CGFloat = 8
        static let verticalSpacing: CGFloat = 4
    }

    enum Opacity {
        static let pastHour: Double = 1.0
        static let futureHour: Double = 0.3
    }

    enum AxisConfig {
        static let hourMarks = [0, 6, 12, 18, 23]
        static let gridLineWidth: CGFloat = 0.25
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

    var chartWidth: CGFloat {
        Layout.yAxisWidth
    }
}

// MARK: - View Composition

private extension HourlyCostChartSimple {
    func chartLayout(geometry: GeometryProxy) -> some View {
        let chartWidth = geometry.size.width - Layout.yAxisWidth
        return VStack(spacing: Layout.verticalSpacing) {
            headerView
            chartView
        }
        .overlay(alignment: .top) {
            tooltipView(chartWidth: chartWidth, totalWidth: geometry.size.width)
        }
    }

    var headerView: some View {
        Text("Hourly")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var chartView: some View {
        costChart
            .frame(height: Layout.chartHeight)
            .padding(.trailing, Layout.yAxisWidth)
    }
}

// MARK: - Chart Content

private extension HourlyCostChartSimple {
    var costChart: some View {
        Chart(enumeratedHourlyData, id: \.offset) { hour, cost in
            hourlyBar(hour: hour, cost: cost)
            selectionMark(for: hour)
        }
        .chartXSelection(value: $selectedHour)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartYScale(domain: 0...yAxisScale.roundedMax)
        .chartXScale(range: .plotDimension(padding: Layout.chartPadding))
    }

    var enumeratedHourlyData: [(offset: Int, element: Double)] {
        Array(hourlyData.enumerated())
    }

    func hourlyBar(hour: Int, cost: Double) -> some ChartContent {
        BarMark(
            x: .value("Hour", hour),
            y: .value("Cost", cost)
        )
        .foregroundStyle(barColor(for: cost))
        .opacity(barOpacity(for: hour))
    }

    func barColor(for cost: Double) -> Color {
        CostIntensity(cost: cost, maxValue: maxValue).color
    }

    func barOpacity(for hour: Int) -> Double {
        hour <= currentHour ? Opacity.pastHour : Opacity.futureHour
    }

    @ChartContentBuilder
    func selectionMark(for hour: Int) -> some ChartContent {
        if let selectedHour, selectedHour == hour {
            RuleMark(x: .value("Hour", hour))
                .foregroundStyle(.primary.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }
}

// MARK: - Axis Configuration

private extension HourlyCostChartSimple {
    var xAxisMarks: some AxisContent {
        AxisMarks(values: AxisConfig.hourMarks) { value in
            AxisValueLabel {
                hourLabel(for: value)
            }
        }
    }

    func hourLabel(for value: AxisValue) -> some View {
        Group {
            if let hour = value.as(Int.self) {
                Text("\(hour)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
        }
    }

    var yAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: yAxisScale.tickValues) { value in
            AxisValueLabel {
                costLabel(for: value)
            }
            gridLine
        }
    }

    func costLabel(for value: AxisValue) -> some View {
        Group {
            if let cost = value.as(Double.self) {
                Text(CostAxisFormat(cost).formatted)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    var gridLine: some AxisMark {
        AxisGridLine(stroke: StrokeStyle(lineWidth: AxisConfig.gridLineWidth))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Tooltip

private extension HourlyCostChartSimple {
    @ViewBuilder
    func tooltipView(chartWidth: CGFloat, totalWidth: CGFloat) -> some View {
        if let selectedHour, isValidHour(selectedHour) {
            HourlyTooltipView(
                hour: selectedHour,
                cost: hourlyData[selectedHour],
                isCompact: true
            )
            .offset(x: tooltipXOffset(for: selectedHour, chartWidth: chartWidth, totalWidth: totalWidth))
            .allowsHitTesting(false)
        }
    }

    func isValidHour(_ hour: Int) -> Bool {
        hourlyData.indices.contains(hour)
    }

    func tooltipXOffset(for hour: Int, chartWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let barCenter = calculateBarCenter(for: hour, chartWidth: chartWidth)
        let viewCenter = totalWidth / 2
        return barCenter - viewCenter
    }

    func calculateBarCenter(for hour: Int, chartWidth: CGFloat) -> CGFloat {
        let barWidth = chartWidth / 24
        return (CGFloat(hour) + 0.5) * barWidth
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
        self = Self.classify(intensity: cost / max(maxValue, 1.0))
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

private extension CostIntensity {
    static func classify(intensity: Double) -> CostIntensity {
        let clamped = min(intensity, 1.0)
        switch clamped {
        case 0.8...: return .peak
        case 0.5...: return .high
        case 0.2...: return .medium
        default: return .low
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
        switch self {
        case .small: [0, roundedMax / 2, roundedMax]
        default: [0, roundedMax / 3, roundedMax * 2 / 3, roundedMax]
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
