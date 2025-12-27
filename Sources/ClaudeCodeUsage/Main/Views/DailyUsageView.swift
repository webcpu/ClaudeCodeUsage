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
                DailyUsageContent(store: store)
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Content Router

private struct DailyUsageContent: View {
    let store: UsageStore

    var body: some View {
        if let stats = store.stats {
            if stats.byDate.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Usage Data",
                    message: "Daily usage statistics will appear here once you start using Claude Code.\nData is collected from ~/.claude/projects/"
                )
            } else {
                DailyUsageList(dates: stats.byDate)
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
}

// MARK: - Header

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

// MARK: - List

private struct DailyUsageList: View {
    let dates: [DailyUsage]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(dates.reversed()) { daily in
                DailyCard(daily: daily)
            }
        }
    }
}

// MARK: - Daily Card

struct DailyCard: View {
    let daily: DailyUsage

    private var dateInfo: DateInfo { DateInfo.from(daily.date) }

    var body: some View {
        HStack(spacing: 16) {
            DateBadge(day: dateInfo.dayOfMonth, month: dateInfo.monthAbbreviation, isToday: dateInfo.isToday)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateInfo.dayOfWeek)
                        .font(.headline)
                    if dateInfo.isToday {
                        Badge(text: "TODAY", color: .accentColor)
                    }
                }
                Text("\(daily.modelCount) model\(daily.modelCount == 1 ? "" : "s") used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

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
}

// MARK: - Date Badge

private struct DateBadge: View {
    let day: String
    let month: String
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(day)
                .font(.title2)
                .fontWeight(.bold)
            Text(month)
                .font(.caption)
                .textCase(.uppercase)
        }
        .frame(width: 50)
        .padding(.vertical, 8)
        .background(isToday ? Color.accentColor : Color.gray.opacity(0.2))
        .foregroundColor(isToday ? .white : .primary)
        .cornerRadius(8)
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

// MARK: - Pure Transformations

private struct DateInfo {
    let dayOfMonth: String
    let monthAbbreviation: String
    let dayOfWeek: String
    let isToday: Bool

    static func from(_ dateString: String) -> DateInfo {
        let components = dateString.split(separator: "-")
        let day = components.count == 3 ? String(components[2]) : ""

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateString) else {
            return DateInfo(dayOfMonth: day, monthAbbreviation: "", dayOfWeek: dateString, isToday: false)
        }

        formatter.dateFormat = "MMM"
        let month = formatter.string(from: date)

        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: date)

        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        return DateInfo(
            dayOfMonth: day,
            monthAbbreviation: month,
            dayOfWeek: weekday,
            isToday: dateString == todayString
        )
    }
}
