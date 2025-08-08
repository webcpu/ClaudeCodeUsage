//
//  HourlyCostChart.swift
//  Swift Charts-based hourly cost visualization
//

import SwiftUI
import Charts
import ClaudeCodeUsage

// MARK: - Data Model for Chart
struct HourlyChartData: Identifiable {
    let id = UUID()
    let hour: Int
    let cost: Double
    let model: String?
    let project: String?
    
    var hourLabel: String {
        String(format: "%02d:00", hour)
    }
    
    var costLabel: String {
        cost > 0 ? String(format: "$%.2f", cost) : ""
    }
}

// MARK: - Hourly Cost Chart View
struct HourlyCostChart: View {
    let chartData: [HourlyChartData]
    @State private var selectedHour: Int? = nil
    
    private var maxValue: Double {
        chartData.map(\.cost).max() ?? 1.0
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    // Fixed y-axis scale to prevent changes on hover
    private var yAxisMax: Double {
        let max = maxValue
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
        VStack(spacing: 8) {
            // Chart Title
            HStack {
                Text("Today's Hourly Costs")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Text("Max: \(maxValue.asCurrency)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            // Chart
            Chart(chartData) { data in
                BarMark(
                    x: .value("Hour", data.hour),
                    y: .value("Cost", data.cost)
                )
                .foregroundStyle(colorForModel(data.model ?? "Unknown"))
                .opacity(data.hour <= currentHour ? (data.cost > 0 ? 1.0 : 0.3) : 0.1)
                .cornerRadius(2)
                
                // Add hover indicator - just the line, no annotation
                if let selectedHour = selectedHour, selectedHour == data.hour {
                    RuleMark(x: .value("Hour", data.hour))
                        .foregroundStyle(.primary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                }
            }
            .chartXSelection(value: $selectedHour)
            .chartXAxis {
                AxisMarks(values: .stride(by: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yAxisValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.tertiary)
                    AxisValueLabel {
                        if let cost = value.as(Double.self) {
                            Text(cost.asCurrency)
                                .font(.system(size: 8, weight: .regular, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...yAxisMax)
            .frame(height: 120)
            .padding(.horizontal, 8)
            .overlay(alignment: .top) {
                // Tooltip overlay - positioned above chart, doesn't affect layout
                if let selectedHour = selectedHour {
                    DetailedHourlyTooltipView(
                        data: hourlyDataForHour(selectedHour),
                        hour: selectedHour
                    )
                    .offset(x: tooltipXOffset(for: selectedHour), y: -5)
                    .allowsHitTesting(false)
                }
            }
            
            // Custom legend
            HStack(spacing: 16) {
                ForEach(uniqueModels, id: \.self) { model in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForModel(model))
                            .frame(width: 6, height: 6)
                        Text(shortModelName(model))
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Helper Methods
    private var uniqueModels: [String] {
        Array(Set(chartData.compactMap(\.model))).sorted()
    }
    
    // Calculate x offset for tooltip based on hour
    private func tooltipXOffset(for hour: Int) -> CGFloat {
        let chartWidth: CGFloat = 280 // Approximate chart width for this larger chart
        let barWidth = chartWidth / 24
        let centerOffset = CGFloat(hour - 12) * barWidth
        
        // Clamp to prevent tooltip from going off screen
        return min(max(centerOffset, -100), 100)
    }
    
    func colorForModel(_ model: String) -> Color {
        switch model.lowercased() {
        case let m where m.contains("opus"):
            return .blue
        case let m where m.contains("sonnet"):
            return .cyan
        case let m where m.contains("haiku"):
            return .green
        default:
            return .gray
        }
    }
    
    private func shortModelName(_ model: String) -> String {
        if model.lowercased().contains("opus") {
            return "Opus"
        } else if model.lowercased().contains("sonnet") {
            return "Sonnet"
        } else if model.lowercased().contains("haiku") {
            return "Haiku"
        } else {
            return "Other"
        }
    }
}

// MARK: - Data Transformation Extension
extension UsageAnalytics {
    /// Get detailed hourly cost data with model and project information
    static func detailedHourlyCosts(from entries: [UsageEntry]) -> [HourlyChartData] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Filter entries for today
        let todayEntries = entries.filter { entry in
            guard let date = entry.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }
        
        // Group by hour, preserving model information
        var hourlyData: [Int: [(cost: Double, model: String, project: String)]] = [:]
        
        for entry in todayEntries {
            guard let date = entry.date else { continue }
            let hour = calendar.component(.hour, from: date)
            hourlyData[hour, default: []].append((
                cost: entry.cost,
                model: entry.model,
                project: entry.project
            ))
        }
        
        // Create chart data for all 24 hours
        var chartData: [HourlyChartData] = []
        
        for hour in 0..<24 {
            if let hourEntries = hourlyData[hour], !hourEntries.isEmpty {
                // If multiple entries in the same hour, combine by model
                let modelGroups = Dictionary(grouping: hourEntries) { $0.model }
                
                for (model, entries) in modelGroups {
                    let totalCost = entries.reduce(0) { $0 + $1.cost }
                    if totalCost > 0 {
                        chartData.append(HourlyChartData(
                            hour: hour,
                            cost: totalCost,
                            model: model,
                            project: entries.first?.project
                        ))
                    }
                }
            } else {
                // Empty hour
                chartData.append(HourlyChartData(
                    hour: hour,
                    cost: 0,
                    model: nil,
                    project: nil
                ))
            }
        }
        
        return chartData.sorted { $0.hour < $1.hour }
    }
}

// MARK: - Preview
struct HourlyCostChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            HourlyCostChart(chartData: sampleData)
            Spacer()
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
    
    static var sampleData: [HourlyChartData] {
        [
            HourlyChartData(hour: 9, cost: 0.25, model: "claude-sonnet-4", project: "TestProject"),
            HourlyChartData(hour: 10, cost: 1.50, model: "claude-opus-4", project: "TestProject"),
            HourlyChartData(hour: 11, cost: 0.75, model: "claude-sonnet-4", project: "TestProject"),
            HourlyChartData(hour: 14, cost: 2.25, model: "claude-opus-4", project: "TestProject"),
        ] + (0..<24).compactMap { hour in
            ![9, 10, 11, 14].contains(hour) ? HourlyChartData(hour: hour, cost: 0, model: nil, project: nil) : nil
        }
    }
}