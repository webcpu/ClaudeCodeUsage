//
//  DailyUsageView.swift
//  Daily usage breakdown view
//

import SwiftUI

struct DailyUsageView: View {
    @Environment(InsightsStore.self) private var store

    var body: some View {
        CaptureCompatibleScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DailyUsageHeader()
                ContentStateRouterView(
                    state: contentState(from: store),
                    router: DailyUsageRouter()
                )
            }
            .padding()
        }
        .frame(minWidth: 600, idealWidth: 840)
    }

    private func contentState(from store: InsightsStore) -> RoutableState<[DailyUsage]> {
        if store.isLoading { return .loading }
        guard let stats = store.stats else { return .error }
        return stats.byDate.isEmpty ? .empty : .loaded(stats.byDate)
    }
}

// MARK: - Router

private struct DailyUsageRouter: ContentStateRouting {
    var loadingMessage: String { "Loading daily usage..." }

    var errorDisplay: ErrorDisplay {
        ErrorDisplay(
            icon: "calendar",
            title: "No Data Available",
            message: "Daily usage statistics will appear here once you start using Claude Code.\nData is collected from ~/.claude/projects/"
        )
    }

    func loadedView(for dates: [DailyUsage]) -> some View {
        DailyUsageList(dates: dates)
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

// MARK: - Grid

private struct DailyUsageList: View {
    let dates: [DailyUsage]

    private enum Layout {
        static let minColumnWidth: CGFloat = 300
        static let spacing: CGFloat = 12
    }

    private var globalMaxHourlyCost: Double {
        dates.flatMap(\.hourlyCosts).max() ?? 1.0
    }

    private var gridItems: [GridItem] {
        [GridItem(.adaptive(minimum: Layout.minColumnWidth), spacing: Layout.spacing)]
    }

    var body: some View {
        LazyVGrid(columns: gridItems, spacing: Layout.spacing) {
            ForEach(dates.reversed()) { daily in
                DailyCard(daily: daily, maxHourlyCost: globalMaxHourlyCost)
            }
        }
    }
}

// MARK: - Daily Card

struct DailyCard: View {
    let daily: DailyUsage
    var maxHourlyCost: Double? = nil // Shared scale for comparing charts

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
            DateDetails(info: dateInfo, modelCount: daily.modelsUsed.count)
            Spacer()
            CostMetrics(cost: daily.totalCost, tokens: daily.totalTokens)
        }
    }

    private var hourlyChart: some View {
        HourlyCostChartSimple(hourlyData: daily.hourlyCosts, maxScale: maxHourlyCost)
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
                .lineLimit(1)
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
            .lineLimit(1)
            .fixedSize()
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .fixedSize()
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
