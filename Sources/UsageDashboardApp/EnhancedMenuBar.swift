//
//  EnhancedMenuBar.swift
//  Professional menu bar UI components
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Section Header Component
@available(macOS 13.0, *)
struct SectionHeaderView: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .kerning(0.5)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Enhanced Progress Bar with Gradients
@available(macOS 13.0, *)
struct SystemProgressBar: View {
    let segments: [ProgressSegment]
    let height: CGFloat = 8
    let width: CGFloat = 140
    
    struct ProgressSegment {
        let value: Double
        let color: Color
        let gradient: LinearGradient
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height/2)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: height)
                
                // Progress segments
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { index in
                        let segment = segments[index]
                        let segmentWidth = geometry.size.width * segment.value
                        
                        if segment.value > 0 {
                            RoundedRectangle(cornerRadius: height/2)
                                .fill(segment.gradient)
                                .frame(width: segmentWidth, height: height)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: height/2))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Mini Graph Component
@available(macOS 13.0, *)
struct MiniGraphView: View {
    let dataPoints: [Double]
    let color: Color
    let height: CGFloat = 24
    let width: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.05))
                
                // Graph
                if dataPoints.count > 1 {
                    let maxValue = dataPoints.max() ?? 1.0
                    let minValue = dataPoints.min() ?? 0.0
                    let range = max(maxValue - minValue, 0.01)
                    
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
                    .stroke(color, lineWidth: 1.5)
                    
                    // Fill area under curve
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        
                        for (index, value) in dataPoints.enumerated() {
                            let x = CGFloat(index) * stepX
                            let normalizedValue = (value - minValue) / range
                            let y = geometry.size.height * (1 - normalizedValue)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        if !dataPoints.isEmpty {
                            let x = geometry.size.width
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.1))
                }
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(4)
    }
}

// MARK: - System Monitor Row Component
@available(macOS 13.0, *)
struct SystemMonitorRow: View {
    let title: String
    let value: String
    let percentage: Int
    let segments: [SystemProgressBar.ProgressSegment]
    let trendData: [Double]?
    let showGraph: Bool
    
