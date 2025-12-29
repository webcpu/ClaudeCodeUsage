//
//  YearlyCostHeatmapCard.swift
//  Yearly cost heatmap visualization
//

import SwiftUI
import ClaudeUsageCore

struct YearlyCostHeatmapCard: View {
    let stats: UsageStats
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private var availableYears: [Int] { YearExtractor.years(from: stats.byDate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeatmapHeader(years: availableYears, selectedYear: $selectedYear)
            YearlyCostHeatmap(stats: stats, year: selectedYear)
        }
        .onAppear {
            if let mostRecent = availableYears.first {
                selectedYear = mostRecent
            }
        }
    }
}

private struct HeatmapHeader: View {
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        HStack {
            Spacer()
            if years.count > 1 {
                YearSelector(years: years, selectedYear: $selectedYear)
            }
        }
    }
}

private struct YearSelector: View {
    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        Menu {
            ForEach(years, id: \.self) { year in
                Button(String(year)) { selectedYear = year }
            }
        } label: {
            menuLabel
        }
        .buttonStyle(.plain)
    }

    private var menuLabel: some View {
        HStack(spacing: 4) {
            Text(String(selectedYear))
                .font(.subheadline)
                .fontWeight(.medium)
            Image(systemName: "chevron.down")
                .font(.caption)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Pure Transformation

private enum YearExtractor {
    static func years(from dates: [DailyUsage]) -> [Int] {
        Array(Set(dates.compactMap { Int($0.date.prefix(4)) })).sorted(by: >)
    }
}
