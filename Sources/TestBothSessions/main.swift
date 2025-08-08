import Foundation
import ClaudeLiveMonitorLib

print("Testing session detection for both projects")
print(String(repeating: "=", count: 50))

// Check claudia project directly
let claudiaFile = NSHomeDirectory() + "/.claude/projects/-Users-liang-Downloads-Data-tmp-claudia/863dfce2-64d8-4e7d-ad14-b76e9f1e8396.jsonl"
let ccusageFile = NSHomeDirectory() + "/.claude/projects/-Users-liang-Downloads-Data-tmp-ccusage/884df067-8e69-4b03-8789-e2adfedcc5c9.jsonl"

let fileManager = FileManager.default
let now = Date()

print("\n1. CLAUDIA PROJECT (current session):")
if let attributes = try? fileManager.attributesOfItem(atPath: claudiaFile),
   let modDate = attributes[.modificationDate] as? Date {
    let minutesAgo = now.timeIntervalSince(modDate) / 60
    print("   Last modified: \(minutesAgo) minutes ago")
    print("   Modification time: \(modDate)")
}

print("\n2. CCUSAGE PROJECT:")
if let attributes = try? fileManager.attributesOfItem(atPath: ccusageFile),
   let modDate = attributes[.modificationDate] as? Date {
    let minutesAgo = now.timeIntervalSince(modDate) / 60
    print("   Last modified: \(minutesAgo) minutes ago")
    print("   Modification time: \(modDate)")
}

// Now test with LiveMonitor
print("\n3. LIVEMONITOR DETECTION (5-hour window):")
let monitor = LiveMonitor(config: LiveMonitorConfig(
    claudePaths: [NSHomeDirectory() + "/.claude"],
    sessionDurationHours: 5,
    tokenLimit: nil,
    refreshInterval: 2.0,
    order: .descending
))

if let activeBlock = monitor.getActiveBlock() {
    print("   ✅ Found active session")
    print("   Start time: \(activeBlock.startTime)")
    print("   Last entry: \(activeBlock.actualEndTime ?? Date())")
    print("   Cost: $\(activeBlock.costUSD)")
    print("   Is active: \(activeBlock.isActive)")
    
    // Try to determine which project
    let timeSinceStart = now.timeIntervalSince(activeBlock.startTime) / 3600
    print("   Hours since start: \(timeSinceStart)")
    
    if timeSinceStart > 3 {
        print("   ⚠️ This appears to be the ccusage project (started >3 hours ago)")
    } else {
        print("   This might be the claudia project")
    }
} else {
    print("   ❌ No active session found")
}

// Test with shorter window
print("\n4. LIVEMONITOR WITH 1-HOUR WINDOW:")
let shortMonitor = LiveMonitor(config: LiveMonitorConfig(
    claudePaths: [NSHomeDirectory() + "/.claude"],
    sessionDurationHours: 1,
    tokenLimit: nil,
    refreshInterval: 2.0,
    order: .descending
))

if let activeBlock = shortMonitor.getActiveBlock() {
    print("   ✅ Found active session")
    print("   Start time: \(activeBlock.startTime)")
    print("   Last entry: \(activeBlock.actualEndTime ?? Date())")
    print("   Cost: $\(activeBlock.costUSD)")
} else {
    print("   ❌ No active session found")
}

print("\n5. CHECKING ACTUAL CONTENTS:")
// Read last line from each file to see actual timestamps
if let claudiaContent = try? String(contentsOfFile: claudiaFile) {
    let lines = claudiaContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
    if let lastLine = lines.last,
       let data = lastLine.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let timestampMs = json["timestamp"] as? Double {
        let date = Date(timeIntervalSince1970: timestampMs / 1000)
        let minutesAgo = now.timeIntervalSince(date) / 60
        print("   Claudia last entry: \(minutesAgo) minutes ago at \(date)")
    }
}

if let ccusageContent = try? String(contentsOfFile: ccusageFile) {
    let lines = ccusageContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
    if let lastLine = lines.last,
       let data = lastLine.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let timestampMs = json["timestamp"] as? Double {
        let date = Date(timeIntervalSince1970: timestampMs / 1000)
        let minutesAgo = now.timeIntervalSince(date) / 60
        print("   CCUsage last entry: \(minutesAgo) minutes ago at \(date)")
    }
}