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
            logger.debug("GlanceService: loadData skipped - already loading")
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        logger.info("GlanceService: loadData started (invalidateCache: \(invalidateCache))")

        do {
            if invalidateCache {
                await clearCache()
            }

            async let costTask = todayCostProvider.getTodayCost()
            async let sessionTask = sessionProvider.getActiveSession()

            let todayCost = try await costTask
            let activeSession = await sessionTask

            logger.info("GlanceService: loadData completed - cost: \(todayCost.total)")
            return .success(GlanceData(todayCost: todayCost, activeSession: activeSession))
        } catch {
            logger.error("GlanceService: loadData failed - \(error.localizedDescription)")
            return .failure(error)
        }
    }

    // MARK: - Cache Management

    public func clearCache() async {
        await todayCostProvider.clearCache()
        await sessionProvider.clearCache()
    }
}
