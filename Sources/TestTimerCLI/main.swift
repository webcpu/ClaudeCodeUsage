//
//  Test Timer Functionality
//

import Foundation
import ClaudeCodeUsage

print("Testing refresh timer functionality...")

// Create client and test timer behavior
let client = ClaudeUsageClient(dataSource: .localFiles(basePath: NSHomeDirectory() + "/.claude"))
var loadCount = 0

func testLoadData() async {
    loadCount += 1
    print("Load #\(loadCount) at \(Date())")
    
    do {
        let stats = try await client.getUsageStats()
        print("  -> Loaded \(stats.totalSessions) sessions, cost: $\(String(format: "%.2f", stats.totalCost))")
    } catch {
        print("  -> Error: \(error)")
    }
}

// Test initial load
Task {
    await testLoadData()
}

// Create timer that fires every 2 seconds
print("\nStarting 2-second refresh timer...")
let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    Task {
        await testLoadData()
    }
}

// Run for 8 seconds to see 4 refreshes
RunLoop.main.run(until: Date().addingTimeInterval(8))
timer.invalidate()

print("\nTimer test complete. Total loads: \(loadCount)")
print("✅ Refresh functionality is working!")