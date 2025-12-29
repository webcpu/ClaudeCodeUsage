//
//  main.swift
//  ClaudeMonitorCLI
//
//  Command-line interface for Claude usage monitoring
//

import Foundation
import ClaudeUsageData

@main
struct ClaudeMonitorCLI {
    static func main() async {
        print("Claude Usage Monitor")
        print("====================")

        let repository = UsageRepositoryImpl()
        let sessionMonitor = SessionMonitorImpl()

        do {
            // Get today's stats
            let entries = try await repository.getTodayEntries()
            let stats = UsageAggregator.aggregate(entries)

            print("\nToday's Usage:")
            print("  Cost: $\(String(format: "%.2f", stats.totalCost))")
            print("  Tokens: \(stats.totalTokens)")
            print("  Sessions: \(stats.sessionCount)")

            // Check for active session
            if let session = await sessionMonitor.getActiveSession() {
                print("\nActive Session:")
                print("  Duration: \(Int(session.durationMinutes)) min")
                print("  Cost: $\(String(format: "%.2f", session.costUSD))")
                print("  Tokens: \(session.tokens.total)")
                print("  Burn Rate: \(session.burnRate.tokensPerMinute) tok/min")
            } else {
                print("\nNo active session")
            }

        } catch {
            print("Error: \(error)")
        }
    }
}
