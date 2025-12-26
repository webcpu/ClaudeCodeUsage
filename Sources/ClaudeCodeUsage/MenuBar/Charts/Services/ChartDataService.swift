//
//  ChartDataService.swift
//  Service for fetching and processing chart data
//

import Foundation
import Observation
import ClaudeCodeUsageKit

@Observable
@MainActor
final class ChartDataService {

    private(set) var todayHourlyCosts: [Double] = []
    private(set) var isLoading: Bool = false
    private(set) var error: Error?
    private let dateProvider: DateProviding

    init(dateProvider: DateProviding = SystemDateProvider()) {
        self.dateProvider = dateProvider
    }

    // MARK: - Data Loading

    func loadHourlyCostsFromEntries(_ entries: [UsageEntry]) async {
        isLoading = true
        error = nil

        let hourlyData = UsageAnalytics.todayHourlyCosts(from: entries, referenceDate: dateProvider.now)
        self.todayHourlyCosts = hourlyData
        self.isLoading = false

        #if DEBUG
        let totalCost = hourlyData.reduce(0, +)
        print("[ChartDataService] Loaded: $\(String(format: "%.2f", totalCost)) from \(entries.count) entries")
        #endif
    }

    // MARK: - Data Access

    func hourlyDataForDisplay() -> [Double] {
        guard !todayHourlyCosts.isEmpty else { return [] }

        var displayData = todayHourlyCosts
        while displayData.count < 24 {
            displayData.append(0)
        }
        return Array(displayData.prefix(24))
    }

    func currentHourCost() -> Double {
        let currentHour = Calendar.current.component(.hour, from: dateProvider.now)
        guard currentHour < todayHourlyCosts.count else { return 0 }
        return todayHourlyCosts[currentHour]
    }
}
