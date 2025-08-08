//
//  GraphView.swift
//  Enhanced graph component with area fill and grid
//

import SwiftUI

@available(macOS 13.0, *)
struct GraphView: View {
    let dataPoints: [Double]
    let color: Color
    let showDots: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: MenuBarTheme.Layout.graphCornerRadius)
                    .fill(MenuBarTheme.Colors.UI.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: MenuBarTheme.Layout.graphCornerRadius)
                            .stroke(MenuBarTheme.Colors.UI.trackBorder, lineWidth: MenuBarTheme.Graph.strokeWidth)
                    )
                
                if dataPoints.count > 1 {
                    let processedData = ChartDataService.processDataPoints(dataPoints)
                    
                    // Grid lines
                    gridLines(in: geometry)
                    
                    // Area fill
                    areaFill(for: processedData, in: geometry)
                    
                    // Line graph
                    lineGraph(for: processedData, in: geometry)
                    
                    // Data dots (if enabled)
                    if showDots {
                        dataDots(for: processedData, in: geometry)
                    }
                }
            }
        }
        .frame(height: MenuBarTheme.Layout.graphHeight)
    }
    
    // MARK: - Grid Lines
    private func gridLines(in geometry: GeometryProxy) -> some View {
        Path { path in
            for i in 1..<MenuBarTheme.Layout.gridLineCount {
                let y = geometry.size.height * (CGFloat(i) / CGFloat(MenuBarTheme.Layout.gridLineCount))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
            }
        }
        .stroke(MenuBarTheme.Colors.UI.gridLines, lineWidth: MenuBarTheme.Graph.strokeWidth)
    }
    
    // MARK: - Line Graph
    private func lineGraph(for processedData: ProcessedChartData, in geometry: GeometryProxy) -> some View {
        Path { path in
            let coordinates = ChartDataService.calculateChartCoordinates(
                for: processedData,
                in: geometry.size
            )
            
            for (index, point) in coordinates.enumerated() {
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: MenuBarTheme.Graph.lineWidth)
    }
    
    // MARK: - Area Fill
    private func areaFill(for processedData: ProcessedChartData, in geometry: GeometryProxy) -> some View {
        Path { path in
            let coordinates = ChartDataService.calculateChartCoordinates(
                for: processedData,
                in: geometry.size
            )
            
            path.move(to: CGPoint(x: 0, y: geometry.size.height))
            
            for point in coordinates {
                path.addLine(to: point)
            }
            
            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
            path.closeSubpath()
        }
        .fill(LinearGradient(
            colors: [
                color.opacity(MenuBarTheme.Graph.areaGradientTopOpacity),
                color.opacity(MenuBarTheme.Graph.areaGradientBottomOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        ))
    }
    
    // MARK: - Data Dots
    private func dataDots(for processedData: ProcessedChartData, in geometry: GeometryProxy) -> some View {
        let coordinates = ChartDataService.calculateChartCoordinates(
            for: processedData,
            in: geometry.size
        )
        
        return ForEach(coordinates.indices, id: \.self) { index in
            let point = coordinates[index]
            Circle()
                .fill(color)
                .frame(
                    width: MenuBarTheme.Layout.dataDotSize,
                    height: MenuBarTheme.Layout.dataDotSize
                )
                .position(x: point.x, y: point.y)
        }
    }
}