    init(title: String, value: String, percentage: Int, segments: [SystemProgressBar.ProgressSegment], trendData: [Double]? = nil, showGraph: Bool = false) {
        self.title = title
        self.value = value
        self.percentage = percentage
        self.segments = segments
        self.trendData = trendData
        self.showGraph = showGraph
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Title and percentage
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                
                Text("\(percentage)%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(progressColor)
                    .monospacedDigit()
            }
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // Mini graph (if available and requested)
            if showGraph, let trendData = trendData {
                MiniGraphView(
                    dataPoints: trendData,
                    color: progressColor
                )
            }
            
            // Progress bar and value
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                SystemProgressBar(segments: segments)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private var progressColor: Color {
        switch Double(percentage) / 100.0 {
        case 0..<0.6: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

// MARK: - System Button Style
@available(macOS 13.0, *)
struct SystemButtonStyle: ButtonStyle {
    enum Style {
        case primary, secondary
    }
    
    let style: Style
    
    init(style: Style = .primary) {
        self.style = style
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(style == .primary ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .foregroundColor(style == .primary ? .blue : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Menu Bar Content View
@available(macOS 13.0, *)
struct EnhancedMenuBarContentView: View {
    @EnvironmentObject var dataModel: UsageDataModel
    @Environment(\.openWindow) private var openWindow
    
    // Store cost history for trend graph
    @State private var costHistory: [Double] = []
    @State private var sessionHistory: [Double] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // LIVE SESSION Section
            if let session = dataModel.activeSession, session.isActive {
                SectionHeaderView(
                    title: "Live Session",
                    icon: "dot.radiowaves.left.and.right",
                    color: .green
                )
                
                liveSessionContent
                
                customDivider
            }
            
            // USAGE Section
            SectionHeaderView(
                title: "Usage",
                icon: "chart.bar.fill",
                color: .blue
            )
            
            usageContent
            
            customDivider
            
            // COST Section
            SectionHeaderView(
                title: "Cost",
                icon: "dollarsign.circle.fill",
                color: .purple
            )
            
            costContent
            
            customDivider
            
            // Actions
            actionButtons
        }
        .padding(.vertical, 8)
        .frame(width: 320)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            updateCostHistory()
        }
    }
    
    private var customDivider: some View {
        Divider()
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
    }
    
    private var liveSessionContent: some View {
        VStack(spacing: 8) {
            if let session = dataModel.activeSession {
                // Session time
                SystemMonitorRow(
                    title: "Time",
                    value: String(format: "%.1fh / %.0fh", 
                                  Date().timeIntervalSince(session.startTime) / 3600,
                                  session.endTime.timeIntervalSince(session.startTime) / 3600),
                    percentage: Int(dataModel.sessionTimeProgress * 100),
                    segments: createTimeProgressSegments()
                )
                
                // Token usage
                if let tokenLimit = dataModel.autoTokenLimit {
                    SystemMonitorRow(
                        title: "Tokens",
                        value: "\(formatTokenCount(session.tokenCounts.total)) / \(formatTokenCount(tokenLimit))",
                        percentage: Int(dataModel.sessionTokenProgress * 100),
                        segments: createTokenProgressSegments()
                    )
                }
                
                // Burn rate indicator
                if let burnRate = dataModel.burnRate {
                    HStack {
                        Label("\(burnRate.tokensPerMinute) tokens/min", systemImage: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("$\(String(format: "%.2f", burnRate.costPerHour))/hr")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
    }
    
    private var usageContent: some View {
        VStack(spacing: 8) {
            if let stats = dataModel.stats {
                // Sessions today
                SystemMonitorRow(
                    title: "Sessions",
                    value: "\(dataModel.todaySessionCount) today",
                    percentage: min(Int((Double(dataModel.todaySessionCount) / 20.0) * 100), 100),
                    segments: [
                        SystemProgressBar.ProgressSegment(
                            value: min(Double(dataModel.todaySessionCount) / 20.0, 1.0),
                            color: .blue,
                            gradient: LinearGradient(
                                colors: [.blue.opacity(0.7), .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    ],
                    trendData: sessionHistory,
                    showGraph: sessionHistory.count > 1
                )
                
                // Total sessions
                HStack {
                    Text("Total:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(stats.totalSessions) sessions")
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private var costContent: some View {
        VStack(spacing: 8) {
            // Today's cost with trend
            SystemMonitorRow(
                title: "Today",
                value: "\(dataModel.todaysCost) / $\(String(format: "%.0f", dataModel.dailyCostThreshold))",
                percentage: Int(dataModel.todaysCostProgress * 100),
                segments: createCostProgressSegments(),
                trendData: costHistory,
                showGraph: costHistory.count > 1
            )
            
            // Additional stats
            if let stats = dataModel.stats {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(stats.totalCost.asCurrency)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Average")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", dataModel.averageDailyCost))/day")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button("Dashboard") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(SystemButtonStyle())
                
                Button("Refresh") {
                    Task { 
                        await dataModel.loadData()
                        updateCostHistory()
                    }
                }
                .buttonStyle(SystemButtonStyle())
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(SystemButtonStyle(style: .secondary))
            }
        }
        .padding(.horizontal, 12)
    }
    
    // MARK: - Progress Segment Creators
    
    private func createTimeProgressSegments() -> [SystemProgressBar.ProgressSegment] {
        let progress = dataModel.sessionTimeProgress
        
        if progress < 0.7 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: progress,
                    color: .green,
                    gradient: LinearGradient(
                        colors: [.green.opacity(0.7), .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else if progress < 0.9 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.7,
                    color: .green,
                    gradient: LinearGradient(
                        colors: [.green.opacity(0.7), .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.7,
                    color: .orange,
                    gradient: LinearGradient(
                        colors: [.orange.opacity(0.7), .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.7,
                    color: .green,
                    gradient: LinearGradient(
                        colors: [.green.opacity(0.7), .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: 0.2,
                    color: .orange,
                    gradient: LinearGradient(
                        colors: [.orange.opacity(0.7), .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.9,
                    color: .red,
                    gradient: LinearGradient(
                        colors: [.red.opacity(0.7), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        }
    }
    
    private func createTokenProgressSegments() -> [SystemProgressBar.ProgressSegment] {
        let progress = dataModel.sessionTokenProgress
        
        if progress < 0.6 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: progress,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.7), .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else if progress < 0.85 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.6,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.7), .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.6,
                    color: .purple,
                    gradient: LinearGradient(
                        colors: [.purple.opacity(0.7), .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.6,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.7), .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: 0.25,
                    color: .purple,
                    gradient: LinearGradient(
                        colors: [.purple.opacity(0.7), .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.85,
                    color: .red,
                    gradient: LinearGradient(
                        colors: [.red.opacity(0.7), .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        }
    }
    
    private func createCostProgressSegments() -> [SystemProgressBar.ProgressSegment] {
        let progress = dataModel.todaysCostProgress
        
        if progress < 0.5 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: progress,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else if progress < 0.8 {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.5,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.5,
                    color: .purple,
                    gradient: LinearGradient(
                        colors: [.purple.opacity(0.6), .purple.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        } else {
            return [
                SystemProgressBar.ProgressSegment(
                    value: 0.5,
                    color: .blue,
                    gradient: LinearGradient(
                        colors: [.blue.opacity(0.6), .blue.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: 0.3,
                    color: .purple,
                    gradient: LinearGradient(
                        colors: [.purple.opacity(0.6), .purple.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ),
                SystemProgressBar.ProgressSegment(
                    value: progress - 0.8,
                    color: .red,
                    gradient: LinearGradient(
                        colors: [.red.opacity(0.6), .red.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            ]
        }
    }
    
    private func updateCostHistory() {
        // Simulate cost history (in production, you'd fetch real data)
        if let stats = dataModel.stats {
            // Take last 7 days of costs
            let recentCosts = stats.byDate.suffix(7).map { $0.totalCost }
            costHistory = recentCosts
            
            // Create session count history
            sessionHistory = stats.byDate.suffix(7).map { daily in
                // Estimate sessions per day (simplified)
                Double(max(1, stats.totalSessions / max(1, stats.byDate.count)))
            }
        }
    }
}

