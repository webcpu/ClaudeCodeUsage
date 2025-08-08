//
//  SessionMetricsSection.swift
//  Live session metrics section component
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

struct SessionMetricsSection: View {
    @Environment(UsageDataModel.self) private var dataModel
    
    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if let session = dataModel.activeSession {
                // Time progress only
                MetricRow(
                    title: "Time",
                    value: FormatterService.formatTimeInterval(
                        Date().timeIntervalSince(session.startTime),
                        totalInterval: session.endTime.timeIntervalSince(session.startTime)
                    ),
                    subvalue: nil,
                    percentage: dataModel.sessionTimeProgress * 100,
                    segments: ColorService.sessionTimeSegments(),
                    trendData: nil,
                    showWarning: false
                )
            }
        }
    }
}
