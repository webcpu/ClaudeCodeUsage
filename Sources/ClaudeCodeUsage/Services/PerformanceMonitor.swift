//
//  PerformanceMonitor.swift
//  ClaudeCodeUsage
//
//  Performance monitoring service for tracking slow operations
//

import Foundation
import OSLog

private let performanceLogger = Logger(subsystem: "com.claudecodeusage", category: "Performance")

/// Performance monitoring configuration
public struct PerformanceThresholds {
    public let warningThreshold: TimeInterval
    public let criticalThreshold: TimeInterval
    
    public static let `default` = PerformanceThresholds(
        warningThreshold: 1.0,  // 1 second
        criticalThreshold: 3.0  // 3 seconds
    )
    
    public static let strict = PerformanceThresholds(
        warningThreshold: 0.5,   // 500ms
        criticalThreshold: 1.0   // 1 second
    )
    
    public static let relaxed = PerformanceThresholds(
        warningThreshold: 2.0,   // 2 seconds
        criticalThreshold: 5.0   // 5 seconds
    )
}

/// Performance metrics for an operation
public struct PerformanceMetric: Sendable {
    public let operation: String
    public let duration: TimeInterval
    public let startTime: Date
    public let endTime: Date
    public let metadata: [String: String]
    
    public func isWarning(thresholds: PerformanceThresholds) -> Bool {
        duration > thresholds.warningThreshold
    }
    
    public func isCritical(thresholds: PerformanceThresholds) -> Bool {
        duration > thresholds.criticalThreshold
    }
}

/// Thread-safe performance monitoring service
@globalActor
public actor PerformanceMonitor {
    public static let shared = PerformanceMonitor()
    
    private var metrics: [PerformanceMetric] = []
    private var activeOperations: [String: Date] = [:]
    public var thresholds: PerformanceThresholds = .default
    private let maxMetricsCount = 1000
    
    private init() {}
    
    /// Configure performance thresholds
    public func configure(thresholds: PerformanceThresholds) {
        self.thresholds = thresholds
    }
    
    /// Start tracking an operation
    public func startOperation(_ name: String) -> String {
        let operationId = "\(name)_\(UUID().uuidString)"
        activeOperations[operationId] = Date()
        return operationId
    }
    
    /// End tracking an operation
    public func endOperation(_ operationId: String, metadata: [String: String] = [:]) {
        guard let startTime = activeOperations.removeValue(forKey: operationId) else {
            performanceLogger.warning("Attempted to end unknown operation: \(operationId)")
            return
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let operationName = operationId.components(separatedBy: "_").first ?? operationId
        
        let metric = PerformanceMetric(
            operation: operationName,
            duration: duration,
            startTime: startTime,
            endTime: endTime,
            metadata: metadata
        )
        
        recordMetric(metric)
        logMetric(metric)
    }
    
    /// Measure a synchronous operation
    public func measure<T>(
        _ operation: String,
        metadata: [String: String] = [:],
        block: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        defer {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let metric = PerformanceMetric(
                operation: operation,
                duration: duration,
                startTime: startTime,
                endTime: endTime,
                metadata: metadata
            )
            recordMetric(metric)
            logMetric(metric)
        }
        return try block()
    }
    
    /// Measure an async operation
    public func measure<T>(
        _ operation: String,
        metadata: [String: String] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        defer {
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            let metric = PerformanceMetric(
                operation: operation,
                duration: duration,
                startTime: startTime,
                endTime: endTime,
                metadata: metadata
            )
            recordMetric(metric)
            logMetric(metric)
        }
        return try await block()
    }
    
    /// Get recent performance metrics
    public func getRecentMetrics(limit: Int = 100) -> [PerformanceMetric] {
        Array(metrics.suffix(min(limit, metrics.count)))
    }
    
    /// Get slow operations
    public func getSlowOperations() -> [PerformanceMetric] {
        metrics.filter { $0.isWarning(thresholds: thresholds) || $0.isCritical(thresholds: thresholds) }
    }
    
    /// Get average duration for an operation
    public func getAverageDuration(for operation: String) -> TimeInterval? {
        let operationMetrics = metrics.filter { $0.operation == operation }
        guard !operationMetrics.isEmpty else { return nil }
        
        let totalDuration = operationMetrics.reduce(0) { $0 + $1.duration }
        return totalDuration / Double(operationMetrics.count)
    }
    
    /// Clear all metrics
    public func clearMetrics() {
        metrics.removeAll()
        activeOperations.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func recordMetric(_ metric: PerformanceMetric) {
        metrics.append(metric)
        
        // Keep metrics under limit
        if metrics.count > maxMetricsCount {
            metrics.removeFirst(metrics.count - maxMetricsCount)
        }
    }
    
    private func logMetric(_ metric: PerformanceMetric) {
        let durationMs = Int(metric.duration * 1000)
        let metadataString = metric.metadata.isEmpty ? "" : " | \(metric.metadata)"
        
        if metric.isCritical(thresholds: thresholds) {
            performanceLogger.error("🔴 CRITICAL: '\(metric.operation)' took \(durationMs)ms\(metadataString)")
        } else if metric.isWarning(thresholds: thresholds) {
            performanceLogger.warning("🟡 SLOW: '\(metric.operation)' took \(durationMs)ms\(metadataString)")
        } else {
            performanceLogger.debug("✅ '\(metric.operation)' completed in \(durationMs)ms\(metadataString)")
        }
    }
}

// MARK: - Convenience Extensions

public extension PerformanceMonitor {
    /// Report performance summary
    func generateReport() -> String {
        let slowOps = getSlowOperations()
        let operationGroups = Dictionary(grouping: metrics) { $0.operation }
        
        var report = "=== Performance Report ===\n"
        report += "Total operations: \(metrics.count)\n"
        report += "Slow operations: \(slowOps.count)\n\n"
        
        report += "=== Operation Statistics ===\n"
        for (operation, metrics) in operationGroups.sorted(by: { $0.key < $1.key }) {
            let durations = metrics.map { $0.duration }
            let avg = durations.reduce(0, +) / Double(durations.count)
            let min = durations.min() ?? 0
            let max = durations.max() ?? 0
            
            report += "\(operation):\n"
            report += "  Count: \(metrics.count)\n"
            report += "  Avg: \(Int(avg * 1000))ms\n"
            report += "  Min: \(Int(min * 1000))ms\n"
            report += "  Max: \(Int(max * 1000))ms\n"
        }
        
        if !slowOps.isEmpty {
            report += "\n=== Slow Operations Detail ===\n"
            for op in slowOps.prefix(10) {
                report += "\(op.operation): \(Int(op.duration * 1000))ms at \(op.startTime)\n"
            }
        }
        
        return report
    }
}

// MARK: - Integration with existing services

public extension UsageRepository {
    /// Load stats with performance monitoring
    func getUsageStatsWithMonitoring() async throws -> UsageStats {
        try await PerformanceMonitor.shared.measure(
            "UsageRepository.getUsageStats",
            metadata: ["basePath": basePath]
        ) {
            try await self.getUsageStats()
        }
    }
    
    /// Load entries with performance monitoring
    func getUsageEntriesWithMonitoring(limit: Int? = nil) async throws -> [UsageEntry] {
        try await PerformanceMonitor.shared.measure(
            "UsageRepository.getUsageEntries",
            metadata: ["limit": limit.map { "\($0)" } ?? "unlimited"]
        ) {
            try await self.getUsageEntries(limit: limit)
        }
    }
}