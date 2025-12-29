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
        logOutput(output, isSlow: duration > Threshold.slowLoad)
    }

    private func buildSummary(duration: TimeInterval) -> String {
        [
            headerLine,
            todayPhaseLine,
            sessionLine,
            historyPhaseLine,
            footerLine(duration: duration)
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private var headerLine: String {
        "┌─ Data Load " + String(repeating: "─", count: 40)
    }

    private var todayPhaseLine: String {
        let duration = phaseDurations[.today].map { " (\(formatDuration($0)))" } ?? ""
        return "│ Phase 1: Today\(duration)"
    }

    private var sessionLine: String? {
        sessionFound.map { found in
            let status = found ? "active" : "none"
            let timing = sessionCached ? "cached" : formatDuration(sessionDuration)
            let limitInfo = tokenLimit.map { ", limit: \(formatNumber($0))" } ?? ""
            return "│   Session: \(status) [\(timing)]\(limitInfo)"
        }
    }

    private var historyPhaseLine: String {
        if historySkipped {
            return "│ Phase 2: History (skipped - same day)"
        }
        let duration = phaseDurations[.history].map { " (\(formatDuration($0)))" } ?? ""
        return "│ Phase 2: History\(duration)"
    }

    private func footerLine(duration: TimeInterval) -> String {
        let status = duration > Threshold.slowLoad ? " [slow]" : ""
        return "└─ Total: \(formatDuration(duration))\(status) " + String(repeating: "─", count: 28)
    }

    private func logOutput(_ output: String, isSlow: Bool) {
        if isSlow {
            logger.warning("\(output)")
        } else {
            logger.info("\(output)")
        }
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

// MARK: - Supporting Types

enum LoadPhase: String {
    case today = "Today"
    case history = "History"
}

private enum Threshold {
    static let slowLoad: TimeInterval = 2.0
}
