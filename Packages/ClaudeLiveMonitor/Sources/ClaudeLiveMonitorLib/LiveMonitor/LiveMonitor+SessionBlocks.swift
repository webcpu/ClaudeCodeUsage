//
//  LiveMonitor+SessionBlocks.swift
//
//  Session block identification, creation, and calculation logic.
//

import Foundation

// MARK: - Session Block Identification

extension LiveMonitor {

    func identifySessionBlocks(entries: [UsageEntry]) -> [SessionBlock] {
        guard !entries.isEmpty else { return [] }

        let sessionDurationSeconds = config.sessionDurationHours * 60 * 60
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        let now = Date()

        return buildBlocks(from: sortedEntries, sessionDuration: sessionDurationSeconds, now: now)
    }

    private func buildBlocks(from entries: [UsageEntry], sessionDuration: TimeInterval, now: Date) -> [SessionBlock] {
        var blocks: [SessionBlock] = []
        var currentBlockStart: Date?
        var currentBlockEntries: [UsageEntry] = []

        for entry in entries {
            let shouldStartNewBlock = currentBlockStart.map { blockStart in
                shouldSplitBlock(
                    entryTime: entry.timestamp,
                    blockStart: blockStart,
                    lastEntryTime: currentBlockEntries.last?.timestamp,
                    sessionDuration: sessionDuration
                )
            } ?? true

            if shouldStartNewBlock {
                if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
                    if let block = createBlock(startTime: blockStart, entries: currentBlockEntries, now: now, sessionDuration: sessionDuration) {
                        blocks.append(block)
                    }
                }
                currentBlockStart = floorToHour(entry.timestamp)
                currentBlockEntries = [entry]
            } else {
                currentBlockEntries.append(entry)
            }
        }

        if let blockStart = currentBlockStart, !currentBlockEntries.isEmpty {
            if let block = createBlock(startTime: blockStart, entries: currentBlockEntries, now: now, sessionDuration: sessionDuration) {
                blocks.append(block)
            }
        }

        return blocks
    }

    private func shouldSplitBlock(entryTime: Date, blockStart: Date, lastEntryTime: Date?, sessionDuration: TimeInterval) -> Bool {
        let timeSinceBlockStart = entryTime.timeIntervalSince(blockStart)
        let timeSinceLastEntry = lastEntryTime.map { entryTime.timeIntervalSince($0) } ?? 0
        return timeSinceBlockStart > sessionDuration || timeSinceLastEntry > sessionDuration
    }
}

// MARK: - Block Creation

extension LiveMonitor {

    private func createBlock(startTime: Date, entries: [UsageEntry], now: Date, sessionDuration: TimeInterval) -> SessionBlock? {
        guard !entries.isEmpty else { return nil }

        let endTime = startTime.addingTimeInterval(sessionDuration)
        let actualEndTime = entries.last?.timestamp
        let isActive = computeIsActive(actualEndTime: actualEndTime, now: now, endTime: endTime, sessionDuration: sessionDuration)

        let aggregated = aggregateEntries(entries)
        let burnRate = computeBurnRate(tokens: aggregated.tokenCounts.total, cost: aggregated.costUSD, startTime: startTime, actualEndTime: actualEndTime, now: now)
        let projectedUsage = computeProjectedUsage(currentTokens: aggregated.tokenCounts.total, currentCost: aggregated.costUSD, burnRate: burnRate, actualEndTime: actualEndTime, endTime: endTime, now: now)

        return SessionBlock(
            id: UUID().uuidString,
            startTime: startTime,
            endTime: endTime,
            actualEndTime: actualEndTime,
            isActive: isActive,
            isGap: false,
            entries: entries,
            tokenCounts: aggregated.tokenCounts,
            costUSD: aggregated.costUSD,
            models: aggregated.models,
            usageLimitResetTime: aggregated.usageLimitResetTime,
            burnRate: burnRate,
            projectedUsage: projectedUsage
        )
    }
}

// MARK: - Pure Calculations

extension LiveMonitor {

    private func computeIsActive(actualEndTime: Date?, now: Date, endTime: Date, sessionDuration: TimeInterval) -> Bool {
        guard let actualEndTime else { return false }
        return now.timeIntervalSince(actualEndTime) < sessionDuration && now < endTime
    }

    private func aggregateEntries(_ entries: [UsageEntry]) -> (tokenCounts: TokenCounts, costUSD: Double, models: [String], usageLimitResetTime: Date?) {
        let tokenCounts = entries.reduce(TokenCounts.zero) { accumulated, entry in
            TokenCounts(
                inputTokens: accumulated.inputTokens + entry.usage.inputTokens,
                outputTokens: accumulated.outputTokens + entry.usage.outputTokens,
                cacheCreationInputTokens: accumulated.cacheCreationInputTokens + entry.usage.cacheCreationInputTokens,
                cacheReadInputTokens: accumulated.cacheReadInputTokens + entry.usage.cacheReadInputTokens
            )
        }

        let costUSD = entries.reduce(0.0) { $0 + $1.costUSD }
        let models = Array(Set(entries.map(\.model)))
        let usageLimitResetTime = entries.lazy.compactMap(\.usageLimitResetTime).last

        return (tokenCounts, costUSD, models, usageLimitResetTime)
    }

    private func computeBurnRate(tokens: Int, cost: Double, startTime: Date, actualEndTime: Date?, now: Date) -> BurnRate {
        let elapsedMinutes = (actualEndTime ?? now).timeIntervalSince(startTime) / 60
        let tokensPerMinute = elapsedMinutes > 0 ? Int(Double(tokens) / elapsedMinutes) : 0
        let costPerHour = elapsedMinutes > 0 ? (cost / elapsedMinutes) * 60 : 0

        return BurnRate(
            tokensPerMinute: tokensPerMinute,
            tokensPerMinuteForIndicator: tokensPerMinute,
            costPerHour: costPerHour
        )
    }

    private func computeProjectedUsage(currentTokens: Int, currentCost: Double, burnRate: BurnRate, actualEndTime: Date?, endTime: Date, now: Date) -> ProjectedUsage {
        let remainingMinutes = endTime.timeIntervalSince(actualEndTime ?? now) / 60
        let projectedTokens = currentTokens + Int(Double(burnRate.tokensPerMinute) * remainingMinutes)
        let projectedCost = currentCost + (burnRate.costPerHour * remainingMinutes / 60)

        return ProjectedUsage(
            totalTokens: projectedTokens,
            totalCost: projectedCost,
            remainingMinutes: remainingMinutes
        )
    }
}

// MARK: - Date Utilities

extension LiveMonitor {

    func floorToHour(_ date: Date) -> Date {
        let secondsSinceEpoch = date.timeIntervalSince1970
        let secondsInHour = 3600.0
        let flooredSeconds = floor(secondsSinceEpoch / secondsInHour) * secondsInHour
        return Date(timeIntervalSince1970: flooredSeconds)
    }
}

// MARK: - TokenCounts Extension

extension TokenCounts {
    static let zero = TokenCounts(
        inputTokens: 0,
        outputTokens: 0,
        cacheCreationInputTokens: 0,
        cacheReadInputTokens: 0
    )
}
