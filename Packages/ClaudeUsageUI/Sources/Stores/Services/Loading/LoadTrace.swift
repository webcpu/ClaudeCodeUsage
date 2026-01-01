//
//  LoadTrace.swift
//  Event-driven load operation tracing
//

import Foundation
import OSLog

// MARK: - Trace Collector

actor LoadTrace {
    static let shared = LoadTrace()

    private let logger = Logger(subsystem: "com.claudecodeusage", category: "DataFlow")

    private var loadStartTime: Date?
    private var phaseStartTimes: [LoadPhase: Date] = [:]
    private var phaseDurations: [LoadPhase: TimeInterval] = [:]

    // Session monitor state
    private var sessionFound: Bool?
    private var sessionCached: Bool = false
    private var sessionDuration: TimeInterval = 0
    private var tokenLimit: Int?
    private var historySkipped: Bool = false

    func start() -> UUID {
        let id = UUID()
        loadStartTime = Date()
        resetState()
        return id
    }

    func phaseStart(_ phase: LoadPhase) {
        phaseStartTimes[phase] = Date()
    }

    func phaseComplete(_ phase: LoadPhase) {
        if let start = phaseStartTimes[phase] {
            phaseDurations[phase] = Date().timeIntervalSince(start)
        }
    }

    func recordSession(found: Bool, cached: Bool, duration: TimeInterval, tokenLimit: Int?) {
        sessionFound = found
        sessionCached = cached
        sessionDuration = duration
        self.tokenLimit = tokenLimit
    }

    func skipHistory() {
        historySkipped = true
    }

    func complete() {
        guard let startTime = loadStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        printSummary(duration: duration)
        resetState()
    }

    // MARK: - State Management

    private func resetState() {
        phaseStartTimes = [:]
        phaseDurations = [:]
        sessionFound = nil
        sessionCached = false
        sessionDuration = 0
        tokenLimit = nil
        historySkipped = false
    }

    // MARK: - Output

    private func printSummary(duration: TimeInterval) {
        let output = buildSummary(duration: duration)
        let isSlow = duration > Threshold.slowLoad
        if isSlow {
            logger.warning("\(output)")
        } else {
            logger.info("\(output)")
        }
    }

    private func buildSummary(duration: TimeInterval) -> String {
        var parts: [String] = []

        // Today phase
        if let todayDuration = phaseDurations[.today] {
            parts.append("today \(formatDuration(todayDuration))")
        }

        // Session info
        if let found = sessionFound {
            let status = found ? "session" : "no session"
            parts.append(status)
        }

        // History phase
        if historySkipped {
            parts.append("history skipped")
        } else if let historyDuration = phaseDurations[.history] {
            parts.append("history \(formatDuration(historyDuration))")
        }

        let details = parts.isEmpty ? "" : " [\(parts.joined(separator: ", "))]"
        let slow = duration > Threshold.slowLoad ? " [slow]" : ""
        return "Load: \(formatDuration(duration))\(details)\(slow)"
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        DurationFormatter.format(seconds)
    }
}

// MARK: - Supporting Types

enum LoadPhase: String {
    case today = "Today"
    case history = "History"
}

private enum Threshold {
    static let slowLoad: TimeInterval = 2.0
}

// MARK: - Pure Formatters

private enum DurationFormatter {
    static func format(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<0.01: "<10ms"
        case ..<1.0: String(format: "%.0fms", seconds * 1000)
        default: String(format: "%.2fs", seconds)
        }
    }
}
