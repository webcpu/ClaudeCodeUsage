//
//  ModelsView.swift
//  Model usage breakdown view
//

import SwiftUI
import ClaudeUsageCore

struct ModelsView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModelsHeader()
                ModelsContent(state: ContentState.from(store: store))
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content State

@MainActor
private enum ContentState {
    case loading
    case empty
    case loaded(models: [ModelUsage], totalCost: Double)
    case error

    static func from(store: UsageStore) -> ContentState {
        if store.isLoading { return .loading }
        guard let stats = store.stats else { return .error }
        let sortedModels = stats.byModel.sorted { $0.totalCost > $1.totalCost }
        return sortedModels.isEmpty ? .empty : .loaded(models: sortedModels, totalCost: stats.totalCost)
    }
}

// MARK: - Content Router

private struct ModelsContent: View {
    let state: ContentState

    var body: some View {
        switch state {
        case .loading:
            LoadingView(message: "Loading models...")
        case .empty:
            EmptyStateView(
                icon: "cpu",
                title: "No Model Data",
                message: "Model usage will appear here once you start using Claude Code."
            )
        case .loaded(let models, let totalCost):
            ModelsList(models: models, totalCost: totalCost)
        case .error:
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
            titleView
            subtitleView
        }
    }

    private var titleView: some View {
        Text("Model Usage")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var subtitleView: some View {
        Text("Breakdown by AI model")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    let message: String

    var body: some View {
        ProgressView(message)
            .frame(maxWidth: .infinity)
            .padding(.top, 50)
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
            ModelHeader(name: model.model, cost: model.totalCost)
            UsageBar(percentage: metrics.percentage, color: metrics.color)
            ModelStats(model: model, percentage: metrics.percentage)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Card Components

private struct ModelHeader: View {
    let name: String
    let cost: Double

    var body: some View {
        HStack {
            Label(ModelNameFormatter.format(name), systemImage: "cpu")
                .font(.headline)
            Spacer()
            Text(cost.asCurrency)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
        }
    }
}

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

private struct ModelStats: View {
    let model: ModelUsage
    let percentage: Double

    var body: some View {
        HStack {
            StatLabel(icon: "doc.text", value: "\(model.sessionCount) sessions")
            Spacer()
            StatLabel(icon: "number", value: "\(model.tokens.total.abbreviated) tokens")
            Spacer()
            StatLabel(icon: "percent", value: percentage.asPercentage)
        }
    }
}

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
    private static let knownFamilies = ["opus", "sonnet", "haiku"]

    static func format(_ model: String) -> String {
        let parts = model.lowercased().components(separatedBy: "-")
        let family = extractFamily(from: parts)
        let version = extractVersion(from: parts)
        return buildDisplayName(family: family, version: version, fallback: model)
    }

    private static func extractFamily(from parts: [String]) -> String? {
        parts.first { knownFamilies.contains($0) }
    }

    private static func extractVersion(from parts: [String]) -> String {
        let numbers = parts.compactMap { Int($0) }
        return numbers.count >= 2
            ? "\(numbers[0]).\(numbers[1])"
            : numbers.first.map { "\($0)" } ?? ""
    }

    private static func buildDisplayName(family: String?, version: String, fallback: String) -> String {
        guard let family = family else { return fallback }
        let capitalizedFamily = family.capitalized
        return version.isEmpty ? "Claude \(capitalizedFamily)" : "Claude \(capitalizedFamily) \(version)"
    }
}
