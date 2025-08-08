//
//  SessionMetricsSection.swift
//  Live session metrics section component
//

import SwiftUI
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

@available(macOS 13.0, *)
struct SessionMetricsSection: View {
    @EnvironmentObject var dataModel: UsageDataModel
    
    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if let session = dataModel.activeSession {
                // Time progress
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
                
                // Token usage
                if let tokenLimit = dataModel.autoTokenLimit {
                    let tokenPercentage = dataModel.sessionTokenProgress * 100
                    MetricRow(
                        title: "Tokens",
                        value: FormatterService.formatValueWithLimit(session.tokenCounts.total, limit: tokenLimit),
                        subvalue: nil,
                        percentage: tokenPercentage,
                        segments: ColorService.sessionTokenSegments(),
                        trendData: nil,
                        showWarning: tokenPercentage >= 100
                    )
                }
                
                // Burn rate
                if let burnRate = dataModel.burnRate {
                    burnRateView(burnRate)
                }
            }
        }
    }
    
    // MARK: - Burn Rate View
    private func burnRateView(_ burnRate: BurnRate) -> some View {
        HStack {
            Label(
                FormatterService.formatTokenRate(burnRate.tokensPerMinute),
                systemImage: "flame.fill"
            )
            .font(MenuBarTheme.Typography.burnRateLabel)
            .foregroundColor(MenuBarTheme.Colors.Status.warning)
            
            Spacer()
            
            Text(FormatterService.formatCostRate(burnRate.costPerHour))
                .font(MenuBarTheme.Typography.burnRateValue)
                .foregroundColor(MenuBarTheme.Colors.Status.warning)
                .monospacedDigit()
        }
        .padding(.horizontal, MenuBarTheme.Layout.horizontalPadding)
        .padding(.bottom, MenuBarTheme.Layout.verticalPadding)
    }
}