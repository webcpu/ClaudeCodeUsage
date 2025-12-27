//
//  BarChartView.swift
//  Bar chart component for hourly cost visualization
//

import SwiftUI

struct BarChartView: View {
    let dataPoints: [Double]
    @State private var hoveredHour: Int? = nil
    @State private var hoverLocation: CGPoint = .zero
    
    private var maxValue: Double {
        dataPoints.max() ?? 1.0
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                chartBars(in: geometry)
                gridOverlay
                axisLabels
                tooltipOverlay
            }
        }
    }

    private func chartBars(in geometry: GeometryProxy) -> some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<24, id: \.self) { hour in
                barView(for: hour, in: geometry)
            }
        }
        .padding(.bottom, 12)
    }

    private func barView(for hour: Int, in geometry: GeometryProxy) -> some View {
        BarView(
            value: valueForHour(hour),
            maxValue: maxValue,
            height: geometry.size.height - 12,
            isCurrentHour: hour == currentHour,
            isPastHour: hour <= currentHour,
            isHovered: hoveredHour == hour
        )
        .onHover { isHovered in
            handleHover(isHovered: isHovered, hour: hour, geometry: geometry)
        }
    }

    private func valueForHour(_ hour: Int) -> Double {
        hour < dataPoints.count ? dataPoints[hour] : 0
    }

    private func handleHover(isHovered: Bool, hour: Int, geometry: GeometryProxy) {
        if isHovered {
            hoveredHour = hour
            hoverLocation = tooltipPosition(for: hour, in: geometry)
        } else if hoveredHour == hour {
            hoveredHour = nil
        }
    }

    private func tooltipPosition(for hour: Int, in geometry: GeometryProxy) -> CGPoint {
        let barWidth = geometry.size.width / 24
        let chartHeight = geometry.size.height - 12
        let xPosition = (CGFloat(hour) + 0.5) * barWidth
        let yPosition = chartHeight - CGFloat(valueForHour(hour) / maxValue) * chartHeight
        return CGPoint(x: xPosition, y: yPosition)
    }

    private var gridOverlay: some View {
        GridOverlay()
            .allowsHitTesting(false)
    }

    private var axisLabels: some View {
        AxisLabels(maxValue: maxValue)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var tooltipOverlay: some View {
        if let hour = hoveredHour {
            TooltipView(
                hour: hour,
                cost: valueForHour(hour),
                location: hoverLocation
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Individual Bar View
private struct BarView: View {
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

private enum CostLevel {
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

// MARK: - Grid Overlay
private struct GridOverlay: View {
    private enum Opacity {
        static let quarterLine: Double = 0.1
        static let halfLine: Double = 0.15
        static let baseline: Double = 0.3
    }

    private enum Layout {
        static let lineHeight: CGFloat = 0.5
        static let bottomPadding: CGFloat = 12
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                horizontalGridLines
                baseline
            }
        }
    }

    private var horizontalGridLines: some View {
        VStack(spacing: 0) {
            Spacer()
            quarterGridLine
            Spacer()
            halfGridLine
            Spacer()
            quarterGridLine
            Spacer()
        }
        .padding(.bottom, Layout.bottomPadding)
    }

    private var quarterGridLine: some View {
        gridLine(opacity: Opacity.quarterLine)
    }

    private var halfGridLine: some View {
        gridLine(opacity: Opacity.halfLine)
    }

    private func gridLine(opacity: Double) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(opacity))
            .frame(height: Layout.lineHeight)
    }

    private var baseline: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.gray.opacity(Opacity.baseline))
                .frame(height: Layout.lineHeight)
                .padding(.bottom, Layout.bottomPadding)
        }
    }
}

