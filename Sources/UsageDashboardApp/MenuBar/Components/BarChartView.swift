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
                // Main chart area
                HStack(alignment: .bottom, spacing: 1) {
                    ForEach(0..<24, id: \.self) { hour in
                        BarView(
                            value: hour < dataPoints.count ? dataPoints[hour] : 0,
                            maxValue: maxValue,
                            height: geometry.size.height - 12, // Leave space for labels
                            isCurrentHour: hour == currentHour,
                            isPastHour: hour <= currentHour,
                            isHovered: hoveredHour == hour
                        )
                        .onHover { isHovered in
                            if isHovered {
                                hoveredHour = hour
                                // Calculate position for tooltip
                                let barWidth = geometry.size.width / 24
                                let xPosition = (CGFloat(hour) + 0.5) * barWidth
                                let yPosition = geometry.size.height - 12 - 
                                    (hour < dataPoints.count ? 
                                     CGFloat(dataPoints[hour] / maxValue) * (geometry.size.height - 12) : 0)
                                hoverLocation = CGPoint(x: xPosition, y: yPosition)
                            } else if hoveredHour == hour {
                                hoveredHour = nil
                            }
                        }
                    }
                }
                .padding(.bottom, 12) // Space for x-axis labels
                
                // Grid overlay
                GridOverlay()
                    .allowsHitTesting(false)
                
                // Axis labels
                AxisLabels(maxValue: maxValue)
                    .allowsHitTesting(false)
                
                // Hover tooltip
                if let hour = hoveredHour {
                    TooltipView(
                        hour: hour,
                        cost: hour < dataPoints.count ? dataPoints[hour] : 0,
                        location: hoverLocation
                    )
                    .allowsHitTesting(false)
                }
            }
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
    
    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 0 }
        let normalizedValue = min(value / maxValue, 1.0)
        return height * CGFloat(normalizedValue)
    }
    
    private var barColor: Color {
        if !isPastHour {
            // Future hour - not reached yet
            return Color.clear
        } else if value == 0 {
            // Past hour with no cost - show as very light gray to indicate it's tracked
            return Color.gray.opacity(0.1)
        } else if value < 1.0 {
            // Low cost - light blue
            return Color(red: 0.4, green: 0.7, blue: 0.95)
        } else if value < 5.0 {
            // Medium cost - cyan/teal
            return Color(red: 0.3, green: 0.75, blue: 0.85)
        } else if value < 10.0 {
            // Higher cost - darker blue
            return Color(red: 0.2, green: 0.5, blue: 0.9)
        } else {
            // High cost - blue with orange tip
            return Color(red: 0.15, green: 0.4, blue: 0.85)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isPastHour && value > 10.0 {
                // Orange cap for high values
                Rectangle()
                    .fill(Color.orange.opacity(0.9))
                    .frame(height: min(barHeight * 0.15, 4))
                    .cornerRadius(0.5, corners: [.topLeft, .topRight])
            }
            
            if isPastHour {
                Rectangle()
                    .fill(barColor)
                    .frame(height: value > 10.0 ? barHeight * 0.85 : max(barHeight, value == 0 ? 2 : 0))
                    .cornerRadius(0.5, corners: value > 10.0 ? [] : [.topLeft, .topRight])
                    .opacity(isHovered ? 1.0 : (isCurrentHour ? 1.0 : 0.85))
                    .scaleEffect(isHovered ? 1.05 : 1.0)
            } else {
                // Future hour - empty space
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: value)
    }
}

// MARK: - Grid Overlay
private struct GridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Horizontal grid lines
                VStack(spacing: 0) {
                    Spacer()
                    
                    // 75% line
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 0.5)
                    
                    Spacer()
                    
                    // 50% line
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 0.5)
                    
                    Spacer()
                    
                    // 25% line
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 0.5)
                    
                    Spacer()
                }
                .padding(.bottom, 12)
                
                // Baseline
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5)
                        .padding(.bottom, 12)
                }
            }
        }
    }
}

// MARK: - Axis Labels
private struct AxisLabels: View {
    let maxValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // X-axis labels (hours) - show labels at 0, 6, 12, 18
                let barWidth = geometry.size.width / 24
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(String(format: "%02d", hour))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                        .position(
                            x: CGFloat(hour) * barWidth + barWidth / 2,
                            y: geometry.size.height - 6
                        )
                }
                
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatValue(maxValue))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatValue(maxValue / 2))
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("0")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .frame(height: geometry.size.height - 12)
                .offset(x: -geometry.size.width - 15, y: -6)
            }
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if value == 0 {
            return "0"
        } else if value < 1 {
            return String(format: "%.1f", value)
        } else if value < 10 {
            return String(format: "%.0f", value)
        } else if value < 100 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.0f", value)
        }
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
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        
        // Top right corner
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight,
                       startAngle: .degrees(-90),
                       endAngle: .degrees(0),
                       clockwise: false)
        }
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        
        // Bottom right corner
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight,
                       startAngle: .degrees(0),
                       endAngle: .degrees(90),
                       clockwise: false)
        }
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        
        // Bottom left corner
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft,
                       startAngle: .degrees(90),
                       endAngle: .degrees(180),
                       clockwise: false)
        }
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        
        // Top left corner
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft,
                       startAngle: .degrees(180),
                       endAngle: .degrees(270),
                       clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Tooltip View
private struct TooltipView: View {
    let hour: Int
    let cost: Double
    let location: CGPoint
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(String(format: "%02d", hour)):00")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(cost > 0 ? String(format: "$%.2f", cost) : "$0.00")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .position(x: location.x, y: max(location.y - 20, 15))
        .animation(.easeInOut(duration: 0.1), value: location)
    }
}