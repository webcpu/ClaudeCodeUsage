//
//  DependencyContainer.swift
//  Dependency injection container for clean architecture
//

import Foundation
import Observation
import ClaudeCodeUsage
// Import specific types from ClaudeLiveMonitorLib to avoid UsageEntry conflict
import struct ClaudeLiveMonitorLib.SessionBlock
import struct ClaudeLiveMonitorLib.BurnRate
import class ClaudeLiveMonitorLib.LiveMonitor
import struct ClaudeLiveMonitorLib.LiveMonitorConfig

// MARK: - Configuration
public struct AppConfiguration {
    let basePath: String
    let refreshInterval: TimeInterval
    let sessionDurationHours: Double
    let dailyCostThreshold: Double
    let minimumRefreshInterval: TimeInterval
    
    static let `default` = AppConfiguration(
        basePath: NSHomeDirectory() + "/.claude",
        refreshInterval: 30.0,
        sessionDurationHours: 5.0,
        dailyCostThreshold: 10.0,
        minimumRefreshInterval: 5.0
    )
    
    static func load() -> AppConfiguration {
        // Future: Load from UserDefaults or config file
        return .default
    }
}

// MARK: - Service Protocols
protocol UsageDataService {
    func loadStats() async throws -> UsageStats
    func loadEntries() async throws -> [UsageEntry]
    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats)
    func getDateRange() -> (start: Date, end: Date)
}

protocol SessionMonitorService {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

protocol ConfigurationService {
    var configuration: AppConfiguration { get }
    func updateConfiguration(_ config: AppConfiguration)
}

// MARK: - Service Implementations
final class DefaultUsageDataService: UsageDataService {
    private let client: ClaudeUsageClient
    
    init(configuration: AppConfiguration) {
        self.client = ClaudeUsageClient(
            dataSource: .localFiles(basePath: configuration.basePath)
        )
    }
    
    func loadStats() async throws -> UsageStats {
        let startTime = Date()
        let range = getDateRange()
        let result = try await client.getUsageByDateRange(
            startDate: range.start,
            endDate: range.end
        )
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadStats completed in \(String(format: "%.3f", duration))s")
        #endif
        return result
    }
    
    func loadEntries() async throws -> [UsageEntry] {
        let startTime = Date()
        let result = try await client.getUsageDetails()
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntries completed in \(String(format: "%.3f", duration))s - \(result.count) entries")
        #endif
        return result
    }

    /// Load entries once and calculate stats from them - avoids reading files twice
    func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let startTime = Date()
        let entries = try await client.getUsageDetails()

        #if DEBUG
        let entriesTime = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntriesAndStats - entries loaded in \(String(format: "%.3f", entriesTime))s - \(entries.count) entries")
        #endif

        // Calculate stats from entries using StatisticsAggregator
        let aggregator = StatisticsAggregator()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)

        #if DEBUG
        let totalTime = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadEntriesAndStats completed in \(String(format: "%.3f", totalTime))s")
        #endif

        return (entries, stats)
    }

    func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }

    /// Load only today's entries and stats - fast path for initial display
    func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        let startTime = Date()
        let entries = try await client.getTodayUsageEntries()

        let aggregator = StatisticsAggregator()
        let sessionCount = Set(entries.compactMap { $0.sessionId }).count
        let stats = aggregator.aggregateStatistics(from: entries, sessionCount: sessionCount)

        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[UsageDataService] loadTodayEntriesAndStats completed in \(String(format: "%.3f", duration))s - \(entries.count) entries")
        #endif

        return (entries, stats)
    }
}

