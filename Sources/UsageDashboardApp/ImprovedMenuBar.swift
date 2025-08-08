//
//  ImprovedMenuBar.swift
//  Refined professional menu bar UI with better overflow handling
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Improved Progress Bar with Overflow Support
@available(macOS 13.0, *)
struct ImprovedProgressBar: View {
    let value: Double // Can be > 1.0 for overflow
    let segments: [Segment]
    let showOverflow: Bool
    
    struct Segment {
        let range: ClosedRange<Double>
        let color: Color
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                
                // Progress fill
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        let segmentValue = min(max(0, value - segment.range.lowerBound), 
                                              segment.range.upperBound - segment.range.lowerBound)
                        let segmentWidth = (segmentValue / (segment.range.upperBound - segment.range.lowerBound)) * 
                                         (segment.range.upperBound - segment.range.lowerBound) * geometry.size.width
                        
                        if segmentValue > 0 {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [segment.color.opacity(0.8), segment.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: min(segmentWidth, geometry.size.width))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Overflow indicator
                if showOverflow && value > 1.0 {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.red)
                            .offset(x: 2)
                    }
                }
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Enhanced Graph Component
@available(macOS 13.0, *)
struct EnhancedGraphView: View {
    let dataPoints: [Double]
    let color: Color
    let showDots: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                
                if dataPoints.count > 1 {
                    let maxValue = dataPoints.max() ?? 1.0
                    let minValue = dataPoints.min() ?? 0.0
                    let range = max(maxValue - minValue, 0.01)
                    
                    // Grid lines
                    Path { path in
                        for i in 1..<4 {
                            let y = geometry.size.height * (CGFloat(i) / 4.0)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    
                    // Line graph
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        
                        for (index, value) in dataPoints.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedValue = (value - minValue) / range
                            let y = geometry.size.height * (1 - normalizedValue)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, lineWidth: 2)
                    
                    // Area fill
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))
                        
                        for (index, value) in dataPoints.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedValue = (value - minValue) / range
                            let y = geometry.size.height * (1 - normalizedValue)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    
                    // Dots at data points
                    if showDots {
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        ForEach(dataPoints.indices, id: \.self) { index in
                            let value = dataPoints[index]
                            let x = CGFloat(index) * stepX
                            let normalizedValue = (value - minValue) / range
                            let y = geometry.size.height * (1 - normalizedValue)
                            
                            Circle()
                                .fill(color)
                                .frame(width: 4, height: 4)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
        }
        .frame(height: 45) // Larger height for better visibility
    }
}

// MARK: - Metric Row Component
@available(macOS 13.0, *)
struct MetricRow: View {
    let title: String
    let value: String
    let subvalue: String?
    let percentage: Double // Can be > 100
    let segments: [ImprovedProgressBar.Segment]
    let trendData: [Double]?
    let showWarning: Bool
    
    var displayPercentage: String {
        if percentage > 100 {
            return "\(Int(percentage))%"
        }
        return "\(Int(percentage))%"
    }
    
