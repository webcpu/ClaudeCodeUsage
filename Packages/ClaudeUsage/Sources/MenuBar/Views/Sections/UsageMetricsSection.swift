//
//  UsageMetricsSection.swift
//  Usage metrics section component
//

import SwiftUI

struct UsageMetricsSection: View {
    @Environment(SessionStore.self) private var store

    var body: some View {
        VStack(spacing: MenuBarTheme.Layout.sectionSpacing) {
            // Token usage - show raw count only (no fake percentage)
            // Claude's actual rate limit is not exposed in usage data
            if let session = store.activeSession {
                TokenDisplay(tokens: session.tokens.total)
            }

            // Burn rate
            if let burnRate = store.burnRate {
                burnRateView(burnRate)
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

// MARK: - Token Display (no fake percentage)

private struct TokenDisplay: View {
    let tokens: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tokens")
                    .font(MenuBarTheme.Typography.metricTitle)
                    .foregroundColor(MenuBarTheme.Colors.UI.secondaryText)
            }

            Spacer()

            Text(FormatterService.formatTokenCount(tokens))
                .font(MenuBarTheme.Typography.metricValue.weight(.medium))
                .foregroundColor(MenuBarTheme.Colors.UI.primaryText)
                .monospacedDigit()
        }
        .padding(.vertical, MenuBarTheme.Layout.verticalPadding)
    }
}
