//
//  LiveRenderer+Metrics.swift
//
//  Session, usage, and projection metrics models for the live renderer.
//

import Foundation

// MARK: - Session Metrics

struct SessionMetrics {
    let percentage: Double
    let startTimeFormatted: String
    let endTimeFormatted: String
    let elapsedFormatted: String
    let remainingFormatted: String

    init(block: SessionBlock) {
        let elapsed = Date().timeIntervalSince(block.startTime)
        let total = block.endTime.timeIntervalSince(block.startTime)
        let remaining = max(0, block.endTime.timeIntervalSince(Date()))

        self.percentage = min((elapsed / total) * 100, 100)
        self.startTimeFormatted = Self.formatTime(block.startTime)
        self.endTimeFormatted = Self.formatTime(block.endTime)
        self.elapsedFormatted = Self.formatDuration(elapsed)
        self.remainingFormatted = Self.formatDuration(remaining)
    }

    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date) + " UTC"
    }

    private static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Usage Metrics

struct UsageMetrics {
    let percentage: Double
    let tokensFormatted: String
    let tokensShort: String
    let limitShort: String
    let burnRateFormatted: String
    let burnIndicator: String

    init(block: SessionBlock, tokenLimit: Int) {
        let tokens = block.tokenCounts.total
        let burnRate = block.burnRate.tokensPerMinute

        self.percentage = tokenLimit > 0 ? min(Double(tokens) * 100 / Double(tokenLimit), 100) : 0
        self.tokensFormatted = tokens.formattedWithCommas
        self.tokensShort = tokens.formattedShort
        self.limitShort = tokenLimit.formattedShort
        self.burnRateFormatted = burnRate.formattedWithCommas
        self.burnIndicator = Self.burnIndicator(for: burnRate)
    }

    private static func burnIndicator(for rate: Int) -> String {
        switch rate {
        case 500_001...: ANSIColor.red.wrap("\u{26A1} HIGH")
        case 200_001...500_000: ANSIColor.yellow.wrap("\u{26A1} MEDIUM")
        default: ANSIColor.green.wrap("\u{2713} NORMAL")
        }
    }
}

// MARK: - Projection Metrics

struct ProjectionMetrics {
    let percentage: Double
    let tokensFormatted: String
    let tokensShort: String
    let limitShort: String
    let status: String

    init(block: SessionBlock, tokenLimit: Int) {
        let projectedTokens = block.projectedUsage.totalTokens

        self.percentage = tokenLimit > 0 ? Double(projectedTokens) * 100 / Double(tokenLimit) : 0
        self.tokensFormatted = projectedTokens.formattedWithCommas
        self.tokensShort = projectedTokens.formattedShort
        self.limitShort = tokenLimit.formattedShort
        self.status = Self.status(for: percentage)
    }

    private static func status(for percentage: Double) -> String {
        switch percentage {
        case 100.01...: ANSIColor.red.wrap("\u{274C} WILL EXCEED LIMIT")
        case 90.01...100: ANSIColor.yellow.wrap("\u{26A0}\u{FE0F}  APPROACHING LIMIT")
        default: ANSIColor.green.wrap("\u{2705} WITHIN LIMIT")
        }
    }
}

// MARK: - Number Formatting Extensions

extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }

    var formattedShort: String {
        guard self >= 1000 else { return String(self) }
        return String(format: "%.1fk", Double(self) / 1000.0)
    }
}

extension Double {
    var formatted: String {
        String(format: "%5.1f", self)
    }

    var progressColor: ANSIColor {
        switch self {
        case 90.01...: .red
        case 75.01...90: .yellow
        default: .green
        }
    }
}
