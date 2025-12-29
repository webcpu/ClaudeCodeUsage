//
//  BarChartView.swift
//  Bar chart component for hourly cost visualization
//
//  Split into extensions for focused responsibilities:
//    - +BarView: Individual bar component and cost levels
//    - +Grid: Grid overlay and axis labels
//    - +Tooltip: Tooltip view and corner radius utilities
//

import SwiftUI

// MARK: - Bar Chart View

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
