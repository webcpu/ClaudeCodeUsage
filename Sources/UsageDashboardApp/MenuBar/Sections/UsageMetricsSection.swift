//
//  UsageMetricsSection.swift
//  Usage metrics section component
//

import SwiftUI
import ClaudeCodeUsage

@available(macOS 13.0, *)
struct UsageMetricsSection: View {
    @EnvironmentObject var dataModel: UsageDataModel
    
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