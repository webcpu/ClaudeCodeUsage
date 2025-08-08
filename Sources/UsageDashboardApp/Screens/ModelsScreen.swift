//
//  ModelsScreen.swift
//  Model usage breakdown screen
//

import SwiftUI
import ClaudeCodeUsage

struct ModelsScreen: View {
    @EnvironmentObject var dataModel: UsageDataModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModelsHeader()
                
                if let stats = dataModel.stats {
                    if stats.byModel.isEmpty {
                        EmptyStateView(
                            icon: "cpu",
                            title: "No Model Data",
                            message: "Model usage will appear here once you start using Claude Code."
                        )
                    } else {
                        ModelsList(stats: stats)
                    }
                } else if dataModel.isLoading {
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
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Models Header
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

// MARK: - Models List
private struct ModelsList: View {
    let stats: UsageStats
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(stats.byModel) { model in
                ModelCard(model: model, totalCost: stats.totalCost)
            }
        }
    }
}

// MARK: - Model Card
struct ModelCard: View {
    let model: ModelUsage
    let totalCost: Double
    
    private var percentage: Double {
        totalCost > 0 ? (model.totalCost / totalCost) * 100 : 0
    }
    
    private var modelColor: Color {
        if model.model.contains("opus") {
            return .purple
        } else if model.model.contains("sonnet") {
            return .blue
        } else if model.model.contains("haiku") {
            return .green
        } else {
            return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(formatModelName(model.model), systemImage: "cpu")
                    .font(.headline)
                
                Spacer()
                
                Text(model.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(modelColor)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
            
            // Stats
            HStack {
                StatLabel(
                    icon: "doc.text",
                    value: "\(model.sessionCount) sessions"
                )
                
                Spacer()
                
                StatLabel(
                    icon: "number",
                    value: "\(model.totalTokens.abbreviated) tokens"
                )
                
                Spacer()
                
                StatLabel(
                    icon: "percent",
                    value: percentage.asPercentage
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func formatModelName(_ model: String) -> String {
        model.components(separatedBy: "-").prefix(3).joined(separator: "-")
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