//
//  GlanceService.swift
//  Data service for loading glance metrics
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.claudecodeusage", category: "GlanceService")

// MARK: - GlanceData

public struct GlanceData: Sendable {
    public let todayCost: TodayCost
    public let activeSession: UsageSession?

    public init(todayCost: TodayCost, activeSession: UsageSession?) {
        self.todayCost = todayCost
        self.activeSession = activeSession
    }
}

// MARK: - GlanceService

public actor GlanceService {

    // MARK: - Dependencies

    private let todayCostProvider: TodayCostProvider
    private let sessionProvider: SessionProvider

    // MARK: - State

    private var isLoading = false

    // MARK: - Initialization

    public init(basePath: String = AppConfiguration.default.basePath, sessionDurationHours: Double = 5.0) {
        let usageProvider = UsageProvider(basePath: basePath)
        self.todayCostProvider = TodayCostProvider(usageProvider: usageProvider)
        self.sessionProvider = SessionProvider(
            basePath: basePath,
            sessionDurationHours: sessionDurationHours
        )
    }

    public init(todayCostProvider: TodayCostProvider, sessionProvider: SessionProvider) {
        self.todayCostProvider = todayCostProvider
        self.sessionProvider = sessionProvider
    }

    // MARK: - Loading

    /// Loads glance data. Returns nil if a load is already in progress.
    public func loadData(invalidateCache: Bool = true) async -> Result<GlanceData, Error>? {
        guard !isLoading else {
            logger.debug("loadData: skipped - already loading")
            return nil
        }
        isLoading = true
        defer { isLoading = false }

        if invalidateCache { await clearCache() }

        // Pipeline: fetch → compose
        return await executeFetch()
            .map { cost, session in GlanceData(todayCost: cost, activeSession: session) }
    }

    private func executeFetch() async -> Result<(TodayCost, UsageSession?), Error> {
        logger.info("loadData: fetching")
        do {
            async let cost = todayCostProvider.getTodayCost()
            async let session = sessionProvider.getActiveSession()
            let result = (try await cost, await session)
            logger.info("loadData: success - cost: \(result.0.total)")
            return .success(result)
        } catch {
            logger.error("loadData: failed - \(error.localizedDescription)")
            return .failure(error)
        }
    }

    // MARK: - Cache Management

    public func clearCache() async {
        await todayCostProvider.clearCache()
        await sessionProvider.clearCache()
    }
}