    var percentageColor: Color {
        switch percentage {
        case 0..<60: return .green
        case 60..<80: return .orange
        case 80..<100: return .orange
        default: return .red // Over 100%
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and value
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Text(displayPercentage)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(percentageColor)
                            .monospacedDigit()
                        
                        if showWarning && percentage >= 100 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Graph (if available)
                if let trendData = trendData, trendData.count > 1 {
                    EnhancedGraphView(
                        dataPoints: trendData,
                        color: percentageColor
                    )
                    .frame(width: 100, height: 45)
                    .padding(.trailing, 6)
                }
                
                // Values
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let subvalue = subvalue {
                        Text(subvalue)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            
            // Progress bar
            ImprovedProgressBar(
                value: min(percentage / 100.0, 1.5), // Allow up to 150% visual
                segments: segments,
                showOverflow: percentage > 100
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

// MARK: - Section Header
@available(macOS 13.0, *)
struct ImprovedSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let badge: String?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.8)
            
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Improved Menu Bar Content
@available(macOS 13.0, *)
struct ImprovedMenuBarContentView: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @Environment(\.openWindow) private var openWindow
    @State private var todayHourlyCosts: [Double] = []
    
    var body: some View {
        VStack(spacing: 2) {
            // Live Session Section
            if let session = dataModel.activeSession, session.isActive {
                ImprovedSectionHeader(
                    title: "Live Session",
                    icon: "dot.radiowaves.left.and.right",
                    color: .green,
                    badge: "ACTIVE"
                )
                
                sessionMetrics
                
                Divider()
                    .padding(.vertical, 6)
            }
            
            // Usage Section
            ImprovedSectionHeader(
                title: "Usage",
                icon: "chart.bar.fill",
                color: .blue,
                badge: nil
            )
            
            usageMetrics
            
            Divider()
                .padding(.vertical, 6)
            
            // Cost Section
            ImprovedSectionHeader(
                title: "Cost",
                icon: "dollarsign.circle.fill",
                color: .purple,
                badge: nil
            )
            
            costMetrics
            
            Divider()
                .padding(.vertical, 10)
            
            // Actions
            actionButtons
        }
        .frame(width: 360) // Don't change it
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            updateTodayHourlyCosts()
        }
    }
    
    private var sessionMetrics: some View {
        VStack(spacing: 14) {
            if let session = dataModel.activeSession {
                // Time progress
                MetricRow(
                    title: "Time",
                    value: String(format: "%.1fh / %.0fh",
                                  Date().timeIntervalSince(session.startTime) / 3600,
                                  session.endTime.timeIntervalSince(session.startTime) / 3600),
                    subvalue: nil,
                    percentage: dataModel.sessionTimeProgress * 100,
                    segments: [
                        ImprovedProgressBar.Segment(range: 0...0.7, color: .green),
                        ImprovedProgressBar.Segment(range: 0.7...0.9, color: .orange),
                        ImprovedProgressBar.Segment(range: 0.9...1.5, color: .red)
                    ],
                    trendData: nil,
                    showWarning: false
                )
                
                // Token usage
                if let tokenLimit = dataModel.autoTokenLimit {
                    let tokenPercentage = dataModel.sessionTokenProgress * 100
                    MetricRow(
                        title: "Tokens",
                        value: "\(formatTokenCount(session.tokenCounts.total)) / \(formatTokenCount(tokenLimit))",
                        subvalue: nil,
                        percentage: tokenPercentage,
                        segments: [
                            ImprovedProgressBar.Segment(range: 0...0.6, color: .blue),
                            ImprovedProgressBar.Segment(range: 0.6...0.85, color: .purple),
                            ImprovedProgressBar.Segment(range: 0.85...1.5, color: .red)
                        ],
                        trendData: nil,
                        showWarning: tokenPercentage >= 100
                    )
                }
                
                // Burn rate
                if let burnRate = dataModel.burnRate {
                    HStack {
                        Label("\(formatTokenCount(burnRate.tokensPerMinute)) tokens/min", 
                              systemImage: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Spacer()
                        Text("$\(String(format: "%.2f", burnRate.costPerHour))/hr")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
        }
    }
    
    private var usageMetrics: some View {
        VStack(spacing: 14) {
            if let stats = dataModel.stats {
                MetricRow(
                    title: "Sessions",
                    value: dataModel.todaySessionCount > 0 ? "\(dataModel.todaySessionCount) active" : "No active",
                    subvalue: "Total: \(stats.totalSessions)",
                    percentage: Double(dataModel.estimatedDailySessions) * 5, // Scale for visibility
                    segments: [
                        ImprovedProgressBar.Segment(range: 0...1.0, color: .blue)
                    ],
                    trendData: nil,
                    showWarning: false
                )
            }
        }
    }
    
    private var costMetrics: some View {
        VStack(spacing: 14) {
            // Today's cost with hourly graph
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Text(dataModel.todaysCost)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(todaysCostColor)
                            .monospacedDigit()
                        
                        if dataModel.todaysCostProgress > 1.0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
                
                // Hourly cost graph
                if !todayHourlyCosts.isEmpty {
                    EnhancedGraphView(
                        dataPoints: todayHourlyCosts,
                        color: todaysCostColor
                    )
                    .frame(width: 200, height: 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            
            // Summary stats
            if let stats = dataModel.stats {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(stats.totalCost.asCurrency)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Daily Avg")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", dataModel.averageDailyCost))")
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Dashboard") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            
            Button("Refresh") {
                Task {
                    await dataModel.loadData()
                    updateTodayHourlyCosts()
                }
            }
            .buttonStyle(MenuButtonStyle(style: .primary))
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(MenuButtonStyle(style: .secondary))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }
    
    private func updateTodayHourlyCosts() {
        Task {
            do {
                // Get real usage entries for today
                let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
                let todayEntries = try await client.getTodayUsageEntries()
                
                // Convert to hourly accumulation
                let hourlyData = UsageAnalytics.todayHourlyAccumulation(from: todayEntries)
                
                // Update UI on main thread
                await MainActor.run {
                    self.todayHourlyCosts = hourlyData
                }
            } catch {
                print("Failed to load real hourly costs: \(error)")
                // Fall back to empty array if real data can't be loaded
                await MainActor.run {
                    self.todayHourlyCosts = []
                }
            }
        }
    }
    
    private var todaysCostColor: Color {
        let percentage = dataModel.todaysCostProgress
        switch percentage {
        case 0..<0.6: return .green
        case 0.6..<0.8: return .orange
        case 0.8..<1.0: return .orange
        default: return .red
        }
    }
}

// MARK: - Button Style
@available(macOS 13.0, *)
struct MenuButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    let style: Style
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(style == .primary ? .blue : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(style == .primary ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style == .primary ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Helper function (using existing formatTokenCount from MenuBarApp.swift)
