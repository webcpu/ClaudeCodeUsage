//
//  FormatterService.swift
//  Composable formatting functions for display values
//

import Foundation

// MARK: - Formatter Type Aliases

typealias Formatter<T> = @Sendable (T) -> String

// MARK: - Formatters Namespace

/// Composable formatting functions organized by category.
/// Each formatter is a pure function that can be composed with `>>>`.
///
/// Example composition:
/// ```
/// let formatTokenRate = Formatters.tokenCount >>> Formatters.appendSuffix(" tokens/min")
/// ```
enum Formatters {

    // MARK: - Token Formatting

    /// Format token count with K/M suffixes for readability
    static let tokenCount: Formatter<Int> = { count in
        TokenThreshold.format(count)
    }

    // MARK: - Percentage Formatting

    /// Format percentage as integer with % suffix
    static let percentage: Formatter<Double> = { percentage in
        "\(Int(percentage))%"
    }

    // MARK: - Currency Formatting

    /// Format amount as USD currency
    static let currency: Formatter<Double> = { amount in
        String(format: "$%.2f", amount)
    }

    // MARK: - Rate Formatting

    /// Format tokens per minute rate
    static let tokenRate: Formatter<Int> = tokenCount >>> appendSuffix(" tokens/min")

    /// Format cost per hour rate
    static let costRate: Formatter<Double> = currency >>> appendSuffix("/hr")

    // MARK: - Session Formatting

    /// Format active session count
    static let sessionCount: Formatter<Int> = { count in
        count > 0 ? "\(count) active" : "No active"
    }

    // MARK: - Composed Formatters (aliases for semantic clarity)

    /// Format daily average cost (composed from currency)
    static let dailyAverage: Formatter<Double> = currency

    /// Format large numbers with K/M suffixes (composed from token count)
    static let largeNumber: Formatter<Int> = tokenCount

    // MARK: - Time Duration Formatting

    /// Format countdown time like "Resets in 3 hr 24 min"
    static let countdown: Formatter<TimeInterval> = { interval in
        guard interval > 0 else { return "Resetting..." }
        let hours = Int(interval / TimeConstants.secondsPerHour)
        let minutes = Int((interval.truncatingRemainder(dividingBy: TimeConstants.secondsPerHour)) / TimeConstants.secondsPerMinute)
        if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        } else {
            return "Resets in \(minutes) min"
        }
    }

    // MARK: - Relative Time Formatting

    /// Format relative time from date (e.g., "5m ago", "2h ago")
    static let relativeTime: Formatter<Date?> = { date in
        guard let date else { return "Never" }
        let interval = Date().timeIntervalSince(date)
        return RelativeTimeThreshold.format(interval)
    }

    // MARK: - Composition Helpers

    /// Create a formatter that appends a suffix to any string
    static func appendSuffix(_ suffix: String) -> Formatter<String> {
        { string in string + suffix }
    }

    // MARK: - Multi-Parameter Formatters

    /// Format a value with its limit (e.g., "1.5K / 10K")
    static func valueWithLimit<T: BinaryInteger>(_ current: T, limit: T) -> String {
        "\(tokenCount(Int(current))) / \(tokenCount(Int(limit)))"
    }

    /// Format time interval with total context
    static func timeInterval(_ interval: TimeInterval, totalInterval: TimeInterval) -> String {
        let hours = interval / TimeConstants.secondsPerHour
        let totalHours = totalInterval / TimeConstants.secondsPerHour
        return String(format: "%.1fh / %.0fh", hours, totalHours)
    }
}

// MARK: - Legacy API (for backward compatibility)

/// Backward-compatible static API wrapping the composable functions.
/// New code should use `Formatters` namespace directly.
enum FormatterService {
    static func formatTokenCount(_ count: Int) -> String {
        Formatters.tokenCount(count)
    }

    static func formatPercentage(_ percentage: Double) -> String {
        Formatters.percentage(percentage)
    }

    static func formatTimeInterval(_ interval: TimeInterval, totalInterval: TimeInterval) -> String {
        Formatters.timeInterval(interval, totalInterval: totalInterval)
    }

    static func formatCountdown(_ interval: TimeInterval) -> String {
        Formatters.countdown(interval)
    }

    static func formatCurrency(_ amount: Double) -> String {
        Formatters.currency(amount)
    }

    static func formatTokenRate(_ tokensPerMinute: Int) -> String {
        Formatters.tokenRate(tokensPerMinute)
    }

    static func formatCostRate(_ costPerHour: Double) -> String {
        Formatters.costRate(costPerHour)
    }

    static func formatSessionCount(_ count: Int) -> String {
        Formatters.sessionCount(count)
    }

    static func formatValueWithLimit<T: BinaryInteger>(_ current: T, limit: T) -> String {
        Formatters.valueWithLimit(current, limit: limit)
    }

    static func formatDailyAverage(_ average: Double) -> String {
        Formatters.dailyAverage(average)
    }

    static func formatLargeNumber(_ number: Int) -> String {
        Formatters.largeNumber(number)
    }

    static func formatRelativeTime(_ date: Date?) -> String {
        Formatters.relativeTime(date)
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
