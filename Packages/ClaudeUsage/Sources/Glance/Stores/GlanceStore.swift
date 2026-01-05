//
//  GlanceStore.swift
//  Observable state container for quick glance monitoring
//

import SwiftUI
import Observation

// MARK: - Glance Store

@Observable
@MainActor
public final class GlanceStore {

    // MARK: - State

    private(set) var isLoading = true
    private(set) var activeSession: UsageSession?
    private(set) var todayCost: TodayCost = .zero

    // MARK: - Derived Properties

    var todaysCost: Double { todayCost.total }
    var formattedTodaysCost: String { todayCost.formatted }
    var todayHourlyCosts: [Double] { todayCost.hourlyCosts }

    var sessionTimeProgress: Double {
        activeSession.map { sessionProgress($0, now: clock.now) } ?? 0
    }

    // MARK: - Dependencies

    private let service: GlanceService
    private let clock: any ClockProtocol
    private let refreshCoordinator: RefreshCoordinator

    // MARK: - Internal State

    private var hasInitialized = false

    // MARK: - Initialization

    public init(
        basePath: String = AppConfiguration.default.basePath,
        sessionDurationHours: Double = 5.0,
        clock: any ClockProtocol = SystemClock()
    ) {
        self.service = GlanceService(basePath: basePath, sessionDurationHours: sessionDurationHours)
        self.clock = clock
        self.refreshCoordinator = RefreshCoordinatorFactory.make(
            clock: clock,
            basePath: basePath
        )

        refreshCoordinator.onRefresh = { [weak self] reason in
            await self?.loadData(invalidateCache: reason.shouldInvalidateCache)
        }
    }

    init(
        service: GlanceService,
        clock: any ClockProtocol,
        refreshCoordinator: RefreshCoordinator
    ) {
        self.service = service
        self.clock = clock
        self.refreshCoordinator = refreshCoordinator

        refreshCoordinator.onRefresh = { [weak self] reason in
            await self?.loadData(invalidateCache: reason.shouldInvalidateCache)
        }
    }

    // MARK: - Public API

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        await loadData(invalidateCache: true)
    }

    func loadData(invalidateCache: Bool = true) async {
        isLoading = true
        defer { isLoading = false }

        guard let result = await service.loadData(invalidateCache: invalidateCache) else { return }

        switch result {
        case .success(let data):
            todayCost = data.todayCost
            activeSession = data.activeSession
        case .failure:
            break
        }
    }

    // MARK: - Lifecycle

    func handleAppBecameActive() {
        refreshCoordinator.handleAppBecameActive()
    }

    func handleAppResignActive() {
        refreshCoordinator.handleAppResignActive()
    }

    func handleWindowFocus() {
        refreshCoordinator.handleWindowFocus()
    }
}

// MARK: - Pure Functions

private func sessionProgress(_ session: UsageSession, now: Date) -> Double {
    let elapsed = now.timeIntervalSince(session.startTime)
    let total = session.endTime.timeIntervalSince(session.startTime)
    guard total > 0 else { return 0 }
    return min(elapsed / total, 1.0)
}
