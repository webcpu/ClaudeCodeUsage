//
//  YearlyCostHeatmap+Preview.swift
//
//  Preview provider for YearlyCostHeatmap development.
//

import SwiftUI

// MARK: - Preview

#if DEBUG
struct YearlyCostHeatmap_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Default configuration
                YearlyCostHeatmap(stats: sampleStats)

                // Performance optimized
                YearlyCostHeatmap.performanceOptimized(stats: sampleStats)

                // Compact version
                YearlyCostHeatmap.compact(stats: sampleStats)

                // Accessibility optimized
                YearlyCostHeatmap.accessible(stats: sampleStats)
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }

    static var sampleStats: UsageStats {
        let dailyUsage = generateSampleDailyUsage()
        return UsageStats(
            totalCost: dailyUsage.reduce(0) { $0 + $1.totalCost },
            tokens: TokenCounts(
                input: 250000,
                output: 150000,
                cacheCreation: 0,
                cacheRead: 0
            ),
            sessionCount: 150,
            byModel: [],
            byDate: dailyUsage,
            byProject: []
        )
    }

    private static func generateSampleDailyUsage() -> [DailyUsage] {
        let calendar = Calendar.current
        let today = Date()
        let dateFormatter = makeDateFormatter()

        return (0..<365).compactMap { dayOffset in
            makeDailyUsage(
                dayOffset: dayOffset,
                today: today,
                calendar: calendar,
                dateFormatter: dateFormatter
            )
        }
    }

    private static func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func makeDailyUsage(
        dayOffset: Int,
        today: Date,
        calendar: Calendar,
        dateFormatter: DateFormatter
    ) -> DailyUsage? {
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
            return nil
        }
        let cost = calculateSampleCost(for: date, dayOffset: dayOffset, calendar: calendar)
        return DailyUsage(
            date: dateFormatter.string(from: date),
            totalCost: cost,
            totalTokens: Int(cost * 1000),
            modelsUsed: ["claude-sonnet-4"]
        )
    }

    private static func calculateSampleCost(
        for date: Date,
        dayOffset: Int,
        calendar: Calendar
    ) -> Double {
        let hasNoRecentActivity = dayOffset >= 300
        guard !hasNoRecentActivity else { return 0 }

        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        let baseUsage = isWeekend ? 0.3 : 1.0
        let randomFactor = Double.random(in: 0.2...1.8)
        let rawCost = baseUsage * randomFactor * 3.0
        let simulateNoUsageDay = rawCost > 2.8
        return simulateNoUsageDay ? 0 : rawCost
    }
}
#endif
