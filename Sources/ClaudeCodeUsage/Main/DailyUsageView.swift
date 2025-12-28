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
                DailyUsageContent(state: ContentState.from(store: store))
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
    case loaded([DailyUsage])
    case error

    static func from(store: UsageStore) -> ContentState {
        if store.isLoading { return .loading }
        guard let stats = store.stats else { return .error }
        return stats.byDate.isEmpty ? .empty : .loaded(stats.byDate)
    }
}

// MARK: - Content Router

private struct DailyUsageContent: View {
    let state: ContentState

    var body: some View {
        switch state {
        case .loading:
            LoadingView(message: "Loading daily usage...")
        case .empty:
            EmptyStateView(
                icon: "calendar",
                title: "No Usage Data",
                message: "Daily usage statistics will appear here once you start using Claude Code.\nData is collected from ~/.claude/projects/"
            )
        case .loaded(let dates):
            DailyUsageList(dates: dates)
        case .error:
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
            titleView
            subtitleView
        }
    }

    private var titleView: some View {
        Text("Daily Usage")
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    private var subtitleView: some View {
        Text("Day-by-day breakdown of your usage")
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
        VStack(spacing: 12) {
            summaryRow
            hourlyChart
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var summaryRow: some View {
        HStack(spacing: 16) {
            DateBadge(info: dateInfo)
            DateDetails(info: dateInfo, modelCount: daily.modelCount)
            Spacer()
            CostMetrics(cost: daily.totalCost, tokens: daily.totalTokens)
        }
    }

    private var hourlyChart: some View {
        HourlyCostChartSimple(hourlyData: daily.hourlyCosts)
    }
}

// MARK: - Card Components

private struct DateBadge: View {
    let info: DateInfo

    var body: some View {
        VStack(spacing: 4) {
            dayText
            monthText
        }
        .frame(width: 50)
        .padding(.vertical, 8)
        .background(info.isToday ? Color.accentColor : Color.gray.opacity(0.2))
        .foregroundColor(info.isToday ? .white : .primary)
        .cornerRadius(8)
    }

    private var dayText: some View {
        Text(info.dayOfMonth)
            .font(.title2)
            .fontWeight(.bold)
    }

    private var monthText: some View {
        Text(info.monthAbbreviation)
            .font(.caption)
            .textCase(.uppercase)
    }
}

private struct DateDetails: View {
    let info: DateInfo
    let modelCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            titleRow
            modelCountText
        }
    }

    private var titleRow: some View {
        HStack {
            Text(info.dayOfWeek)
                .font(.headline)
            todayBadge
        }
    }

    @ViewBuilder
    private var todayBadge: some View {
        Badge(text: "TODAY", color: .accentColor)
        .opacity(info.isToday ? 1 : 0)
    }

    private var modelCountText: some View {
        Text("\(modelCount) model\(modelCount == 1 ? "" : "s") used")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

private struct CostMetrics: View {
    let cost: Double
    let tokens: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            costText
            tokenText
        }
    }

    private var costText: some View {
        Text(cost.asCurrency)
            .font(.system(.body, design: .monospaced))
            .fontWeight(.semibold)
    }

    private var tokenText: some View {
        Text("\(tokens.abbreviated) tokens")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

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
