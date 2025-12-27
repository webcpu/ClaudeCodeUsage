//
//  ModelsView.swift
//  Model usage breakdown view
//

import SwiftUI
import ClaudeCodeUsageKit

struct ModelsView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModelsHeader()
                ModelsContent(store: store)
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content Router

private struct ModelsContent: View {
    let store: UsageStore

    var body: some View {
        if let stats = store.stats {
            if stats.byModel.isEmpty {
                EmptyStateView(
                    icon: "cpu",
                    title: "No Model Data",
                    message: "Model usage will appear here once you start using Claude Code."
                )
            } else {
                ModelsList(models: stats.byModel, totalCost: stats.totalCost)
            }
        } else if store.isLoading {
            ProgressView("Loading models...")
                .frame(maxWidth: .infinity)
                .padding(.top, 50)
        } else {
            EmptyStateView(
                icon: "cpu",
                title: "No Data Available",
                message: "Unable to load model usage data."
            )
        }
    }
}

// MARK: - Header

private struct ModelsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Model Usage")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Breakdown by AI model")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - List

private struct ModelsList: View {
    let models: [ModelUsage]
    let totalCost: Double

    var body: some View {
        VStack(spacing: 12) {
            ForEach(models) { model in
                ModelCard(model: model, totalCost: totalCost)
            }
        }
    }
}

// MARK: - Model Card

struct ModelCard: View {
    let model: ModelUsage
    let totalCost: Double

    private var metrics: ModelMetrics { ModelMetrics.from(model: model, totalCost: totalCost) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(ModelNameFormatter.format(model.model), systemImage: "cpu")
                    .font(.headline)
                Spacer()
                Text(model.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }

            UsageBar(percentage: metrics.percentage, color: metrics.color)

            HStack {
                StatLabel(icon: "doc.text", value: "\(model.sessionCount) sessions")
                Spacer()
                StatLabel(icon: "number", value: "\(model.totalTokens.abbreviated) tokens")
                Spacer()
                StatLabel(icon: "percent", value: metrics.percentage.asPercentage)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Usage Bar

private struct UsageBar: View {
    let percentage: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * (percentage / 100), height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Stat Label

private struct StatLabel: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Pure Transformations

private struct ModelMetrics {
    let percentage: Double
    let color: Color

    static func from(model: ModelUsage, totalCost: Double) -> ModelMetrics {
        let pct = totalCost > 0 ? (model.totalCost / totalCost) * 100 : 0
        let color = ModelColorResolver.color(for: model.model)
        return ModelMetrics(percentage: pct, color: color)
    }
}

private enum ModelColorResolver {
    static func color(for modelName: String) -> Color {
        if modelName.contains("opus") { return .purple }
        if modelName.contains("sonnet") { return .blue }
        if modelName.contains("haiku") { return .green }
        return .gray
    }
}

private enum ModelNameFormatter {
    static func format(_ model: String) -> String {
        model.components(separatedBy: "-").prefix(3).joined(separator: "-")
    }
}
