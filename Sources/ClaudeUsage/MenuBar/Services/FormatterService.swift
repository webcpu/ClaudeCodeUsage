//
//  FormatterService.swift
//  Formatting utilities for display values
//

import Foundation

struct FormatterService {

    // MARK: - Token Formatting

    static func formatTokenCount(_ count: Int) -> String {
        TokenThreshold.format(count)
    }

    // MARK: - Percentage Formatting

    static func formatPercentage(_ percentage: Double) -> String {
        "\(Int(percentage))%"
    }

    // MARK: - Time Duration Formatting

    static func formatTimeInterval(_ interval: TimeInterval, totalInterval: TimeInterval) -> String {
        let hours = interval / TimeConstants.secondsPerHour
        let totalHours = totalInterval / TimeConstants.secondsPerHour
        return String(format: "%.1fh / %.0fh", hours, totalHours)
    }

    /// Format countdown time like "Resets in 3 hr 24 min"
    static func formatCountdown(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "Resetting..." }
        let hours = Int(interval / TimeConstants.secondsPerHour)
        let minutes = Int((interval.truncatingRemainder(dividingBy: TimeConstants.secondsPerHour)) / TimeConstants.secondsPerMinute)
        if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        } else {
            return "Resets in \(minutes) min"
        }
    }

    // MARK: - Currency Formatting

    static func formatCurrency(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }

    // MARK: - Rate Formatting

    static func formatTokenRate(_ tokensPerMinute: Int) -> String {
        "\(formatTokenCount(tokensPerMinute)) tokens/min"
    }

    static func formatCostRate(_ costPerHour: Double) -> String {
        "\(formatCurrency(costPerHour))/hr"
    }

    // MARK: - Session Count Formatting

    static func formatSessionCount(_ count: Int) -> String {
        count > 0 ? "\(count) active" : "No active"
    }

    // MARK: - Value with Limit Formatting

    static func formatValueWithLimit<T: BinaryInteger>(_ current: T, limit: T) -> String {
        "\(formatTokenCount(Int(current))) / \(formatTokenCount(Int(limit)))"
    }

    // MARK: - Daily Average Formatting

    static func formatDailyAverage(_ average: Double) -> String {
        formatCurrency(average)
    }

    // MARK: - Large Number Formatting

    static func formatLargeNumber(_ number: Int) -> String {
        formatTokenCount(number)
    }

    // MARK: - Relative Time Formatting

    static func formatRelativeTime(_ date: Date?) -> String {
        guard let date else { return "Never" }
        let interval = Date().timeIntervalSince(date)
        return RelativeTimeThreshold.format(interval)
    }
}

// MARK: - Token Threshold Configuration

private enum TokenThreshold {
    typealias Threshold = (minimum: Int, divisor: Double, suffix: String, format: String)

    static let thresholds: [Threshold] = [
        (minimum: 1_000_000, divisor: 1_000_000, suffix: "M", format: "%.1f"),
        (minimum: 1_000, divisor: 1_000, suffix: "K", format: "%.1f")
    ]

    static func format(_ count: Int) -> String {
        thresholds
            .first { count >= $0.minimum }
            .map { formatWithThreshold(count, threshold: $0) }
            ?? "\(count)"
    }

    private static func formatWithThreshold(_ count: Int, threshold: Threshold) -> String {
        let value = Double(count) / threshold.divisor
        return String(format: "\(threshold.format)\(threshold.suffix)", value)
    }
}

// MARK: - Relative Time Threshold Configuration

private enum RelativeTimeThreshold {
    typealias Threshold = (maxInterval: TimeInterval, divisor: TimeInterval, suffix: String)

    static let thresholds: [Threshold] = [
        (maxInterval: TimeConstants.secondsPerMinute, divisor: 1, suffix: ""),
        (maxInterval: TimeConstants.secondsPerHour, divisor: TimeConstants.secondsPerMinute, suffix: "m ago"),
        (maxInterval: TimeConstants.secondsPerDay, divisor: TimeConstants.secondsPerHour, suffix: "h ago")
    ]

    static func format(_ interval: TimeInterval) -> String {
        thresholds
            .first { interval < $0.maxInterval }
            .map { formatWithThreshold(interval, threshold: $0) }
            ?? formatDays(interval)
    }

    private static func formatWithThreshold(_ interval: TimeInterval, threshold: Threshold) -> String {
        threshold.suffix.isEmpty
            ? "Just now"
            : "\(Int(interval / threshold.divisor))\(threshold.suffix)"
    }

    private static func formatDays(_ interval: TimeInterval) -> String {
        "\(Int(interval / TimeConstants.secondsPerDay))d ago"
    }
}

// MARK: - Time Constants

private enum TimeConstants {
    static let secondsPerMinute: TimeInterval = 60
    static let secondsPerHour: TimeInterval = 3600
    static let secondsPerDay: TimeInterval = 86400
}