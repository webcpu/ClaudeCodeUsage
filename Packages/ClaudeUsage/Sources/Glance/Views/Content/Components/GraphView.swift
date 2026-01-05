//
//  GraphView.swift
//  Enhanced graph component with area fill and grid
//

import SwiftUI

// MARK: - Constants

private enum Constants {
    static let coordinatePadding: CGFloat = 4
    static let uniformNormalizedValue: Double = 0.5
}

// MARK: - GraphView

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
        .frame(height: GlanceTheme.Layout.graphHeight)
    }
}

// MARK: - Background

private extension GraphView {
    var backgroundView: some View {
        RoundedRectangle(cornerRadius: GlanceTheme.Layout.graphCornerRadius)
            .fill(GlanceTheme.Colors.UI.background)
            .overlay(backgroundBorder)
    }

    var backgroundBorder: some View {
        RoundedRectangle(cornerRadius: GlanceTheme.Layout.graphCornerRadius)
            .stroke(GlanceTheme.Colors.UI.trackBorder, lineWidth: GlanceTheme.Graph.strokeWidth)
    }
}

// MARK: - Chart Content

private extension GraphView {
    @ViewBuilder
    func chartContentView(in geometry: GeometryProxy) -> some View {
        if hasEnoughDataPoints {
            let normalizedData = normalizedDataPoints
            gridLinesView(in: geometry)
            areaFillView(for: normalizedData, in: geometry)
            lineGraphView(for: normalizedData, in: geometry)
            dataDotsView(for: normalizedData, in: geometry)
        }
    }

    var hasEnoughDataPoints: Bool {
        dataPoints.count > 1
    }

    @ViewBuilder
    func dataDotsView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        if showDots {
            dataDots(for: normalizedData, in: geometry)
        }
    }
}

// MARK: - Data Normalization

private extension GraphView {
    var normalizedDataPoints: [Double] {
        guard !dataPoints.isEmpty else { return [] }
        return normalizeToRange(dataPoints, range: dataRange)
    }

    var dataRange: DataRange {
        DataRange(
            minimum: dataPoints.min() ?? 0.0,
            maximum: dataPoints.max() ?? 1.0
        )
    }

    func normalizeToRange(_ points: [Double], range: DataRange) -> [Double] {
        guard range.span > 0 else {
            return uniformNormalizedValues(count: points.count)
        }
        return points.map { range.normalize($0) }
    }

    func uniformNormalizedValues(count: Int) -> [Double] {
        Array(repeating: Constants.uniformNormalizedValue, count: count)
    }
}

// MARK: - Data Range

private struct DataRange {
    let minimum: Double
    let maximum: Double

    var span: Double { maximum - minimum }

    func normalize(_ value: Double) -> Double {
        (value - minimum) / span
    }
}

// MARK: - Coordinate Calculation

private extension GraphView {
    func calculateCoordinates(for normalizedData: [Double], in size: CGSize) -> [CGPoint] {
        guard normalizedData.count > 1 else { return [] }
        let xStep = calculateXStep(for: normalizedData.count, width: size.width)
        return normalizedData.enumerated().map { index, value in
            calculatePoint(at: index, value: value, xStep: xStep, size: size)
        }
    }

    func calculateXStep(for count: Int, width: CGFloat) -> CGFloat {
        width / CGFloat(count - 1)
    }

    func calculatePoint(at index: Int, value: Double, xStep: CGFloat, size: CGSize) -> CGPoint {
        let x = CGFloat(index) * xStep
        let y = calculateY(for: value, height: size.height)
        return CGPoint(x: x, y: y)
    }

    func calculateY(for normalizedValue: Double, height: CGFloat) -> CGFloat {
        let padding = Constants.coordinatePadding
        let availableHeight = height - padding * 2
        return padding + (1.0 - normalizedValue) * availableHeight
    }
}

// MARK: - Grid Lines

private extension GraphView {
    func gridLinesView(in geometry: GeometryProxy) -> some View {
        Path { path in
            gridLineYPositions(in: geometry.size).forEach { y in
                path.addHorizontalLine(at: y, width: geometry.size.width)
            }
        }
        .stroke(GlanceTheme.Colors.UI.gridLines, lineWidth: GlanceTheme.Graph.strokeWidth)
    }

    func gridLineYPositions(in size: CGSize) -> [CGFloat] {
        (1..<GlanceTheme.Layout.gridLineCount).map { index in
            calculateGridLineY(at: index, height: size.height)
        }
    }

    func calculateGridLineY(at index: Int, height: CGFloat) -> CGFloat {
        height * (CGFloat(index) / CGFloat(GlanceTheme.Layout.gridLineCount))
    }
}

// MARK: - Line Graph

private extension GraphView {
    func lineGraphView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        Path { path in
            path.addLineGraph(through: calculateCoordinates(for: normalizedData, in: geometry.size))
        }
        .stroke(color, lineWidth: GlanceTheme.Graph.lineWidth)
    }
}

// MARK: - Area Fill

private extension GraphView {
    func areaFillView(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        Path { path in
            path.addClosedArea(
                through: calculateCoordinates(for: normalizedData, in: geometry.size),
                bottomY: geometry.size.height,
                width: geometry.size.width
            )
        }
        .fill(areaGradient)
    }

    var areaGradient: LinearGradient {
        LinearGradient(
            colors: areaGradientColors,
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var areaGradientColors: [Color] {
        [
            color.opacity(GlanceTheme.Graph.areaGradientTopOpacity),
            color.opacity(GlanceTheme.Graph.areaGradientBottomOpacity)
        ]
    }
}

// MARK: - Data Dots

private extension GraphView {
    func dataDots(for normalizedData: [Double], in geometry: GeometryProxy) -> some View {
        let coordinates = calculateCoordinates(for: normalizedData, in: geometry.size)
        return ForEach(coordinates.indices, id: \.self) { index in
            dataDot(at: coordinates[index])
        }
    }

    func dataDot(at point: CGPoint) -> some View {
        Circle()
            .fill(color)
            .frame(width: GlanceTheme.Layout.dataDotSize, height: GlanceTheme.Layout.dataDotSize)
            .position(point)
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
