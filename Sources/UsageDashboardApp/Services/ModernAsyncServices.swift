//
//  ModernAsyncServices.swift
//  Modern Swift concurrency implementation without semaphores
//

import Foundation
import ClaudeCodeUsageKit
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

// MARK: - Efficient Bridge for Legacy Code

/// Bridge for legacy synchronous code using efficient semaphore-based blocking
public final class EfficientBridge: SessionMonitorService {
    private let asyncService: AsyncSessionMonitorServiceProtocol
    private let timeout: TimeInterval
    
    public init(asyncService: AsyncSessionMonitorServiceProtocol, timeout: TimeInterval = 2.0) {
        self.asyncService = asyncService
        self.timeout = timeout
    }
    
    public func getActiveSession() -> SessionBlock? {
        return runBlockingWithTimeout {
            await self.asyncService.getActiveSession()
        } ?? nil
    }
    
    public func getBurnRate() -> BurnRate? {
        return runBlockingWithTimeout {
            await self.asyncService.getBurnRate()
        } ?? nil
    }
    
    public func getAutoTokenLimit() -> Int? {
        return runBlockingWithTimeout {
            await self.asyncService.getAutoTokenLimit()
        } ?? nil
    }
    
    /// Efficiently run async code synchronously with timeout
    private func runBlockingWithTimeout<T>(_ operation: @escaping () async -> T?) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T?
        var taskHandle: Task<Void, Never>?
        
        taskHandle = Task {
            result = await operation()
            semaphore.signal()
        }
        
        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        
        if timeoutResult == .timedOut {
            taskHandle?.cancel()
            print("[EfficientBridge] Operation timed out after \(timeout) seconds")
            return nil
        }
        
        return result
    }
}

/// Legacy compatibility alias
public typealias RunLoopBridge = EfficientBridge

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
@MainActor
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
    
    public func getActiveSession() async -> SessionBlock? {
        await service.getActiveSession()
    }
    
    public func getBurnRate() async -> BurnRate? {
        await service.getBurnRate()
    }
    
    public func getAutoTokenLimit() async -> Int? {
        await service.getAutoTokenLimit()
    }
}
