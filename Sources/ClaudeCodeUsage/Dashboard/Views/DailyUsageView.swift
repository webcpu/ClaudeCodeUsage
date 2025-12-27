//
//  DailyUsageView.swift
//  Daily usage breakdown view
//

import SwiftUI
import ClaudeCodeUsageKit

struct DailyUsageView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DailyUsageHeader()

                if let stats = store.stats {
                    if stats.byDate.isEmpty {
                        EmptyStateView(
                            icon: "calendar",
                            title: "No Usage Data",
                            message: "Daily usage statistics will appear here once you start using Claude Code.\nData is collected from ~/.claude/projects/"
                        )
                    } else {
                        DailyUsageList(stats: stats)
                    }
                } else if store.isLoading {
                    ProgressView("Loading daily usage...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                } else {
                    EmptyStateView(
                        icon: "calendar",
                        title: "No Data Available",
                        message: "Unable to load daily usage data."
                    )
                }
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Daily Usage Header
private struct DailyUsageHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Usage")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Day-by-day breakdown of your usage")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Daily Usage List
private struct DailyUsageList: View {
    let stats: UsageStats
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(stats.byDate.reversed()) { daily in
                DailyCard(daily: daily)
            }
        }
    }
}

// MARK: - Daily Card
struct DailyCard: View {
    let daily: DailyUsage
    
    private var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return daily.date == formatter.string(from: Date())
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Date Badge
            VStack(spacing: 4) {
                Text(dayOfMonth)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(monthAbbreviation)
                    .font(.caption)
                    .textCase(.uppercase)
            }
            .frame(width: 50)
            .padding(.vertical, 8)
            .background(isToday ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isToday ? .white : .primary)
            .cornerRadius(8)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dayOfWeek)
                        .font(.headline)
                    
                    if isToday {
                        Badge(text: "TODAY", color: .accentColor)
                    }
                }
                
                Text("\(daily.modelCount) model\(daily.modelCount == 1 ? "" : "s") used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Metrics
            VStack(alignment: .trailing, spacing: 4) {
                Text(daily.totalCost.asCurrency)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                
                Text("\(daily.totalTokens.abbreviated) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var dayOfMonth: String {
        let components = daily.date.split(separator: "-")
        guard components.count == 3 else { return "" }
        return String(components[2])
    }
    
    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: daily.date) else { return "" }
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: daily.date) else { return daily.date }
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Badge
private struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}