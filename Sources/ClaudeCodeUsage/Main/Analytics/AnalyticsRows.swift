//
//  AnalyticsRows.swift
//  Shared row components for analytics cards
//

import SwiftUI

struct TokenRow: View {
    let label: String
    let percentage: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text(percentage.asPercentage)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct PredictionRow: View {
    let label: String
    let value: String
    let icon: String
    let detail: String?

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            valueSection
        }
    }

    private var valueSection: some View {
        VStack(alignment: .trailing) {
            valueText
            detailText
        }
    }

    private var valueText: some View {
        Text(value)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.semibold)
    }

    @ViewBuilder
    private var detailText: some View {
        if let detail {
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct TrendRow: View {
    let trend: UsageTrend

    var body: some View {
        HStack {
            Label("7-Day Trend", systemImage: trend.icon)
                .foregroundColor(trend.color)
            Spacer()
            Text(trend.formattedPercentage)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(trend.color)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let detail: String

    var body: some View {
        HStack {
            labelView
            Spacer()
            valueSection
        }
    }

    private var labelView: some View {
        Text(label)
            .foregroundColor(.secondary)
    }

    private var valueSection: some View {
        VStack(alignment: .trailing) {
            Text(value)
                .font(.subheadline)
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
