//
//  SessionDetector.swift
//  Pure domain logic for detecting session boundaries
//

import Foundation

// MARK: - SessionDetector

/// Detects session boundaries from usage entries.
///
/// Pure domain logic with no I/O or side effects.
/// All methods are deterministic given the same inputs.
public struct SessionDetector: Sendable {
    public let sessionDurationHours: Double

    public init(sessionDurationHours: Double = 5.0) {
        self.sessionDurationHours = sessionDurationHours
    }

    // MARK: - Public API

    /// Detects all session blocks from sorted usage entries.
    public func detectSessions(from entries: [UsageEntry], now: Date) -> [SessionBlock] {
        guard !entries.isEmpty else { return [] }
        let groups = splitAtSessionGaps(entries)
        return mapGroupsToBlocks(groups, now: now)
    }

    /// Finds the most recent active session from detected blocks.
    public func findActiveSession(in blocks: [SessionBlock]) -> SessionBlock? {
        blocks
            .filter(\.isActive)
            .max { ($0.actualEndTime ?? $0.startTime) < ($1.actualEndTime ?? $1.startTime) }
    }

    /// Returns max tokens from completed (inactive) sessions.
    public func maxTokensFromCompletedSessions(_ blocks: [SessionBlock]) -> Int {
        blocks
            .filter { !$0.isActive }
            .map(\.tokens.total)
            .max() ?? 0
    }
}

// MARK: - Session Gap Detection

private extension SessionDetector {
    func splitAtSessionGaps(_ entries: [UsageEntry]) -> [[UsageEntry]] {
        guard !entries.isEmpty else { return [] }
        let splitIndices = findSplitIndices(in: entries)
        return partitionEntries(entries, at: splitIndices)
    }

    func findSplitIndices(in entries: [UsageEntry]) -> [Int] {
        zip(entries, entries.dropFirst())
            .enumerated()
            .filter { hasSessionGap(from: $0.element.0, to: $0.element.1) }
            .map { $0.offset + 1 }
    }

    func partitionEntries(_ entries: [UsageEntry], at splitIndices: [Int]) -> [[UsageEntry]] {
        let boundaries = [0] + splitIndices + [entries.count]
        return zip(boundaries, boundaries.dropFirst())
            .map { start, end in Array(entries[start..<end]) }
    }

    func hasSessionGap(from previous: UsageEntry, to next: UsageEntry) -> Bool {
        next.timestamp.timeIntervalSince(previous.timestamp) > sessionDurationSeconds
    }
}

// MARK: - Block Mapping

private extension SessionDetector {
    func mapGroupsToBlocks(_ groups: [[UsageEntry]], now: Date) -> [SessionBlock] {
        guard !groups.isEmpty else { return [] }
        let historicalBlocks = groups.dropLast().compactMap { createHistoricalBlock($0, now: now) }
        let finalBlock = groups.last.flatMap { createFinalBlock($0, now: now) }
        return historicalBlocks + [finalBlock].compactMap { $0 }
    }

    /// Historical blocks are always inactive - completed sessions.
    func createHistoricalBlock(_ entries: [UsageEntry], now: Date) -> SessionBlock? {
        guard let sessionStart = entries.first?.timestamp else { return nil }
        return createBlock(entries: entries, displayStartTime: sessionStart, isActive: false, now: now)
    }

    /// Final block may be active if recent activity detected.
    func createFinalBlock(_ entries: [UsageEntry], now: Date) -> SessionBlock? {
        guard let sessionStart = entries.first?.timestamp else { return nil }
        let isActive = hasRecentActivity(entries: entries, now: now)
        let displayTime = isActive
            ? rollingWindowStartTime(from: sessionStart, now: now)
            : sessionStart
        return createBlock(entries: entries, displayStartTime: displayTime, isActive: isActive, now: now)
    }

    func hasRecentActivity(entries: [UsageEntry], now: Date) -> Bool {
        guard let lastEntryTime = entries.last?.timestamp else { return false }
        return now.timeIntervalSince(lastEntryTime) < sessionDurationSeconds
    }
}

// MARK: - Block Creation

private extension SessionDetector {
    func createBlock(
        entries: [UsageEntry],
        displayStartTime: Date,
        isActive: Bool,
        now: Date
    ) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        return SessionBlock(
            id: UUID().uuidString,
            startTime: displayStartTime,
            endTime: displayStartTime.addingTimeInterval(sessionDurationSeconds),
            actualEndTime: entries.last?.timestamp,
            isActive: isActive,
            entries: entries,
            tokens: aggregateTokens(from: entries),
            costUSD: aggregateCost(from: entries),
            models: uniqueModels(from: entries),
            burnRate: calculateBurnRate(entries: entries)
        )
    }

    /// Rolling window for active sessions using modulo arithmetic.
    func rollingWindowStartTime(from sessionStart: Date, now: Date) -> Date {
        let totalDuration = now.timeIntervalSince(sessionStart)
        let elapsedInCurrentWindow = totalDuration.truncatingRemainder(dividingBy: sessionDurationSeconds)
        return now.addingTimeInterval(-elapsedInCurrentWindow)
    }
}

// MARK: - Aggregations

private extension SessionDetector {
    func aggregateTokens(from entries: [UsageEntry]) -> TokenCounts {
        entries.reduce(TokenCounts.zero) { $0 + $1.tokens }
    }

    func aggregateCost(from entries: [UsageEntry]) -> Double {
        entries.reduce(0.0) { $0 + $1.costUSD }
    }

    func uniqueModels(from entries: [UsageEntry]) -> [String] {
        Array(Set(entries.map(\.model)))
    }
}

// MARK: - Burn Rate

private extension SessionDetector {
    func calculateBurnRate(entries: [UsageEntry]) -> BurnRate {
        guard let duration = sessionDuration(from: entries),
              duration > Constants.minimumDuration else {
            return .zero
        }
        let totalTokens = entries.reduce(0) { $0 + $1.totalTokens }
        let totalCost = aggregateCost(from: entries)
        return BurnRate(
            tokensPerMinute: Int(Double(totalTokens) / (duration / 60)),
            costPerHour: totalCost / (duration / 3600)
        )
    }

    func sessionDuration(from entries: [UsageEntry]) -> TimeInterval? {
        guard let first = entries.first, let last = entries.last, entries.count >= 2 else {
            return nil
        }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }
}

// MARK: - Constants

private extension SessionDetector {
    var sessionDurationSeconds: TimeInterval {
        sessionDurationHours * 3600
    }

    enum Constants {
        static let minimumDuration: TimeInterval = 60
    }
}
