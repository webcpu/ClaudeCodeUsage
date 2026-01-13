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
    private let clock: any ClockProtocol

    // MARK: - Internal State

    private var hasInitialized = false
    private var dayChangeMonitor: DayChangeMonitor?
    private var dayTracker: DayTracker?

    // MARK: - Initialization

    public init(
        basePath: String = AppConfiguration.default.basePath,
        clock: any ClockProtocol = SystemClock()
    ) {
        self.service = InsightsService(basePath: basePath)
        self.clock = clock
    }

    init(service: InsightsService, clock: any ClockProtocol = SystemClock()) {
        self.service = service
        self.clock = clock
    }

    // MARK: - Public API

    func initializeIfNeeded(startMonitoring: Bool = true) async {
        guard !hasInitialized else { return }
        hasInitialized = true

        if startMonitoring {
            await service.startMonitoring { [weak self] in
                Task { await self?.loadData() }
            }
            startDayChangeMonitoring()
        }
        await loadData()
    }

    // MARK: - Day Change Monitoring

    private func startDayChangeMonitoring() {
        let tracker = DayTracker(clock: clock)
        dayTracker = tracker

        dayChangeMonitor = DayChangeMonitor(
            clock: clock,
            dayTracker: tracker,
            onRefresh: { [weak self] _ in
                Task { await self?.loadData() }
            }
        )
        dayChangeMonitor?.start()
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
