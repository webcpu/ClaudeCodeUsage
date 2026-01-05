//
//  SessionMetricsSection.swift
//  Live session metrics: time, tokens, burn rate
//

import SwiftUI

struct SessionMetricsSection: View {
    @Environment(GlanceStore.self) private var store

    var body: some View {
        if let session = store.activeSession {
            VStack(spacing: GlanceTheme.Layout.sectionSpacing) {
                sessionTimeRow(session)
                tokenRow(session.tokens.total)
                if session.burnRate.tokensPerMinute > 0 {
                    burnRateRow(session.burnRate)
                }
            }
        }
    }

    // MARK: - Time

    private func sessionTimeRow(_ session: UsageSession) -> MetricRow {
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

    // MARK: - Tokens

    private func tokenRow(_ tokens: Int) -> some View {
        HStack {
            Text("Tokens")
                .font(GlanceTheme.Typography.metricTitle)
                .foregroundColor(GlanceTheme.Colors.UI.secondaryText)
            Spacer()
            Text(FormatterService.formatTokenCount(tokens))
                .font(GlanceTheme.Typography.metricValue.weight(.medium))
                .foregroundColor(GlanceTheme.Colors.UI.primaryText)
                .monospacedDigit()
        }
        .padding(.vertical, GlanceTheme.Layout.verticalPadding)
    }

    // MARK: - Burn Rate

    private func burnRateRow(_ burnRate: BurnRate) -> some View {
        HStack {
            Label(
                FormatterService.formatTokenRate(burnRate.tokensPerMinute),
                systemImage: "flame.fill"
            )
            .font(GlanceTheme.Typography.burnRateLabel)
            .foregroundColor(GlanceTheme.Colors.Status.warning)
            Spacer()
            Text(FormatterService.formatCostRate(burnRate.costPerHour))
                .font(GlanceTheme.Typography.burnRateValue)
                .foregroundColor(GlanceTheme.Colors.Status.warning)
                .monospacedDigit()
        }
        .padding(.bottom, GlanceTheme.Layout.verticalPadding)
    }
}
