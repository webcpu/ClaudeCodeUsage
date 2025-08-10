import Foundation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Async Session Monitor Protocol

/// Async version of SessionMonitorService for modern concurrency
protocol AsyncSessionMonitorService {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Actor-based Implementation

final class ActorBasedSessionMonitorService: AsyncSessionMonitorService {
    private let monitor: LiveMonitorActor
    
    init(configuration: AppConfiguration) {
        let config = LiveMonitorConfig(
            claudePaths: [configuration.basePath],
            sessionDurationHours: configuration.sessionDurationHours,
            tokenLimit: nil,
            refreshInterval: 2.0,
            order: .descending
        )
        self.monitor = LiveMonitorActor(config: config)
    }
    
    func getActiveSession() async -> SessionBlock? {
        return await monitor.getActiveBlock()
    }
    
    func getBurnRate() async -> BurnRate? {
        guard let session = await getActiveSession() else { return nil }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(session.startTime)
        let totalCost = session.costUSD
        
        guard elapsed > 0 else { return nil }
        
        let costPerSecond = totalCost / elapsed
        let costPerHour = costPerSecond * 3600
        let tokensPerSecond = Double(session.tokenCounts.total) / elapsed
        let tokensPerMinute = Int(tokensPerSecond * 60)
        
        return BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
    }
    
    func getAutoTokenLimit() async -> Int? {
        return await monitor.getAutoTokenLimit()
    }
}

// MARK: - Adapter for Legacy Code

/// Adapter that bridges between sync and async implementations
final class HybridSessionMonitorService: SessionMonitorService {
    private let asyncService: AsyncSessionMonitorService?
    private let syncService: SessionMonitorService?
    
    init(configuration: AppConfiguration) {
        if FeatureFlags.useActorBasedLiveMonitor {
            self.asyncService = ActorBasedSessionMonitorService(configuration: configuration)
            self.syncService = nil
        } else {
            self.asyncService = nil
            self.syncService = DefaultSessionMonitorService(configuration: configuration)
        }
    }
    
    func getActiveSession() -> SessionBlock? {
        if let asyncService = asyncService {
            // Use async service in sync context with timeout to prevent deadlock
            let semaphore = DispatchSemaphore(value: 0)
            var result: SessionBlock?
            
            Task {
                result = await asyncService.getActiveSession()
                semaphore.signal()
            }
            
            // Wait with timeout (2 seconds)
            let timeout = DispatchTime.now() + .seconds(2)
            if semaphore.wait(timeout: timeout) == .timedOut {
                print("[HybridSessionMonitorService] Warning: getActiveSession timed out")
                return nil
            }
            return result
        } else {
            return syncService?.getActiveSession()
        }
    }
    
    func getBurnRate() -> BurnRate? {
        if let asyncService = asyncService {
            // Use async service in sync context with timeout to prevent deadlock
            let semaphore = DispatchSemaphore(value: 0)
            var result: BurnRate?
            
            Task {
                result = await asyncService.getBurnRate()
                semaphore.signal()
            }
            
            // Wait with timeout (2 seconds)
            let timeout = DispatchTime.now() + .seconds(2)
            if semaphore.wait(timeout: timeout) == .timedOut {
                print("[HybridSessionMonitorService] Warning: getBurnRate timed out")
                return nil
            }
            return result
        } else {
            return syncService?.getBurnRate()
        }
    }
    
    func getAutoTokenLimit() -> Int? {
        if let asyncService = asyncService {
            // Use async service in sync context with timeout to prevent deadlock
            let semaphore = DispatchSemaphore(value: 0)
            var result: Int?
            
            Task {
                result = await asyncService.getAutoTokenLimit()
                semaphore.signal()
            }
            
            // Wait with timeout (2 seconds)
            let timeout = DispatchTime.now() + .seconds(2)
            if semaphore.wait(timeout: timeout) == .timedOut {
                print("[HybridSessionMonitorService] Warning: getAutoTokenLimit timed out")
                return nil
            }
            return result
        } else {
            return syncService?.getAutoTokenLimit()
        }
    }
}

// MARK: - Performance Monitoring

final class MonitoredSessionService: SessionMonitorService {
    private let wrapped: SessionMonitorService
    private let performanceMetrics: PerformanceMetricsProtocol
    
    init(wrapped: SessionMonitorService, metrics: PerformanceMetricsProtocol) {
        self.wrapped = wrapped
        self.performanceMetrics = metrics
    }
    
    func getActiveSession() -> SessionBlock? {
        let start = Date()
        let result = wrapped.getActiveSession()
        let duration = Date().timeIntervalSince(start)
        
        Task {
            await performanceMetrics.record(
                "SessionMonitor.getActiveSession",
                metadata: [
                    "duration": duration,
                    "hasResult": result != nil,
                    "implementation": FeatureFlags.useActorBasedLiveMonitor ? "actor" : "gcd"
                ]
            ) {
                return result
            }
        }
        
        return result
    }
    
    func getBurnRate() -> BurnRate? {
        let start = Date()
        let result = wrapped.getBurnRate()
        let duration = Date().timeIntervalSince(start)
        
        Task {
            await performanceMetrics.record(
                "SessionMonitor.getBurnRate",
                metadata: [
                    "duration": duration,
                    "hasResult": result != nil,
                    "implementation": FeatureFlags.useActorBasedLiveMonitor ? "actor" : "gcd"
                ]
            ) {
                return result
            }
        }
        
        return result
    }
    
    func getAutoTokenLimit() -> Int? {
        let start = Date()
        let result = wrapped.getAutoTokenLimit()
        let duration = Date().timeIntervalSince(start)
        
        Task {
            await performanceMetrics.record(
                "SessionMonitor.getAutoTokenLimit",
                metadata: [
                    "duration": duration,
                    "hasResult": result != nil,
                    "implementation": FeatureFlags.useActorBasedLiveMonitor ? "actor" : "gcd"
                ]
            ) {
                return result
            }
        }
        
        return result
    }
}