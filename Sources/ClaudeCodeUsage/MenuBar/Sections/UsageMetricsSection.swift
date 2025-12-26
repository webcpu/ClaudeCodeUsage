//
//  UsageMetricsSection.swift
//  Usage metrics section component
//

import SwiftUI
import ClaudeCodeUsageKit
import ClaudeLiveMonitorLib

struct UsageMetricsSection: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            if store.stats != nil {
                // Token usage (moved from Session section)
                if let session = store.activeSession,
                   let tokenLimit = store.autoTokenLimit {
                    let tokenPercentage = store.sessionTokenProgress * 100
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
                
                // Burn rate (moved from Session section)
                if let burnRate = store.burnRate {
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
        .padding(.bottom, MenuBarTheme.Layout.verticalPadding)
    }
}

//// Sessions
//MetricRow(
//    title: "Sessions",
//    value: FormatterService.formatSessionCount(dataModel.todaySessionCount),
//    subvalue: "Total: \(stats.totalSessions)",
//    percentage: Double(dataModel.estimatedDailySessions) * 5, // Scale for visibility
//    segments: ColorService.singleColorSegment(color: MenuBarTheme.Colors.Sections.usage),
//    trendData: nil,
//    showWarning: false
//)
