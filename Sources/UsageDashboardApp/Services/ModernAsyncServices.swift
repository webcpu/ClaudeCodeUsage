//
//  ModernAsyncServices.swift
//  Modern Swift concurrency implementation without semaphores
//

import Foundation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

// MARK: - Async Service Protocol

/// Modern async version of SessionMonitorService
public protocol AsyncSessionMonitorServiceProtocol: Sendable {
    func getActiveSession() async -> SessionBlock?
    func getBurnRate() async -> BurnRate?
    func getAutoTokenLimit() async -> Int?
}

// MARK: - Actor-based Implementation

/// Thread-safe actor implementation
public actor ModernSessionMonitorActor: AsyncSessionMonitorServiceProtocol {
    private let monitor: LiveMonitorActor
    
    public init(configuration: AppConfiguration) {
        let config = LiveMonitorConfig(
            claudePaths: [configuration.basePath],
            sessionDurationHours: configuration.sessionDurationHours,
            tokenLimit: nil,
            refreshInterval: 2.0,
            order: .descending
        )
        self.monitor = LiveMonitorActor(config: config)
    }
    
    public func getActiveSession() async -> SessionBlock? {
        await monitor.getActiveBlock()
    }
    
    public func getBurnRate() async -> BurnRate? {
        guard let session = await getActiveSession() else { return nil }
        
        let now = Date()
        let elapsed = now.timeIntervalSince(session.startTime)
        
        guard elapsed > 0 else { return nil }
        
        let costPerSecond = session.costUSD / elapsed
        let costPerHour = costPerSecond * 3600
        let tokensPerSecond = Double(session.tokenCounts.total) / elapsed
        let tokensPerMinute = Int(tokensPerSecond * 60)
        
        return BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
    }
    
    public func getAutoTokenLimit() async -> Int? {
        await monitor.getAutoTokenLimit()
    }
}

// MARK: - RunLoop Bridge for Legacy Code

/// Bridge for legacy synchronous code using RunLoop instead of semaphores
public final class RunLoopBridge: SessionMonitorService {
    private let asyncService: AsyncSessionMonitorServiceProtocol
    private let timeout: TimeInterval
    
    public init(asyncService: AsyncSessionMonitorServiceProtocol, timeout: TimeInterval = 2.0) {
        self.asyncService = asyncService
        self.timeout = timeout
    }
    
    public func getActiveSession() -> SessionBlock? {
        var result: SessionBlock?
        var taskCompleted = false
        
        Task {
            result = await asyncService.getActiveSession()
            taskCompleted = true
        }
        
        // Use RunLoop to wait for async operation
        let deadline = Date().addingTimeInterval(timeout)
        while !taskCompleted && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
        
        if !taskCompleted {
            print("[RunLoopBridge] getActiveSession timed out after \(timeout) seconds")
        }
        
        return result
    }
    
    public func getBurnRate() -> BurnRate? {
        var result: BurnRate?
        var taskCompleted = false
        
        Task {
            result = await asyncService.getBurnRate()
            taskCompleted = true
        }
        
        // Use RunLoop to wait for async operation
        let deadline = Date().addingTimeInterval(timeout)
        while !taskCompleted && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
        
        if !taskCompleted {
            print("[RunLoopBridge] getBurnRate timed out after \(timeout) seconds")
        }
        
        return result
    }
    
    public func getAutoTokenLimit() -> Int? {
        var result: Int?
        var taskCompleted = false
        
        Task {
            result = await asyncService.getAutoTokenLimit()
            taskCompleted = true
        }
        
        // Use RunLoop to wait for async operation
        let deadline = Date().addingTimeInterval(timeout)
        while !taskCompleted && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
        
        if !taskCompleted {
            print("[RunLoopBridge] getAutoTokenLimit timed out after \(timeout) seconds")
        }
        
        return result
    }
}

// MARK: - Continuation-based Bridge (Alternative)

/// Alternative bridge using CheckedContinuation for one-shot async operations
public final class ContinuationBridge: SessionMonitorService {
    private let asyncService: AsyncSessionMonitorServiceProtocol
    private let timeout: TimeInterval
    
