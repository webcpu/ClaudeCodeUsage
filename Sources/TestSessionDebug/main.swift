import Foundation
import ClaudeLiveMonitorLib

// Test with detailed session block analysis
let monitor = LiveMonitor(config: LiveMonitorConfig(
    claudePaths: [NSHomeDirectory() + "/.claude"],
    sessionDurationHours: 5,
    tokenLimit: nil,
    refreshInterval: 2.0,
    order: .descending
))

// Get the raw data first
let projectsPath = NSHomeDirectory() + "/.claude/projects"
let fileManager = FileManager.default

print("Looking for JSONL files...")
if let enumerator = fileManager.enumerator(atPath: projectsPath) {
    while let path = enumerator.nextObject() as? String {
        if path.hasSuffix(".jsonl") {
            let fullPath = "\(projectsPath)/\(path)"
            
            // Get file info
            if let attributes = try? fileManager.attributesOfItem(atPath: fullPath),
               let modDate = attributes[.modificationDate] as? Date {
                let minutesAgo = Date().timeIntervalSince(modDate) / 60
                print("\nFile: \(path)")
                print("  Last modified: \(minutesAgo) minutes ago")
                
                // Parse the file to see entries
                if minutesAgo < 10 { // Only check recent files
                    let contents = try? String(contentsOfFile: fullPath)
                    let lines = contents?.components(separatedBy: .newlines) ?? []
                    var timestamps: [Date] = []
                    
                    for line in lines {
                        if !line.isEmpty,
                           let data = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let timestampMs = json["timestamp"] as? Double {
                            let date = Date(timeIntervalSince1970: timestampMs / 1000)
                            timestamps.append(date)
                        }
                    }
                    
                    if !timestamps.isEmpty {
                        timestamps.sort()
                        let firstEntry = timestamps.first!
                        let lastEntry = timestamps.last!
                        let now = Date()
                        
                        print("  First entry: \(firstEntry)")
                        print("  Last entry: \(lastEntry)")
                        print("  Time since last: \(now.timeIntervalSince(lastEntry) / 60) minutes")
                        
                        // Check session logic
                        let sessionDuration: TimeInterval = 5 * 60 * 60 // 5 hours
                        
                        // Floor start time to hour
                        let secondsSinceEpoch = firstEntry.timeIntervalSince1970
                        let secondsInHour = 3600.0
                        let flooredSeconds = floor(secondsSinceEpoch / secondsInHour) * secondsInHour
                        let startTime = Date(timeIntervalSince1970: flooredSeconds)
                        let endTime = startTime.addingTimeInterval(sessionDuration)
                        
                        print("\n  Session analysis:")
                        print("    Start time (floored): \(startTime)")
                        print("    End time (start + 5hr): \(endTime)")
                        print("    Now: \(now)")
                        
                        // Check the three conditions for isActive
                        let cond1 = true // actualEndTime exists
                        let cond2 = now.timeIntervalSince(lastEntry) < sessionDuration
                        let cond3 = now < endTime
                        
                        print("\n  isActive conditions:")
                        print("    1. Has entries: \(cond1)")
                        print("    2. Recent activity (<5hr): \(cond2)")
                        print("    3. Now < endTime: \(cond3)")
                        print("    => isActive: \(cond1 && cond2 && cond3)")
                        
                        if !cond3 {
                            print("\n  ⚠️ Problem: Session end time is in the past!")
                            print("    This happens when session started early in the hour")
                            print("    and we're now past startTime + sessionDuration")
                        }
                    }
                }
            }
        }
    }
}

print("\n\n=== LiveMonitor Result ===")
if let activeBlock = monitor.getActiveBlock() {
    print("✅ Found active session!")
    print("  Cost: $\(activeBlock.costUSD)")
    print("  Tokens: \(activeBlock.tokenCounts.total)")
    print("  Burn rate: \(activeBlock.burnRate.tokensPerMinute) tokens/min")
} else {
    print("❌ No active session detected")
}