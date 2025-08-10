//
//  DependencyContainer.swift
//  Dependency injection container for clean architecture
//

import Foundation
import Observation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

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
    func getDateRange() -> (start: Date, end: Date)
}

protocol SessionMonitorService {
    func getActiveSession() -> SessionBlock?
    func getBurnRate() -> BurnRate?
    func getAutoTokenLimit() -> Int?
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
        let range = getDateRange()
        return try await client.getUsageByDateRange(
            startDate: range.start,
            endDate: range.end
        )
    }
    
    func getDateRange() -> (start: Date, end: Date) {
        TimeRange.allTime.dateRange
    }
}

final class DefaultSessionMonitorService: SessionMonitorService {
    private let monitor: LiveMonitor
    
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
    
    func getActiveSession() -> SessionBlock? {
        monitor.getActiveBlock()
    }
    
    func getBurnRate() -> BurnRate? {
        getActiveSession()?.burnRate
    }
    
    func getAutoTokenLimit() -> Int? {
        monitor.getAutoTokenLimit()
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
final class MockUsageDataService: UsageDataService {
    var mockStats: UsageStats?
    var shouldThrow = false
    
    func loadStats() async throws -> UsageStats {
        if shouldThrow {
            throw NSError(domain: "MockError", code: 1)
        }
        // For testing, return the mock stats or throw an error
        guard let stats = mockStats else {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No mock stats provided"])
        }
        return stats
    }
    
    func getDateRange() -> (start: Date, end: Date) {
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