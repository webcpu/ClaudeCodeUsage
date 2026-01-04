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

    private let usageProvider: UsageProvider
    private var directoryMonitor: DirectoryMonitor?

    // MARK: - Internal State

    private var isCurrentlyLoading = false
    private var hasInitialized = false

    // MARK: - Initialization

    public init(basePath: String = AppConfiguration.default.basePath) {
        self.usageProvider = UsageProvider(basePath: basePath)
        self.directoryMonitor = nil

        self.directoryMonitor = DirectoryMonitor(path: basePath) { [weak self] in
            guard let self else { return }
            Task { await self.loadData() }
        }
    }

    init(usageProvider: UsageProvider, directoryMonitor: DirectoryMonitor) {
        self.usageProvider = usageProvider
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
        guard !isCurrentlyLoading else { return }

        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }

        do {
            let stats = try await usageProvider.getUsageStats()
            state = .loaded(stats)
        } catch {
            state = .error(error)
            logger.error("Failed to load: \(error.localizedDescription)")
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() async {
        await directoryMonitor?.start()
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