// MARK: - Axis Labels
private struct AxisLabels: View {
    let maxValue: Double
    private static let displayedHours = [0, 6, 12, 18]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                hourLabels(in: geometry)
            }
        }
    }

    private func hourLabels(in geometry: GeometryProxy) -> some View {
        let barWidth = geometry.size.width / 24
        return ForEach(Self.displayedHours, id: \.self) { hour in
            hourLabel(hour: hour, barWidth: barWidth, containerHeight: geometry.size.height)
        }
    }

    private func hourLabel(hour: Int, barWidth: CGFloat, containerHeight: CGFloat) -> some View {
        Text(String(format: "%02d", hour))
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .foregroundColor(.gray)
            .position(
                x: CGFloat(hour) * barWidth + barWidth / 2,
                y: containerHeight - 6
            )
    }
}

// MARK: - Corner Radius Extension
private extension View {
    func cornerRadius(_ radius: CGFloat, corners: Set<Corner>) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private enum Corner {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: Set<Corner> = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    func path(in rect: CGRect) -> Path {
        let radii = cornerRadii
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY))
        addTopEdge(to: &path, in: rect, radii: radii)
        addTopRightCorner(to: &path, in: rect, radii: radii)
        addRightEdge(to: &path, in: rect, radii: radii)
        addBottomRightCorner(to: &path, in: rect, radii: radii)
        addBottomEdge(to: &path, in: rect, radii: radii)
        addBottomLeftCorner(to: &path, in: rect, radii: radii)
        addLeftEdge(to: &path, in: rect, radii: radii)
        addTopLeftCorner(to: &path, in: rect, radii: radii)
        path.closeSubpath()
        return path
    }

    private var cornerRadii: CornerRadii {
        CornerRadii(
            topLeft: corners.contains(.topLeft) ? radius : 0,
            topRight: corners.contains(.topRight) ? radius : 0,
            bottomLeft: corners.contains(.bottomLeft) ? radius : 0,
            bottomRight: corners.contains(.bottomRight) ? radius : 0
        )
    }

    private func addTopEdge(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        path.addLine(to: CGPoint(x: rect.maxX - radii.topRight, y: rect.minY))
    }

    private func addTopRightCorner(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        guard radii.topRight > 0 else { return }
        path.addArc(
            center: CGPoint(x: rect.maxX - radii.topRight, y: rect.minY + radii.topRight),
            radius: radii.topRight,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
    }

    private func addRightEdge(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radii.bottomRight))
    }

    private func addBottomRightCorner(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        guard radii.bottomRight > 0 else { return }
        path.addArc(
            center: CGPoint(x: rect.maxX - radii.bottomRight, y: rect.maxY - radii.bottomRight),
            radius: radii.bottomRight,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
    }

    private func addBottomEdge(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        path.addLine(to: CGPoint(x: rect.minX + radii.bottomLeft, y: rect.maxY))
    }

    private func addBottomLeftCorner(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        guard radii.bottomLeft > 0 else { return }
        path.addArc(
            center: CGPoint(x: rect.minX + radii.bottomLeft, y: rect.maxY - radii.bottomLeft),
            radius: radii.bottomLeft,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
    }

    private func addLeftEdge(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radii.topLeft))
    }

    private func addTopLeftCorner(to path: inout Path, in rect: CGRect, radii: CornerRadii) {
        guard radii.topLeft > 0 else { return }
        path.addArc(
            center: CGPoint(x: rect.minX + radii.topLeft, y: rect.minY + radii.topLeft),
            radius: radii.topLeft,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
    }
}

private struct CornerRadii {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat
}

// MARK: - Tooltip View
private struct TooltipView: View {
    let hour: Int
    let cost: Double
    let location: CGPoint

    var body: some View {
        tooltipContent
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(tooltipBackground)
            .overlay(tooltipBorder)
            .position(x: location.x, y: max(location.y - 20, 15))
            .animation(.easeInOut(duration: 0.1), value: location)
    }

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            timeLabel
            costLabel
        }
    }

    private var timeLabel: some View {
        Text("\(String(format: "%02d", hour)):00")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
    }

    private var costLabel: some View {
        Text(cost > 0 ? String(format: "$%.2f", cost) : "$0.00")
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.9))
    }

    private var tooltipBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.black.opacity(0.85))
    }

    private var tooltipBorder: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
    }
}