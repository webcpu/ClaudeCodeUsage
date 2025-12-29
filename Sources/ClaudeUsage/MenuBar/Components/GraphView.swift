//
//  GraphView.swift
//  Enhanced graph component with area fill and grid
//

import SwiftUI

struct GraphView: View {
    let dataPoints: [Double]
    let color: Color
    let showDots: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                chartContentView(in: geometry)
            }
        }
        .frame(height: MenuBarTheme.Layout.graphHeight)
    }

    // MARK: - Background

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: MenuBarTheme.Layout.graphCornerRadius)
            .fill(MenuBarTheme.Colors.UI.background)
            .overlay(backgroundBorder)
    }

    private var backgroundBorder: some View {
        RoundedRectangle(cornerRadius: MenuBarTheme.Layout.graphCornerRadius)
            .stroke(MenuBarTheme.Colors.UI.trackBorder, lineWidth: MenuBarTheme.Graph.strokeWidth)
    }

    // MARK: - Chart Content

    @ViewBuilder
    private func chartContentView(in geometry: GeometryProxy) -> some View {
        if hasEnoughDataPoints {
            let normalizedData = normalizeDataPoints(dataPoints)
            gridLinesView(in: geometry)
            areaFillView(for: normalizedData, in: geometry)
            lineGraphView(for: normalizedData, in: geometry)
            dataDotsView(for: normalizedData, in: geometry)
        }
    }

    private var hasEnoughDataPoints: Bool {
        dataPoints.count > 1
    }

    @ViewBuilder
    private func dataDotsView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        if showDots {
            dataDots(for: normalizedData, in: geometry)
        }
    }

    // MARK: - Data Processing

    private func normalizeDataPoints(_ points: [Double]) -> [Double] {
        guard !points.isEmpty else { return [] }

        let maxValue = points.max() ?? 1.0
        let minValue = points.min() ?? 0.0
        let range = maxValue - minValue

        guard range != 0 else {
            return Array(repeating: 0.5, count: points.count)
        }

        return points.map { ($0 - minValue) / range }
    }

    private func calculateCoordinates(for normalizedData: [Double], in size: CGSize) -> [CGPoint] {
        guard normalizedData.count > 1 else { return [] }

        let xStep = size.width / CGFloat(normalizedData.count - 1)
        let padding: CGFloat = 4

        return normalizedData.enumerated().map { index, value in
            let x = CGFloat(index) * xStep
            let y = padding + (1.0 - CGFloat(value)) * (size.height - padding * 2)
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Grid Lines

    private func gridLinesView(in geometry: GeometryProxy) -> some View {
        Path { path in
            gridLineYPositions(in: geometry.size).forEach { y in
                path.addHorizontalLine(at: y, width: geometry.size.width)
            }
        }
        .stroke(MenuBarTheme.Colors.UI.gridLines, lineWidth: MenuBarTheme.Graph.strokeWidth)
    }

    private func gridLineYPositions(in size: CGSize) -> [CGFloat] {
        (1..<MenuBarTheme.Layout.gridLineCount).map { index in
            size.height * (CGFloat(index) / CGFloat(MenuBarTheme.Layout.gridLineCount))
        }
    }

    // MARK: - Line Graph

    private func lineGraphView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        Path { path in
            path.addLineGraph(through: calculateCoordinates(for: normalizedData, in: geometry.size))
        }
        .stroke(color, lineWidth: MenuBarTheme.Graph.lineWidth)
    }

    // MARK: - Area Fill

    private func areaFillView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        Path { path in
            path.addClosedArea(
                through: calculateCoordinates(for: normalizedData, in: geometry.size),
                bottomY: geometry.size.height,
                width: geometry.size.width
            )
        }
        .fill(areaGradient)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                color.opacity(MenuBarTheme.Graph.areaGradientTopOpacity),
                color.opacity(MenuBarTheme.Graph.areaGradientBottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Data Dots

    private func dataDots(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        let coordinates = calculateCoordinates(for: normalizedData, in: geometry.size)

        return ForEach(coordinates.indices, id: \.self) { index in
            dataDot(at: coordinates[index])
        }
    }

    private func dataDot(at point: CGPoint) -> some View {
        Circle()
            .fill(color)
            .frame(
                width: MenuBarTheme.Layout.dataDotSize,
                height: MenuBarTheme.Layout.dataDotSize
            )
            .position(x: point.x, y: point.y)
    }
}

// MARK: - Path Extensions

private extension Path {
    mutating func addHorizontalLine(at y: CGFloat, width: CGFloat) {
        move(to: CGPoint(x: 0, y: y))
        addLine(to: CGPoint(x: width, y: y))
    }

    mutating func addLineGraph(through points: [CGPoint]) {
        guard let first = points.first else { return }
        move(to: first)
        points.dropFirst().forEach { addLine(to: $0) }
    }

    mutating func addClosedArea(through points: [CGPoint], bottomY: CGFloat, width: CGFloat) {
        move(to: CGPoint(x: 0, y: bottomY))
        points.forEach { addLine(to: $0) }
        addLine(to: CGPoint(x: width, y: bottomY))
        closeSubpath()
    }
}