final class DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: LiveMonitor
    
    // Cache for session data with short TTL
    private var cachedSession: (session: SessionBlock?, timestamp: Date)?
    private var cachedTokenLimit: (limit: Int?, timestamp: Date)?
    private let cacheTTL: TimeInterval = 2.0 // 2 second cache
    
    init(configuration: AppConfiguration) {
        let config = LiveMonitorConfig(
            claudePaths: [configuration.basePath],
            sessionDurationHours: configuration.sessionDurationHours,
            tokenLimit: nil,
            refreshInterval: 2.0,
            order: .descending
        )
        self.monitor = LiveMonitor(config: config)
    }
    
    func getActiveSession() async -> SessionBlock? {
        let startTime = Date()
        
        // Check cache first
        if let cached = cachedSession,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            #if DEBUG
            print("[SessionMonitorService] getActiveSession returned from cache (age: \(String(format: "%.3f", Date().timeIntervalSince(cached.timestamp)))s)")
            #endif
            return cached.session
        }
        
        // Load fresh data
        let result = await monitor.getActiveBlock()
        
        // Update cache
        cachedSession = (result, Date())
        
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getActiveSession completed in \(String(format: "%.3f", duration))s - session: \(result != nil ? "found" : "none")")
        #endif
        return result
    }
    
    func getBurnRate() async -> BurnRate? {
        let startTime = Date()
        let result = await getActiveSession()?.burnRate
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getBurnRate completed in \(String(format: "%.3f", duration))s")
        #endif
        return result
    }
    
    func getAutoTokenLimit() async -> Int? {
        let startTime = Date()
        
        // Check cache first
        if let cached = cachedTokenLimit,
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            #if DEBUG
            print("[SessionMonitorService] getAutoTokenLimit returned from cache (age: \(String(format: "%.3f", Date().timeIntervalSince(cached.timestamp)))s)")
            #endif
            return cached.limit
        }
        
        // Load fresh data
        let result = await monitor.getAutoTokenLimit()
        
        // Update cache
        cachedTokenLimit = (result, Date())
        
        #if DEBUG
        let duration = Date().timeIntervalSince(startTime)
        print("[SessionMonitorService] getAutoTokenLimit completed in \(String(format: "%.3f", duration))s - limit: \(result ?? 0)")
        #endif
        return result
    }
}

@Observable
final class DefaultConfigurationService: ConfigurationService {
    private(set) var configuration: AppConfiguration
    
    init() {
        self.configuration = AppConfiguration.load()
    }
    
    func updateConfiguration(_ config: AppConfiguration) {
        self.configuration = config
    }
}

// MARK: - Dependency Container
protocol DependencyContainer {
    var usageDataService: UsageDataService { get }
    var sessionMonitorService: SessionMonitorService { get }
    var configurationService: ConfigurationService { get }
    var performanceMetrics: PerformanceMetricsProtocol { get }
}

@MainActor
final class ProductionContainer: DependencyContainer {
    lazy var usageDataService: UsageDataService = {
        DefaultUsageDataService(configuration: configurationService.configuration)
    }()
    
    lazy var sessionMonitorService: SessionMonitorService = {
        // Use ModernHybridSessionMonitor that switches based on feature flag without semaphores
        let hybrid = ModernHybridSessionMonitor(configuration: configurationService.configuration)
        // Wrap with performance monitoring for A/B testing
        return MonitoredSessionService(wrapped: hybrid, metrics: performanceMetrics)
    }()
    
    lazy var configurationService: ConfigurationService = {
        DefaultConfigurationService()
    }()
    
    lazy var performanceMetrics: PerformanceMetricsProtocol = {
        PerformanceMetrics.default
    }()
    
    static let shared = ProductionContainer()
}

// MARK: - Test Container for Unit Testing
#if DEBUG
final class TestContainer: DependencyContainer {
    var usageDataService: UsageDataService
    var sessionMonitorService: SessionMonitorService
    var configurationService: ConfigurationService
    var performanceMetrics: PerformanceMetricsProtocol
    
    init(
        usageDataService: UsageDataService? = nil,
        sessionMonitorService: SessionMonitorService? = nil,
        configurationService: ConfigurationService? = nil,
        performanceMetrics: PerformanceMetricsProtocol? = nil
    ) {
        self.usageDataService = usageDataService ?? MockUsageDataService()
        self.sessionMonitorService = sessionMonitorService ?? MockSessionMonitorService()
        self.configurationService = configurationService ?? DefaultConfigurationService()
        self.performanceMetrics = performanceMetrics ?? NullPerformanceMetrics()
    }
}

// Mock implementations for testing
public final class MockUsageDataService: UsageDataService {
    public var mockStats: UsageStats?
    public var mockEntries: [UsageEntry] = []
    public var shouldThrow = false
    
    public init() {}
    
    public func loadStats() async throws -> UsageStats {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        // For testing, return the mock stats or throw an error
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats provided"])
        }
        return stats
    }
    
    public func loadEntries() async throws -> [UsageEntry] {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        return mockEntries
    }

    public func loadEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats provided"])
        }
        return (mockEntries, stats)
    }

    public func loadTodayEntriesAndStats() async throws -> (entries: [UsageEntry], stats: UsageStats) {
        // Same as loadEntriesAndStats for mock - returns all mock data
        return try await loadEntriesAndStats()
    }

    public func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }
}

final class MockSessionMonitorService: SessionMonitorService {
    var mockSession: SessionBlock?
    var mockBurnRate: BurnRate?
    var mockTokenLimit: Int?
    
    func getActiveSession() -> SessionBlock? { mockSession }
    func getBurnRate() -> BurnRate? { mockBurnRate }
    func getAutoTokenLimit() -> Int? { mockTokenLimit }
}
#endif
