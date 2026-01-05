//
//  InsightsService.swift
//  Domain service for loading and monitoring usage insights
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "InsightsService")

// MARK: - InsightsService

public actor InsightsService {

    // MARK: - Dependencies

    private let usageProvider: UsageProvider
    private let basePath: String

    // MARK: - State

    private var isLoading = false
    private var directoryMonitor: DirectoryMonitor?

    // MARK: - Initialization

    public init(basePath: String = AppConfiguration.default.basePath) {
        self.basePath = basePath
        self.usageProvider = UsageProvider(basePath: basePath)
    }

    public init(usageProvider: UsageProvider, basePath: String) {
        self.usageProvider = usageProvider
        self.basePath = basePath
    }

    // MARK: - Loading

    /// Loads usage stats. Returns nil if a load is already in progress.
    public func loadStats() async -> Result<UsageStats, Error>? {
        guard !isLoading else {
            logger.debug("InsightsService: loadStats skipped - already loading")
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        logger.info("InsightsService: loadStats started")

        do {
            let stats = try await usageProvider.getUsageStats()
            logger.info("InsightsService: loadStats completed - cost: \(stats.totalCost)")
            return .success(stats)
        } catch {
            logger.error("InsightsService: loadStats failed - \(error.localizedDescription)")
            return .failure(error)
        }
    }

    // MARK: - Monitoring

    public func startMonitoring(onChange: @escaping @Sendable @MainActor () -> Void) async {
        guard directoryMonitor == nil else { return }

        directoryMonitor = DirectoryMonitor(path: basePath, onChange: onChange)
        await directoryMonitor?.start()
        logger.info("InsightsService: monitoring started for \(self.basePath)")
    }

    public func stopMonitoring() async {
        await directoryMonitor?.stop()
        directoryMonitor = nil
        logger.info("InsightsService: monitoring stopped")
    }
}
