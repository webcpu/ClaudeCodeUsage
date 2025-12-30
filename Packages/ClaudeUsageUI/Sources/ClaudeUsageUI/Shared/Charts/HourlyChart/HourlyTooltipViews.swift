//
//  HourlyTooltipViews.swift
//  Tooltip views for hourly cost charts
//

import SwiftUI

// MARK: - Simple Tooltip View

struct HourlyTooltipView: View {
    let hour: Int
    let cost: Double
    let isCompact: Bool

    private var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? "HH:mm" : "h:mm a"

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
                .fill(.regularMaterial)
                .stroke(.tertiary, lineWidth: 0.5)
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hour \(formattedHour), cost \(formattedCost)")
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.15), value: hour)
    }
}

// MARK: - Previews

struct HourlyTooltipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HourlyTooltipView(hour: 14, cost: 12.50, isCompact: false)
            HourlyTooltipView(hour: 10, cost: 0, isCompact: true)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}
