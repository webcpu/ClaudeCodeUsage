import Foundation
import ClaudeCodeUsage

print("🔍 Testing ClaudiaUsageSDK")
print(String(repeating: "=", count: 72))

// Use real data from ~/.claude/projects/
let claudePath = NSHomeDirectory() + "/.claude"
print("Using path: \(claudePath)")

let client = ClaudiaUsageClient(dataSource: .localFiles(basePath: claudePath))
print("Client created")

Task { @MainActor in
    print("Inside Task")
    
    do {
        print("Calling getUsageStats...")
        let stats = try await client.getUsageStats()
        print("Got stats: \(stats.totalSessions) sessions, $\(String(format: "%.2f", stats.totalCost))")
        
        if stats.totalSessions > 0 {
            print("\n✅ SUCCESS! Found real usage data:")
            print("  • Total Sessions: \(stats.totalSessions)")
            print("  • Total Cost: $\(String(format: "%.2f", stats.totalCost))")
            print("  • Days with data: \(stats.byDate.count)")
            
            // Show first day's data
            if let firstDay = stats.byDate.first {
                print("\n  First day: \(firstDay.date)")
                print("    Models: \(firstDay.modelsUsed.joined(separator: ", "))")
                print("    Cost: $\(String(format: "%.2f", firstDay.totalCost))")
            }
        } else {
            print("\n⚠️ No usage data found")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    print("Exiting...")
    exit(0)
}

print("Starting RunLoop...")
RunLoop.main.run()