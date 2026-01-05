//
//  InsightsStore.swift
//  Observable state container for usage insights
//

import SwiftUI
import Observation

// MARK: - Insights Store

@Observable
@MainActor
public final class InsightsStore {

    // MARK: - State

    private(set) var state: InsightsState = .loading

    // MARK: - Derived Properties

    var isLoading: Bool { state.isLoading }
    var stats: UsageStats? { state.stats }

    // MARK: - Dependencies

    private let service: InsightsService

    // MARK: - Internal State

    private var hasInitialized = false

    // MARK: - Initialization

    public init(basePath: String = AppConfiguration.default.basePath) {
        self.service = InsightsService(basePath: basePath)
    }

    init(service: InsightsService) {
        self.service = service
    }

    // MARK: - Public API

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true

        await service.startMonitoring { [weak self] in
            Task { await self?.loadData() }
        }
        await loadData()
    }

    func loadData() async {
        guard let result = await service.loadStats() else { return }

        switch result {
        case .success(let stats):
            state = .loaded(stats)
        case .failure(let error):
            state = .error(error)
        }
    }
}

// MARK: - Insights State

public enum InsightsState {
    case loading
    case loaded(UsageStats)
    case error(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var stats: UsageStats? {
        if case .loaded(let stats) = self { return stats }
        return nil
    }
}
