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

    var body: some View {
        VStack(spacing: Layout.labelSpacing) {
            hourLabel
            costLabel
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(tooltipBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .transition(.scale(scale: Animation.scaleAmount).combined(with: .opacity))
        .animation(.easeInOut(duration: Animation.duration), value: hour)
    }
}

// MARK: - Layout Constants

private extension HourlyTooltipView {
    enum Layout {
        static let labelSpacing: CGFloat = 2
        static let horizontalPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 4
        static let cornerRadius: CGFloat = 4
        static let borderWidth: CGFloat = 0.5
        static let shadowOpacity: Double = 0.15
        static let shadowRadius: CGFloat = 3
        static let shadowY: CGFloat = 1
    }

    enum FontSize {
        static let hourCompact: CGFloat = 9
        static let hourRegular: CGFloat = 10
        static let costCompact: CGFloat = 8
        static let costRegular: CGFloat = 9
    }

    enum Animation {
        static let duration: Double = 0.15
        static let scaleAmount: CGFloat = 0.8
    }

    enum DateFormat {
        static let compact = "HH:mm"
        static let regular = "h:mm a"
        static let fallback = "%02d:00"
    }
}

// MARK: - View Components

private extension HourlyTooltipView {
    var hourLabel: some View {
        Text(formattedHour)
            .font(.system(size: hourFontSize, weight: .semibold, design: .monospaced))
            .foregroundColor(.primary)
    }

    var costLabel: some View {
        Text(formattedCost)
            .font(.system(size: costFontSize, weight: .medium, design: .monospaced))
            .foregroundColor(costColor)
    }

    var tooltipBackground: some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(.regularMaterial)
            .stroke(.tertiary, lineWidth: Layout.borderWidth)
            .shadow(
                color: .black.opacity(Layout.shadowOpacity),
                radius: Layout.shadowRadius,
                x: 0,
                y: Layout.shadowY
            )
    }
}

// MARK: - Computed Properties

private extension HourlyTooltipView {
    var hourFontSize: CGFloat {
        isCompact ? FontSize.hourCompact : FontSize.hourRegular
    }

    var costFontSize: CGFloat {
        isCompact ? FontSize.costCompact : FontSize.costRegular
    }

    var costColor: Color {
        cost > 0 ? .blue : .secondary
    }

    var accessibilityDescription: String {
        "Hour \(formattedHour), cost \(formattedCost)"
    }
}

// MARK: - Formatting

private extension HourlyTooltipView {
    var formattedHour: String {
        dateForHour.map(formatDate) ?? fallbackHourString
    }

    var formattedCost: String {
        cost == 0 ? "$0.00" : cost.asCurrency
    }

    var dateForHour: Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = isCompact ? DateFormat.compact : DateFormat.regular
        return formatter.string(from: date)
    }

    var fallbackHourString: String {
        String(format: DateFormat.fallback, hour)
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
