//
//  Debug Live Monitor
//

import Foundation
import ClaudeCodeUsage
import ClaudeLiveMonitorLib

print("Debugging Live Monitor")
print("=" * 40)

// Create live monitor with different session durations
let monitors = [
    ("1 hour", LiveMonitor(config: LiveMonitorConfig(
        claudePaths: [NSHomeDirectory() + "/.claude/projects"],
        sessionDurationHours: 1,
        tokenLimit: nil,
        refreshInterval: 1.0,
        order: .descending
    ))),
    ("5 hours", LiveMonitor(config: LiveMonitorConfig(
        claudePaths: [NSHomeDirectory() + "/.claude/projects"],
        sessionDurationHours: 5,
        tokenLimit: nil,
        refreshInterval: 1.0,
        order: .descending
    ))),
    ("24 hours", LiveMonitor(config: LiveMonitorConfig(
        claudePaths: [NSHomeDirectory() + "/.claude/projects"],
        sessionDurationHours: 24,
        tokenLimit: nil,
        refreshInterval: 1.0,
        order: .descending
    )))
]

for (duration, monitor) in monitors {
    print("\n📊 Testing with session duration: \(duration)")
    
    if let session = monitor.getActiveBlock() {
        print("  ✅ Active session found!")
        print("  • Start: \(session.startTime)")
        print("  • End: \(session.endTime)")
        print("  • Is Active: \(session.isActive)")
        print("  • Cost: $\(String(format: "%.2f", session.costUSD))")
        
        // Calculate time since start
        let timeSinceStart = Date().timeIntervalSince(session.startTime)
        let hoursSinceStart = timeSinceStart / 3600
        print("  • Hours since start: \(String(format: "%.1f", hoursSinceStart))")
    } else {
        print("  ❌ No active session")
    }
}

// Check the actual file modification time
let projectPath = NSHomeDirectory() + "/.claude/projects/-Users-liang-Downloads-Data-tmp-claudia"
let sessionFile = projectPath + "/863dfce2-64d8-4e7d-ad14-b76e9f1e8396.jsonl"

if let attributes = try? FileManager.default.attributesOfItem(atPath: sessionFile),
   let modDate = attributes[.modificationDate] as? Date {
    print("\n📁 Session file info:")
    print("  • Path: \(sessionFile)")
    print("  • Last modified: \(modDate)")
    let timeSinceMod = Date().timeIntervalSince(modDate)
    let minsSinceMod = timeSinceMod / 60
    print("  • Minutes since last update: \(String(format: "%.1f", minsSinceMod))")
}

print("\n" + "=" * 40)

// Helper extension
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}