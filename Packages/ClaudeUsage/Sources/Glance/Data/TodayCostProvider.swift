//
//  TodayCostProvider.swift
//  Provides today's cost data from usage files
//

import Foundation

// MARK: - TodayCostProvider

/// Provides today's cost data by reading usage files.
///
/// Responsibilities:
/// - Fetches entries from UsageProvider (I/O)
/// - Transforms raw entries into TodayCost (Domain object)
public actor TodayCostProvider: TodayCostProviding {
    private let usageProvider: UsageProvider

    // MARK: - Initialization

    public init(usageProvider: UsageProvider) {
        self.usageProvider = usageProvider
    }

    // MARK: - TodayCostProviding

    public func getTodayCost() async throws -> TodayCost {
        let entries = try await usageProvider.getTodayEntries()
        return TodayCost(entries: entries)
    }

    // MARK: - Cache Management

    public func clearCache() async {
        await usageProvider.clearCache()
    }
}