    public init(asyncService: AsyncSessionMonitorServiceProtocol, timeout: TimeInterval = 2.0) {
        self.asyncService = asyncService
        self.timeout = timeout
    }
    
    public func getActiveSession() -> SessionBlock? {
        withTimeoutSync(timeout: timeout) { [asyncService] continuation in
            Task {
                let result = await asyncService.getActiveSession()
                continuation.resume(returning: result)
            }
        }
    }
    
    public func getBurnRate() -> BurnRate? {
        withTimeoutSync(timeout: timeout) { [asyncService] continuation in
            Task {
                let result = await asyncService.getBurnRate()
                continuation.resume(returning: result)
            }
        }
    }
    
    public func getAutoTokenLimit() -> Int? {
        withTimeoutSync(timeout: timeout) { [asyncService] continuation in
            Task {
                let result = await asyncService.getAutoTokenLimit()
                continuation.resume(returning: result)
            }
        }
    }
    
    private func withTimeoutSync<T>(
        timeout: TimeInterval,
        operation: @escaping (CheckedContinuation<T?, Never>) -> Void
    ) -> T? {
        var result: T?
        let group = DispatchGroup()
        group.enter()
        
        Task {
            result = await withCheckedContinuation { continuation in
                operation(continuation)
            }
            group.leave()
        }
        
        let timeoutResult = group.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            print("[ContinuationBridge] Operation timed out after \(timeout) seconds")
            return nil
        }
        
        return result
    }
}

// MARK: - Performance Monitoring Wrapper

/// Async performance monitoring wrapper
public actor PerformanceMonitoringActor: AsyncSessionMonitorServiceProtocol {
    private let wrapped: AsyncSessionMonitorServiceProtocol
    private let metrics: PerformanceMetricsProtocol
    
    public init(wrapped: AsyncSessionMonitorServiceProtocol, metrics: PerformanceMetricsProtocol) {
        self.wrapped = wrapped
        self.metrics = metrics
    }
    
    public func getActiveSession() async -> SessionBlock? {
        let start = Date()
        let result = await wrapped.getActiveSession()
        let duration = Date().timeIntervalSince(start)
        
        _ = await metrics.record(
            "AsyncSessionMonitor.getActiveSession",
            metadata: [
                "duration": duration,
                "hasResult": result != nil,
                "implementation": "actor"
            ]
        ) {
            return result
        }
        
        return result
    }
    
    public func getBurnRate() async -> BurnRate? {
        let start = Date()
        let result = await wrapped.getBurnRate()
        let duration = Date().timeIntervalSince(start)
        
        _ = await metrics.record(
            "AsyncSessionMonitor.getBurnRate",
            metadata: [
                "duration": duration,
                "hasResult": result != nil,
                "implementation": "actor"
            ]
        ) {
            return result
        }
        
        return result
    }
    
    public func getAutoTokenLimit() async -> Int? {
        let start = Date()
        let result = await wrapped.getAutoTokenLimit()
        let duration = Date().timeIntervalSince(start)
        
        _ = await metrics.record(
            "AsyncSessionMonitor.getAutoTokenLimit",
            metadata: [
                "duration": duration,
                "hasResult": result != nil,
                "implementation": "actor"
            ]
        ) {
            return result
        }
        
        return result
    }
}

// MARK: - Modern Feature Flag Based Service

/// Modern implementation that switches based on feature flags without semaphores
public final class ModernHybridSessionMonitor: SessionMonitorService {
    private let service: SessionMonitorService
    
    public init(configuration: AppConfiguration) {
        if FeatureFlags.useActorBasedLiveMonitor {
            // Use modern actor-based implementation with RunLoop bridging
            let actor = ModernSessionMonitorActor(configuration: configuration)
            self.service = RunLoopBridge(asyncService: actor, timeout: 2.0)
        } else {
            // Use legacy GCD-based implementation
            self.service = DefaultSessionMonitorService(configuration: configuration)
        }
    }
    
    public func getActiveSession() -> SessionBlock? {
        service.getActiveSession()
    }
    
    public func getBurnRate() -> BurnRate? {
        service.getBurnRate()
    }
    
    public func getAutoTokenLimit() -> Int? {
        service.getAutoTokenLimit()
    }
}