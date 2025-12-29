//
//  BarChartView+Grid.swift
//
//  Grid overlay and axis labels for bar chart.
//

import SwiftUI

// MARK: - Grid Overlay

struct GridOverlay: View {
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

struct AxisLabels: View {
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
