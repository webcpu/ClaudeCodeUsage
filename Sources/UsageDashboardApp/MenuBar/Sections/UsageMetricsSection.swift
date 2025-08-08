//
//  UsageMetricsSection.swift
//  Usage metrics section component
//

import SwiftUI
import ClaudeCodeUsage

struct UsageMetricsSection: View {
    @Environment(UsageDataModel.self) private var dataModel
    
    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if let stats = dataModel.stats {
                MetricRow(
                    title: "Sessions",
                    value: FormatterService.formatSessionCount(dataModel.todaySessionCount),
                    subvalue: "Total: \(stats.totalSessions)",
                    percentage: Double(dataModel.estimatedDailySessions) * 5, // Scale for visibility
                    segments: ColorService.singleColorSegment(color: MenuBarTheme.Colors.Sections.usage),
                    trendData: nil,
                    showWarning: false
                )
            }
        }
    }
}