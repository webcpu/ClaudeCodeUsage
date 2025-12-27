//
//  LoadTrace.swift
//  Event-driven load operation tracing
//

import Foundation
import OSLog

// MARK: - Events

enum LoadPhase: String {
    case today = "Today"
    case history = "History"
}

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
    private var tokenLimitCached: Bool = false
    private var tokenLimitDuration: TimeInterval = 0

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

    func recordSession(found: Bool, cached: Bool, duration: TimeInterval) {
        sessionFound = found
        sessionCached = cached
        sessionDuration = duration
    }

    func recordTokenLimit(limit: Int?, cached: Bool, duration: TimeInterval) {
        tokenLimit = limit
        tokenLimitCached = cached
        tokenLimitDuration = duration
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
        tokenLimitCached = false
        tokenLimitDuration = 0
    }

    // MARK: - Output

    private func printSummary(duration: TimeInterval) {
        let isSlow = duration > 2.0
        let durationStr = formatDuration(duration)

        var lines: [String] = []
        lines.append("┌─ Data Load " + String(repeating: "─", count: 40))

        // Phase 1: Today
        let todayDur = phaseDurations[.today].map { " (\(formatDuration($0)))" } ?? ""
        lines.append("│ Phase 1: Today\(todayDur)")

        if let found = sessionFound {
            let sessionStr = found ? "active" : "none"
            let timing = sessionCached ? "cached" : formatDuration(sessionDuration)
            lines.append("│   Session: \(sessionStr) [\(timing)]")
        }

        if let limit = tokenLimit {
            let timing = tokenLimitCached ? "cached" : formatDuration(tokenLimitDuration)
            lines.append("│   TokenLimit: \(formatNumber(limit)) [\(timing)]")
        }

        // Phase 2: History
        let historyDur = phaseDurations[.history].map { " (\(formatDuration($0)))" } ?? ""
        lines.append("│ Phase 2: History\(historyDur)")

        // Footer
        let status = isSlow ? " [slow]" : ""
        lines.append("└─ Total: \(durationStr)\(status) " + String(repeating: "─", count: 28))

        let output = lines.joined(separator: "\n")

        if isSlow {
            logger.warning("\(output)")
        } else {
            logger.info("\(output)")
        }

        #if DEBUG
        print(output)
        #endif
    }

    // MARK: - Formatting

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.01 {
            return "<10ms"
        } else if seconds < 1.0 {
            return String(format: "%.0fms", seconds * 1000)
        } else {
            return String(format: "%.2fs", seconds)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
