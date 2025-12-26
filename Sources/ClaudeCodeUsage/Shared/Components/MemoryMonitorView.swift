//
//  MemoryMonitorView.swift
//  ClaudeCodeUsage
//

import SwiftUI

// MARK: - SwiftUI Extensions

private extension MemoryPressureLevel {
    var swiftUIColor: Color {
        switch self {
        case .nominal: return .green
        case .warning: return .yellow
        case .critical: return .orange
        case .terminal: return .red
        }
    }
}

// MARK: - Memory Monitor View

/// SwiftUI view for displaying memory stats
public struct MemoryMonitorView: View {
    @State private var monitor = MemoryMonitor()
    @State private var showDetails = false

    public init() {}

    public var body: some View {
        Group {
            if let stats = monitor.currentStats {
                statsView(stats)
            } else {
                placeholderView
            }
        }
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
        .sheet(isPresented: $showDetails) {
            MemoryDetailsView(monitor: monitor)
        }
    }

    private func statsView(_ stats: MemoryStats) -> some View {
        HStack {
            Image(systemName: stats.memoryPressure.systemImage)
                .foregroundColor(stats.memoryPressure.swiftUIColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Memory: \(stats.footprintMB, specifier: "%.1f") MB")
                    .font(.caption)

                if monitor.isMemoryPressureHigh() {
                    Text("High Usage")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button(action: { showDetails.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var placeholderView: some View {
        Text("Memory: --")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }
}

// MARK: - Memory Details View

struct MemoryDetailsView: View {
    let monitor: MemoryMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let stats = monitor.currentStats {
                statsContent(stats)
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 250)
    }

    private var header: some View {
        HStack {
            Text("Memory Statistics")
                .font(.headline)

            Spacer()

            Button("Done") {
                dismiss()
            }
        }
    }

    private func statsContent(_ stats: MemoryStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatRow(label: "App Memory", value: String(format: "%.1f MB", stats.footprintMB))
            StatRow(label: "System Used", value: String(format: "%.1f MB", stats.usedMemoryMB))
            StatRow(label: "Free Memory", value: String(format: "%.1f MB", stats.freeMemoryMB))
            StatRow(label: "Pressure Level", value: stats.memoryPressure.rawValue)
            StatRow(label: "Trend", value: monitor.getMemoryTrend().rawValue)

            Divider()

            Text("History (\(monitor.memoryHistory.count) samples)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}
