//
//  BarChartView+BarView.swift
//
//  Individual bar component and cost level coloring.
//

import SwiftUI

// MARK: - Individual Bar View

struct BarView: View {
    let value: Double
    let maxValue: Double
    let height: CGFloat
    let isCurrentHour: Bool
    let isPastHour: Bool
    let isHovered: Bool

    private enum Threshold {
        static let highCost: Double = 10.0
    }

    private enum Layout {
        static let capHeightRatio: CGFloat = 0.15
        static let capMaxHeight: CGFloat = 4
        static let mainBarRatio: CGFloat = 0.85
        static let cornerRadius: CGFloat = 0.5
        static let zeroBarHeight: CGFloat = 2
        static let hoverScale: CGFloat = 1.05
    }

    private enum Opacity {
        static let orangeCap: Double = 0.9
        static let activeBar: Double = 1.0
        static let inactiveBar: Double = 0.85
    }

    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        let normalizedValue = min(value / maxValue, 1.0)
        return height * CGFloat(normalizedValue)
    }

    private var barColor: Color {
        CostLevel.from(value: value, isPastHour: isPastHour).color
    }

    private var isHighCost: Bool {
        value > Threshold.highCost
    }

    private var barOpacity: Double {
        (isHovered || isCurrentHour) ? Opacity.activeBar : Opacity.inactiveBar
    }

    private var barScale: CGFloat {
        isHovered ? Layout.hoverScale : 1.0
    }

    private var mainBarHeight: CGFloat {
        isHighCost ? barHeight * Layout.mainBarRatio : max(barHeight, value == 0 ? Layout.zeroBarHeight : 0)
    }

    private var mainBarCorners: Set<Corner> {
        isHighCost ? [] : [.topLeft, .topRight]
    }

    var body: some View {
        VStack(spacing: 0) {
            orangeCapView
            barContent
        }
        .animation(.easeInOut(duration: 0.3), value: value)
    }

    @ViewBuilder
    private var orangeCapView: some View {
        if isPastHour && isHighCost {
            Rectangle()
                .fill(Color.orange.opacity(Opacity.orangeCap))
                .frame(height: min(barHeight * Layout.capHeightRatio, Layout.capMaxHeight))
                .cornerRadius(Layout.cornerRadius, corners: [.topLeft, .topRight])
        }
    }

    @ViewBuilder
    private var barContent: some View {
        if isPastHour {
            pastHourBar
        } else {
            futureHourBar
        }
    }

    private var pastHourBar: some View {
        Rectangle()
            .fill(barColor)
            .frame(height: mainBarHeight)
            .cornerRadius(Layout.cornerRadius, corners: mainBarCorners)
            .opacity(barOpacity)
            .scaleEffect(barScale)
    }

    private var futureHourBar: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 0)
    }
}

// MARK: - Cost Level

enum CostLevel {
    case future
    case zero
    case low
    case medium
    case high
    case veryHigh

    static func from(value: Double, isPastHour: Bool) -> CostLevel {
        guard isPastHour else { return .future }
        guard value > 0 else { return .zero }
        if value < 1.0 { return .low }
        if value < 5.0 { return .medium }
        if value < 10.0 { return .high }
        return .veryHigh
    }

    var color: Color {
        switch self {
        case .future: Color.clear
        case .zero: Color.gray.opacity(0.1)
        case .low: Color(red: 0.4, green: 0.7, blue: 0.95)
        case .medium: Color(red: 0.3, green: 0.75, blue: 0.85)
        case .high: Color(red: 0.2, green: 0.5, blue: 0.9)
        case .veryHigh: Color(red: 0.15, green: 0.4, blue: 0.85)
        }
    }
}
