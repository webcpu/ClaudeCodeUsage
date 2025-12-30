//
//  HeatmapViewModel+SupportingTypes.swift
//
//  Supporting types for HeatmapViewModel: errors, stats, and factory.
//

import Foundation

// MARK: - Heatmap Error

/// Heatmap-specific error types
public enum HeatmapError: Error, LocalizedError {
    case invalidDateRange(String)
    case dataProcessingFailed(String)
    case configurationInvalid(String)
    case performanceThresholdExceeded

    public var errorDescription: String? {
        switch self {
        case .invalidDateRange(let message):
            return "Invalid date range: \(message)"
        case .dataProcessingFailed(let message):
            return "Data processing failed: \(message)"
        case .configurationInvalid(let message):
            return "Configuration invalid: \(message)"
        case .performanceThresholdExceeded:
            return "Performance threshold exceeded - consider using a smaller date range"
        }
    }
}

// MARK: - Summary Statistics

/// Summary statistics for heatmap data
public struct SummaryStats {
    public let totalCost: Double
    public let daysWithUsage: Int
    public let totalDays: Int
    public let maxDailyCost: Double
    public let averageDailyCost: Double
    public let dateRange: ClosedRange<Date>

    /// Usage frequency as percentage
    public var usageFrequency: Double {
        guard totalDays > 0 else { return 0 }
        return Double(daysWithUsage) / Double(totalDays) * 100
    }

    /// Formatted date range string
    public var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: dateRange.lowerBound)) - \(formatter.string(from: dateRange.upperBound))"
    }
}

// MARK: - Performance Metrics

/// Performance metrics for monitoring
struct PerformanceMetrics {
    var datasetGenerationTime: Double = 0
    var hoverEventCount: Int = 0
    var averageHoverTime: Double = 0

    var summary: String {
        return """
        Dataset Generation: \(String(format: "%.3f", datasetGenerationTime))s
        Hover Events: \(hoverEventCount)
        Avg Hover Time: \(String(format: "%.4f", averageHoverTime))s
        """
    }
}

// MARK: - View Model Factory

/// Factory for creating pre-configured view models
public struct HeatmapViewModelFactory {

    /// Create view model optimized for performance
    @MainActor
    public static func performanceOptimized() -> HeatmapViewModel {
        return HeatmapViewModel(configuration: .performanceOptimized)
    }

    /// Create view model for compact displays
    @MainActor
    public static func compact() -> HeatmapViewModel {
        return HeatmapViewModel(configuration: .compact)
    }

    /// Create view model with custom configuration
    /// - Parameter configuration: Custom configuration
    /// - Returns: Configured view model
    @MainActor
    public static func custom(_ configuration: HeatmapConfiguration) -> HeatmapViewModel {
        return HeatmapViewModel(configuration: configuration)
    }
}
