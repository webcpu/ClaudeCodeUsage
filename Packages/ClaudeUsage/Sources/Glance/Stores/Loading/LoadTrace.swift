//
//  LoadTrace.swift
//  Event-driven load operation tracing
//

import Foundation
import OSLog

// MARK: - Load Speed Classification (OCP: Extensible logging behavior)

private enum LoadSpeed {
    case normal
    case slow

    static func classify(_ duration: TimeInterval) -> LoadSpeed {
        duration > Threshold.slowLoad ? .slow : .normal
    }

    func log(_ message: String, using logger: Logger) {
        switch self {
        case .normal: logger.info("\(message)")
        case .slow: logger.warning("\(message)")
        }
    }
}

// MARK: - Summary Part Providers (OCP: Registry of part builders)

private struct SummaryPartProvider: Sendable {
    let build: @Sendable (LoadTraceState) -> String?

    /// Registry of summary part providers - add new providers here
    static let all: [SummaryPartProvider] = [
        SummaryPartProvider { state in
            state.phaseDurations[.today].map { "today \(DurationFormatter.format($0))" }
        },
        SummaryPartProvider { state in
            state.sessionFound.map { $0 ? "session" : "no session" }
        },
        SummaryPartProvider { state in
            if state.historySkipped { return "history skipped" }
            return state.phaseDurations[.history].map { "history \(DurationFormatter.format($0))" }
        }
    ]
}

// MARK: - Load Trace State (Pure data container)

private struct LoadTraceState: Sendable {
    var phaseStartTimes: [LoadPhase: Date] = [:]
    var phaseDurations: [LoadPhase: TimeInterval] = [:]
    var sessionFound: Bool?
    var sessionCached: Bool = false
    var sessionDuration: TimeInterval = 0
    var tokenLimit: Int?
    var historySkipped: Bool = false

    static let initial = LoadTraceState()
}

// MARK: - Trace Collector

actor LoadTrace {
    static let shared = LoadTrace()

    /// Package-internal initializer for testing
    init() {}

    private let logger = Logger(subsystem: "com.claudecodeusage", category: "DataFlow")

    private var loadStartTime: Date?
    private var state = LoadTraceState.initial

    func start() -> UUID {
        let id = UUID()
        loadStartTime = Date()
        state = .initial
        return id
    }

    func phaseStart(_ phase: LoadPhase) {
        state.phaseStartTimes[phase] = Date()
    }

    func phaseComplete(_ phase: LoadPhase) {
        if let start = state.phaseStartTimes[phase] {
            state.phaseDurations[phase] = Date().timeIntervalSince(start)
        }
    }

    func recordSession(found: Bool, cached: Bool, duration: TimeInterval, tokenLimit: Int?) {
        state.sessionFound = found
        state.sessionCached = cached
        state.sessionDuration = duration
        state.tokenLimit = tokenLimit
    }

    func skipHistory() {
        state.historySkipped = true
    }

    func complete() {
        guard let startTime = loadStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        printSummary(duration: duration)
        state = .initial
    }

    // MARK: - Output

    private func printSummary(duration: TimeInterval) {
        let output = buildSummary(duration: duration)
        LoadSpeed.classify(duration).log(output, using: logger)
    }

    private func buildSummary(duration: TimeInterval) -> String {
        let parts = SummaryPartProvider.all.compactMap { $0.build(state) }
        return formatLoadSummary(duration: duration, parts: parts)
    }

    private func formatLoadSummary(duration: TimeInterval, parts: [String]) -> String {
        let details = parts.isEmpty ? "" : " [\(parts.joined(separator: ", "))]"
        let slow = duration > Threshold.slowLoad ? " [slow]" : ""
        return "Load: \(DurationFormatter.format(duration))\(details)\(slow)"
    }
}

// MARK: - Supporting Types

private enum Threshold {
    static let slowLoad: TimeInterval = 2.0
}

// MARK: - Duration Formatting (OCP: Registry of duration ranges)

private struct DurationRange: Sendable {
    let threshold: TimeInterval
    let format: @Sendable (TimeInterval) -> String

    /// Registry of duration ranges - add new ranges here
    static let ranges: [DurationRange] = [
        DurationRange(threshold: 0.01, format: { _ in "<10ms" }),
        DurationRange(threshold: 1.0, format: { String(format: "%.0fms", $0 * 1000) }),
        DurationRange(threshold: .infinity, format: { String(format: "%.2fs", $0) })
    ]
}

private enum DurationFormatter {
    static func format(_ seconds: TimeInterval) -> String {
        DurationRange.ranges
            .first { seconds < $0.threshold }?
            .format(seconds) ?? String(format: "%.2fs", seconds)
    }
}

// MARK: - Protocol Conformance

extension LoadTrace: LoadTracing {}
