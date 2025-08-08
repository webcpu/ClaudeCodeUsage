import Foundation
import ClaudeLiveMonitorLib

// Test which session is being detected
let monitor = LiveMonitor(config: LiveMonitorConfig(
    claudePaths: [NSHomeDirectory() + "/.claude"],
    sessionDurationHours: 5,
    tokenLimit: nil,
    refreshInterval: 2.0,
    order: .descending
))

if let activeBlock = monitor.getActiveBlock() {
    print("Found active session!")
    
    // Check which project this session is from by looking at first entry
    if let firstEntry = activeBlock.entries.first {
        print("  First entry time: \(firstEntry.timestamp)")
        print("  Model: \(firstEntry.model)")
        print("  Entry count: \(activeBlock.entries.count)")
    }
    
    print("\nSession details:")
    print("  Cost: $\(activeBlock.costUSD)")
    print("  Tokens: \(activeBlock.tokenCounts.total)")
    print("  Start time: \(activeBlock.startTime)")
    print("  Actual end time: \(activeBlock.actualEndTime ?? Date())")
    print("  Is active: \(activeBlock.isActive)")
} else {
    print("No active session found")
}

// Now check specifically for claudia project
print("\n\n=== Checking claudia project specifically ===")
let claudiaPath = NSHomeDirectory() + "/.claude/projects/-Users-liang-Downloads-Data-tmp-claudia/863dfce2-64d8-4e7d-ad14-b76e9f1e8396.jsonl"

if let contents = try? String(contentsOfFile: claudiaPath) {
    let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
    print("Found \(lines.count) entries in claudia project")
    
    // Check last few entries
    if lines.count > 0 {
        print("\nLast 3 entries:")
        for i in max(0, lines.count - 3)..<lines.count {
            if let data = lines[i].data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let timestampMs = json["timestamp"] as? Double {
                let date = Date(timeIntervalSince1970: timestampMs / 1000)
                let minutesAgo = Date().timeIntervalSince(date) / 60
                print("  Entry \(i): \(minutesAgo) minutes ago")
            }
        }
    }
}