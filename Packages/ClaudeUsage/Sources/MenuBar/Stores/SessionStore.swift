//
//  SessionStore.swift
//  Observable state container for live session monitoring
//

import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "SessionStore")

// MARK: - Session Store

@Observable
@MainActor
public final class SessionStore {
    // MARK: - State

    private(set) var isLoading = true
    private(set) var activeSession: SessionBlock?
    private(set) var burnRate: BurnRate?
    private(set) var todayEntries: [UsageEntry] = []

    // MARK: - Derived Properties

    var todaysCost: Double {
        todayEntries.reduce(0.0) { $0 + $1.costUSD }
    }

    var formattedTodaysCost: String {
        todaysCost.asCurrency
    }

    var sessionTimeProgress: Double {
        activeSession.map { sessionProgress($0, now: clock.now) } ?? 0
    }

    var todayHourlyCosts: [Double] {
        UsageAggregator.todayHourlyCosts(from: todayEntries, referenceDate: clock.now)
    }

    // MARK: - Dependencies

    private let repository: UsageRepository
    private let sessionMonitor: SessionMonitor
    private let clock: any ClockProtocol
    private let refreshCoordinator: RefreshCoordinator

    // MARK: - Internal State

    private var isCurrentlyLoading = false
    private var hasInitialized = false

    // MARK: - Initialization

    public init(
        basePath: String = AppConfiguration.default.basePath,
        sessionDurationHours: Double = 5.0,
        clock: any ClockProtocol = SystemClock()
    ) {
        self.repository = UsageRepository(basePath: basePath)
        self.sessionMonitor = SessionMonitor(
            basePath: basePath,
            sessionDurationHours: sessionDurationHours
        )
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
        repository: UsageRepository,
        sessionMonitor: SessionMonitor,
        clock: any ClockProtocol,
        refreshCoordinator: RefreshCoordinator
    ) {
        self.repository = repository
        self.sessionMonitor = sessionMonitor
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
        guard !isCurrentlyLoading else {
            logger.debug("Load blocked: already loading")
            return
        }

        isCurrentlyLoading = true
        isLoading = true
        defer {
            isCurrentlyLoading = false
            isLoading = false
        }

        logger.info("Loading session data (invalidateCache=\(invalidateCache))")

        do {
            if invalidateCache {
                await repository.clearCache()
            }

            async let entriesTask = repository.getTodayEntries()
            async let sessionTask = sessionMonitor.getActiveSession()

            todayEntries = try await entriesTask
            activeSession = await sessionTask
            burnRate = activeSession?.burnRate

            logger.info("Loaded \(self.todayEntries.count) entries, session=\(self.activeSession != nil)")
        } catch {
            logger.error("Failed to load: \(error.localizedDescription)")
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

private func sessionProgress(_ session: SessionBlock, now: Date) -> Double {
    let elapsed = now.timeIntervalSince(session.startTime)
    let total = session.endTime.timeIntervalSince(session.startTime)
    guard total > 0 else { return 0 }
    return min(elapsed / total, 1.0)
}
