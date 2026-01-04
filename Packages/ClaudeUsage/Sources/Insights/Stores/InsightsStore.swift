//
//  InsightsStore.swift
//  Observable state container for usage insights
//

import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "InsightsStore")

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

    private let repository: UsageRepository
    private var directoryMonitor: DirectoryMonitor?

    // MARK: - Internal State

    private var isCurrentlyLoading = false
    private var hasInitialized = false

    // MARK: - Initialization

    public init(basePath: String = AppConfiguration.default.basePath) {
        self.repository = UsageRepository(basePath: basePath)
        self.directoryMonitor = nil

        self.directoryMonitor = DirectoryMonitor(path: basePath) { [weak self] in
            guard let self else { return }
            Task { await self.loadData() }
        }
    }

    init(repository: UsageRepository, directoryMonitor: DirectoryMonitor) {
        self.repository = repository
        self.directoryMonitor = directoryMonitor
    }

    // MARK: - Public API

    func initializeIfNeeded() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        await startMonitoring()
        await loadData()
    }

    func loadData() async {
        guard !isCurrentlyLoading else {
            logger.debug("Load blocked: already loading")
            return
        }

        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }

        logger.info("Loading insights data")

        do {
            let stats = try await repository.getUsageStats()
            state = .loaded(stats)
            logger.info("Loaded \(stats.byDate.count) days of data")
        } catch {
            state = .error(error)
            logger.error("Failed to load: \(error.localizedDescription)")
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() async {
        await directoryMonitor?.start()
        logger.info("Started directory monitoring")
    }
}

// MARK: - Insights State

enum InsightsState {
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
