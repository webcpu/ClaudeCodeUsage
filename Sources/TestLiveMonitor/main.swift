//
//  Test Live Monitor Integration
//

import Foundation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

print("Testing ClaudeLiveMonitor Integration")
print("=" * 40)

// Create live monitor
let monitor = LiveMonitor(config: LiveMonitorConfig(
    claudePaths: [NSHomeDirectory() + "/.claude/projects"],
    sessionDurationHours: 5,
    tokenLimit: nil,
    refreshInterval: 1.0,
    order: .descending
))

// Get active session
let activeSession = monitor.getActiveBlock()

if let session = activeSession {
    print("\n🟢 ACTIVE SESSION DETECTED")
    print("  • Session ID: \(session.id)")
    print("  • Start Time: \(session.startTime)")
    print("  • Is Active: \(session.isActive)")
    print("  • Cost: \(session.costUSD.asCurrency)")
    print("  • Tokens: \(session.tokenCounts.total)")
    print("  • Models: \(session.models.joined(separator: ", "))")
    
    print("\n🔥 BURN RATE")
    print("  • Tokens/min: \(session.burnRate.tokensPerMinute)")
    print("  • Cost/hour: $\(String(format: "%.2f", session.burnRate.costPerHour))")
    
    print("\n📊 PROJECTED USAGE")
    print("  • Total Tokens: \(session.projectedUsage.totalTokens)")
    print("  • Total Cost: $\(String(format: "%.2f", session.projectedUsage.totalCost))")
    print("  • Remaining Minutes: \(Int(session.projectedUsage.remainingMinutes))")
    
    // Test integration with ClaudeUsageClient
    print("\n📈 COMBINED DATA")
    let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
    
    let group = DispatchGroup()
    var stats: UsageStats?
    
    group.enter()
    Task {
        do {
            let range = TimeRange.allTime.dateRange
            stats = try await client.getUsageByDateRange(
                startDate: range.start,
                endDate: range.end
            )
        } catch {
            print("Error loading stats: \(error)")
        }
        group.leave()
    }
    
    group.wait()
    
    if let stats = stats {
        // Get today's cost
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        
        if let todayUsage = stats.byDate.first(where: { $0.date == todayString }) {
            print("  • Today's Total Cost: \(todayUsage.totalCost.asCurrency)")
            print("  • Active Session Cost: \(session.costUSD.asCurrency)")
            let percentOfToday = (session.costUSD / todayUsage.totalCost) * 100
            print("  • Active Session is \(String(format: "%.1f", percentOfToday))% of today's usage")
        }
    }
} else {
    print("\n⚠️ No active session detected")
    print("Start a Claude Code session to see live monitoring in action")
}

print("\n" + "=" * 40)
print("✅ Live monitor integration test complete!")

// Helper extensions
extension Double {
    var asCurrency: String {
        return String(format: "$%.2f", self)
    }
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}