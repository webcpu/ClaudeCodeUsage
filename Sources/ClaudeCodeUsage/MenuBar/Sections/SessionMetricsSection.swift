//
//  SessionMetricsSection.swift
//  Live session metrics section component
//

import SwiftUI
import ClaudeCodeUsageKit
import ClaudeLiveMonitorLib

struct SessionMetricsSection: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if let session = store.activeSession {
                // Time progress only
                MetricRow(
                    title: "Time",
                    value: FormatterService.formatTimeInterval(
                        Date().timeIntervalSince(session.startTime),
                        totalInterval: session.endTime.timeIntervalSince(session.startTime)
                    ),
                    subvalue: nil,
                    percentage: store.sessionTimeProgress * 100,
                    segments: ColorService.sessionTimeSegments(),
                    trendData: nil,
                    showWarning: false
                )
            }
        }
    }
}
