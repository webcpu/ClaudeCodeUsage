//
//  PerformanceMetrics.swift
//  ClaudeCodeUsage
//
//  Performance monitoring and metrics collection
//

import Foundation

// MARK: - Protocol Definition

/// Protocol for performance metrics collection
public protocol PerformanceMetricsProtocol {
    func record<T>(
        _ operation: String,
        metadata: [String: Any],
        block: () async throws -> T
    ) async rethrows -> T
    
    func getStats(for operation: String) async -> MetricStats?
    func getAllStats() async -> [MetricStats]
    func clearMetrics(for operation: String?) async
    func exportMetrics() async -> Data?
    func generateReport() async -> String
}

/// Null implementation for testing or when metrics are disabled
public actor NullPerformanceMetrics: PerformanceMetricsProtocol {
    public init() {}
    
    public func record<T>(
        _ operation: String,
        metadata: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        try await block()
    }
    
    public func getStats(for operation: String) async -> MetricStats? { nil }
    public func getAllStats() async -> [MetricStats] { [] }
    public func clearMetrics(for operation: String? = nil) async {}
    public func exportMetrics() async -> Data? { nil }
    public func generateReport() async -> String { "No metrics collected" }
}

/// Performance metric data
public struct MetricData {
    public let operation: String
    public let duration: TimeInterval
    public let timestamp: Date
    public let metadata: [String: Any]
    
