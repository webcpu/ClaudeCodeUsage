//
//  HourlyTooltipViews.swift
//  Tooltip views for hourly cost charts
//

import SwiftUI
import Charts
import ClaudeCodeUsageKit

// MARK: - Simple Tooltip View
struct HourlyTooltipView: View {
    let hour: Int
    let cost: Double
    let isCompact: Bool
    
    private var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? "HH:mm" : "h:mm a"
        
        // Create a date for the given hour today
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        var hourComponents = components
        hourComponents.hour = hour
        hourComponents.minute = 0
        
        if let date = calendar.date(from: hourComponents) {
            return formatter.string(from: date)
        }
        return String(format: "%02d:00", hour)
    }
    
    private var formattedCost: String {
        if cost == 0 {
            return "$0.00"
        }
        return cost.asCurrency
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(formattedHour)
                .font(.system(size: isCompact ? 9 : 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            
            Text(formattedCost)
                .font(.system(size: isCompact ? 8 : 9, weight: .medium, design: .monospaced))
                .foregroundColor(cost > 0 ? .blue : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.background.opacity(0.95))
                .stroke(.tertiary, lineWidth: 0.5)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hour \(formattedHour), cost \(formattedCost)")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.15), value: hour)
    }
}

// MARK: - Detailed Tooltip View
struct DetailedHourlyTooltipView: View {
    let data: [HourlyChartData]
    let hour: Int
    
    private var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Create a date for the given hour today
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        var hourComponents = components
        hourComponents.hour = hour
        hourComponents.minute = 0
        
        if let date = calendar.date(from: hourComponents) {
            return formatter.string(from: date)
        }
        return String(format: "%02d:00", hour)
    }
    
    private var totalCost: Double {
        data.reduce(0) { $0 + $1.cost }
    }
    
    private var hasData: Bool {
        totalCost > 0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Hour header
            Text(formattedHour)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            
            if hasData {
                // Total cost
                Text(totalCost.asCurrency)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                
                // Model breakdown if multiple models
                let nonZeroData = data.filter { $0.cost > 0 }
                if nonZeroData.count > 1 {
                    VStack(spacing: 1) {
                        ForEach(nonZeroData, id: \.id) { item in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForModel(item.model ?? "Unknown"))
                                    .frame(width: 4, height: 4)
                                
                                Text(shortModelName(item.model ?? "Unknown"))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(item.cost.asCurrency)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            } else {
                Text("No usage")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.background.opacity(0.95))
                .stroke(.tertiary, lineWidth: 0.5)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hour \(formattedHour), total cost \(totalCost.asCurrency)")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.15), value: hour)
    }
    
    // Helper methods (duplicated from parent for preview support)
    private func colorForModel(_ model: String) -> Color {
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

// MARK: - Extension for HourlyCostChart Hover Support
extension HourlyCostChart {
    func hourlyDataForHour(_ hour: Int) -> [HourlyChartData] {
        return chartData.filter { $0.hour == hour }
    }
    
    func determineTooltipPosition(for hour: Int) -> AnnotationPosition {
        // Position tooltip to avoid chart edges
        if hour < 6 {
            return .topTrailing  // Early hours: position to the right
        } else if hour > 18 {
            return .topLeading   // Late hours: position to the left
        } else {
            return .top          // Middle hours: position above
        }
    }
}

// MARK: - Previews
struct HourlyTooltipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HourlyTooltipView(hour: 14, cost: 12.50, isCompact: false)
            HourlyTooltipView(hour: 10, cost: 0, isCompact: true)
            
            DetailedHourlyTooltipView(
                data: [
                    HourlyChartData(hour: 14, cost: 8.25, model: "claude-opus-4", project: "TestProject"),
                    HourlyChartData(hour: 14, cost: 4.25, model: "claude-sonnet-4", project: "TestProject")
                ],
                hour: 14
            )
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}