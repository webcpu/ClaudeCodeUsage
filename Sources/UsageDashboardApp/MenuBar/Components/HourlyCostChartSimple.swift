//
//  HourlyCostChartSimple.swift
//  Simplified Swift Charts implementation for hourly costs
//

import SwiftUI
import Charts
import ClaudeCodeUsage

// MARK: - Simple Hourly Cost Chart
struct HourlyCostChartSimple: View {
    let hourlyData: [Double] // 24 hours of cost data
    @State private var selectedHour: Int? = nil
    
    private var maxValue: Double {
        hourlyData.max() ?? 1.0
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    // Fixed y-axis scale to prevent changes on hover
    private var yAxisMax: Double {
        let max = hourlyData.max() ?? 1.0
        // Round up to a nice number
        if max <= 10 {
            return ceil(max)
        } else if max <= 50 {
            return ceil(max / 10) * 10
        } else if max <= 100 {
            return ceil(max / 20) * 20
        } else {
            return ceil(max / 50) * 50
        }
    }
    
    private var yAxisValues: [Double] {
        let max = yAxisMax
        if max <= 10 {
            return [0, max/2, max]
        } else {
            return [0, max/3, max*2/3, max]
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Title and max value
            HStack {
                Text("Hourly")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(maxValue > 0 ? String(format: "$%.1f", maxValue) : "$0")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            // Chart
            Chart(Array(hourlyData.enumerated()), id: \.offset) { hour, cost in
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Cost", cost)
                )
                .foregroundStyle(barColor(for: hour, cost: cost))
                .opacity(hour <= currentHour ? 1.0 : 0.3)
                
                // Hover indicator - just the line, no annotation
                if let selectedHour = selectedHour, selectedHour == hour {
                    RuleMark(x: .value("Hour", hour))
                        .foregroundStyle(.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
            }
            .chartXSelection(value: $selectedHour)
            .chartXAxis {
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
            .chartYAxis {
                AxisMarks(position: .trailing, values: yAxisValues) { value in
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(formatAxisValue(cost))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.25))
                        .foregroundStyle(.tertiary)
                }
            }
            .chartYScale(domain: 0...yAxisMax)
            .frame(height: 60)
            .padding(.trailing, 30) // Space for y-axis labels
            .overlay(alignment: .top) {
                // Tooltip overlay - positioned above chart, doesn't affect layout
                if let selectedHour = selectedHour,
                   selectedHour >= 0 && selectedHour < hourlyData.count {
                    let cost = hourlyData[selectedHour]
                    HourlyTooltipView(
                        hour: selectedHour,
                        cost: cost,
                        isCompact: true
                    )
                    .offset(x: tooltipXOffset(for: selectedHour), y: -5)
                    .allowsHitTesting(false)
                }
            }
        }
    }
    
    // Calculate x offset for tooltip based on hour
    private func tooltipXOffset(for hour: Int) -> CGFloat {
        let chartWidth: CGFloat = 200 // Approximate chart width
        let barWidth = chartWidth / 24
        let centerOffset = CGFloat(hour - 12) * barWidth
        
        // Clamp to prevent tooltip from going off screen
        return min(max(centerOffset, -80), 80)
    }
    
    private func barColor(for hour: Int, cost: Double) -> Color {
        if cost == 0 {
            return .gray.opacity(0.2)
        }
        
        // Use different shades of blue based on cost intensity
        let intensity = min(cost / max(maxValue, 1.0), 1.0)
        if intensity > 0.8 {
            return .blue
        } else if intensity > 0.5 {
            return .cyan
        } else if intensity > 0.2 {
            return .teal
        } else {
            return .mint
        }
    }
    
    private func formatAxisValue(_ value: Double) -> String {
        if value == 0 {
            return "$0"
        } else if value < 10 {
            return String(format: "$%.1f", value)
        } else {
            return String(format: "$%.0f", value)
        }
    }
}

// MARK: - Integration Helper
extension HourlyCostChartSimple {
    init(from detailedData: [HourlyChartData]) {
        // Aggregate costs by hour
        var hourlyCosts = Array(repeating: 0.0, count: 24)
        
        for data in detailedData {
            if data.hour >= 0 && data.hour < 24 {
                hourlyCosts[data.hour] += data.cost
            }
        }
        
        self.hourlyData = hourlyCosts
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