    public var formattedDuration: String {
        if duration < 0.001 {
            return String(format: "%.2fµs", duration * 1_000_000)
        } else if duration < 1.0 {
            return String(format: "%.2fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

/// Performance metrics statistics
public struct MetricStats {
    public let operation: String
    public let count: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let minDuration: TimeInterval
    public let maxDuration: TimeInterval
    public let p50Duration: TimeInterval
    public let p95Duration: TimeInterval
    public let p99Duration: TimeInterval
    
    public var formattedAverage: String {
        formatDuration(averageDuration)
    }
    
    public var formattedP95: String {
        formatDuration(p95Duration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return String(format: "%.2fµs", duration * 1_000_000)
        } else if duration < 1.0 {
            return String(format: "%.2fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

/// Performance metrics collector
public actor PerformanceMetrics: PerformanceMetricsProtocol {
    private var metrics: [String: [MetricData]] = [:]
    private let maxMetricsPerOperation: Int
    private let enabled: Bool
    
    /// Shared instance for backward compatibility
    /// @available(*, deprecated, message: "Use dependency injection instead of singleton")
    public static let shared = PerformanceMetrics()
    
    /// Default instance for dependency injection
    public static let `default` = PerformanceMetrics()
    
    public init(maxMetricsPerOperation: Int = 1000, enabled: Bool = true) {
        self.maxMetricsPerOperation = maxMetricsPerOperation
        self.enabled = enabled
    }
    
    /// Record a performance metric
    public func record<T>(
        _ operation: String,
        metadata: [String: Any] = [:],
        block: () async throws -> T
    ) async rethrows -> T {
        guard enabled else {
            return try await block()
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Task {
                await self.addMetric(
                    operation: operation,
                    duration: duration,
                    metadata: metadata
                )
            }
        }
        
        return try await block()
    }
    
    /// Record a synchronous performance metric (not part of protocol)
    /// This is a convenience method for sync operations
    public func recordSync<T>(
        _ operation: String,
        metadata: [String: Any] = [:],
        block: () throws -> T
    ) rethrows -> T {
        guard enabled else {
            return try block()
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - start
            Task {
                await self.addMetric(
                    operation: operation,
                    duration: duration,
                    metadata: metadata
                )
            }
        }
        
        return try block()
    }
    
    /// Add a metric
    private func addMetric(operation: String, duration: TimeInterval, metadata: [String: Any]) {
        let metric = MetricData(
            operation: operation,
            duration: duration,
            timestamp: Date(),
            metadata: metadata
        )
        
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        
        metrics[operation]?.append(metric)
        
        // Limit stored metrics per operation
        if let count = metrics[operation]?.count, count > maxMetricsPerOperation {
            metrics[operation]?.removeFirst(count - maxMetricsPerOperation)
        }
        
        #if DEBUG
        if duration > 1.0 {
            print("⚠️ [Performance] Slow operation '\(operation)': \(metric.formattedDuration)")
        }
        #endif
    }
    
    /// Get statistics for an operation
    public func getStats(for operation: String) -> MetricStats? {
        guard let operationMetrics = metrics[operation], !operationMetrics.isEmpty else {
            return nil
        }
        
        let durations = operationMetrics.map { $0.duration }.sorted()
        let count = durations.count
        let total = durations.reduce(0, +)
        
        return MetricStats(
            operation: operation,
            count: count,
            totalDuration: total,
            averageDuration: total / Double(count),
            minDuration: durations.first ?? 0,
            maxDuration: durations.last ?? 0,
            p50Duration: percentile(durations, 0.5),
            p95Duration: percentile(durations, 0.95),
            p99Duration: percentile(durations, 0.99)
        )
    }
    
    /// Get all operation statistics
    public func getAllStats() -> [MetricStats] {
        metrics.keys.compactMap { getStats(for: $0) }
            .sorted { $0.totalDuration > $1.totalDuration }
    }
    
    /// Clear metrics for an operation
    public func clearMetrics(for operation: String? = nil) {
        if let operation = operation {
            metrics.removeValue(forKey: operation)
        } else {
            metrics.removeAll()
        }
    }
    
    /// Export metrics as JSON
    public func exportMetrics() -> Data? {
        let stats = getAllStats().map { stat in
            [
                "operation": stat.operation,
                "count": stat.count,
                "totalDuration": stat.totalDuration,
                "averageDuration": stat.averageDuration,
                "minDuration": stat.minDuration,
                "maxDuration": stat.maxDuration,
                "p50Duration": stat.p50Duration,
                "p95Duration": stat.p95Duration,
                "p99Duration": stat.p99Duration
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: stats, options: .prettyPrinted)
    }
    
    /// Generate performance report
    public func generateReport() -> String {
        let stats = getAllStats()
        
        guard !stats.isEmpty else {
            return "No performance metrics collected"
        }
        
        var report = "Performance Metrics Report\n"
        report += "========================\n\n"
        
        for stat in stats {
            report += "Operation: \(stat.operation)\n"
            report += "  Count: \(stat.count)\n"
            report += "  Average: \(stat.formattedAverage)\n"
            report += "  P95: \(stat.formattedP95)\n"
            report += "  Min: \(formatDuration(stat.minDuration))\n"
            report += "  Max: \(formatDuration(stat.maxDuration))\n"
            report += "\n"
        }
        
        // Identify slow operations
        let slowOps = stats.filter { $0.p95Duration > 1.0 }
        if !slowOps.isEmpty {
            report += "⚠️ Slow Operations (P95 > 1s):\n"
            for op in slowOps {
                report += "  - \(op.operation): \(op.formattedP95)\n"
            }
        }
        
        return report
    }
    
    // MARK: - Helpers
    
    private func percentile(_ sortedArray: [TimeInterval], _ percentile: Double) -> TimeInterval {
        guard !sortedArray.isEmpty else { return 0 }
        
        let index = Int(Double(sortedArray.count - 1) * percentile)
        return sortedArray[index]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return String(format: "%.2fµs", duration * 1_000_000)
        } else if duration < 1.0 {
            return String(format: "%.2fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

// MARK: - Integration Extensions

extension AsyncUsageRepository {
    /// Get usage stats with performance monitoring
    /// @available(*, deprecated, message: "Use getUsageStats() with metrics injected via init")
    public func getUsageStatsWithMetrics() async throws -> UsageStats {
        // For backward compatibility, use shared metrics if no metrics injected
        if let metrics = performanceMetrics {
            return try await metrics.record("UsageRepository.getUsageStats", metadata: [:]) {
                try await self.getUsageStats()
            }
        } else {
            // Fallback to shared for backward compatibility
            return try await PerformanceMetrics.shared.record("UsageRepository.getUsageStats", metadata: [:]) {
                try await self.getUsageStats()
            }
        }
    }
}

// Extension for UsageViewModel is defined in the UsageDashboardApp target
// where UsageViewModel exists

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

public struct PerformanceOverlay: View {
    @State private var stats: [MetricStats] = []
    @State private var isExpanded = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .trailing) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Metrics")
                        .font(.caption.bold())
                    
                    ForEach(stats.prefix(5), id: \.operation) { stat in
                        HStack {
                            Text(stat.operation)
                                .font(.caption2)
                            Spacer()
                            Text("Avg: \(stat.formattedAverage)")
                                .font(.caption2.monospaced())
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Button(action: toggleExpanded) {
                Image(systemName: "speedometer")
                    .font(.caption)
                    .padding(4)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
        }
        .onAppear(perform: loadStats)
    }
    
    private func toggleExpanded() {
        isExpanded.toggle()
        if isExpanded {
            loadStats()
        }
    }
    
    private func loadStats() {
        Task {
            stats = await PerformanceMetrics.shared.getAllStats()
        }
    }
}
#endif