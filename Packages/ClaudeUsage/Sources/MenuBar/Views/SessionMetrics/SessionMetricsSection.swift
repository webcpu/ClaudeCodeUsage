//
//  SessionMetricsSection.swift
//  Live session metrics section component
//

import SwiftUI

struct SessionMetricsSection: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if let session = store.activeSession {
                sessionTimeMetricRow(for: session)
            }
        }
    }

    private func sessionTimeMetricRow(for session: SessionBlock) -> MetricRow {
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
