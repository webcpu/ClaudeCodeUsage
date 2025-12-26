import Foundation
import ClaudeCodeUsageKit

print("🚀 Claude Usage Dashboard - Real Data")
print(String(repeating: "=", count: 72))

// Use real data from ~/.claude/projects/
let claudePath = NSHomeDirectory() + "/.claude"
print("Using path: \(claudePath)")

let client = ClaudeUsageClient(dataSource: .localFiles(basePath: claudePath))
print("Client created")

Task {
    print("Inside Task")
    
    do {
        print("Fetching usage stats...")
        let stats = try await client.getUsageStats()
        print("Got stats: \(stats.totalSessions) sessions, $\(String(format: "%.2f", stats.totalCost))")
        
        if stats.totalSessions == 0 {
            print("\n⚠️  No usage data found in ~/.claude/projects/")
            print("    Make sure you have run Claude Code sessions that generated usage data.")
        } else {
            // Display formatted table
            print("\n┌────────────┬────────────────────┬─────────────┐")
            print("│ Date       │ Models             │  Cost (USD) │")
            print("├────────────┼────────────────────┼─────────────┤")
            
            for daily in stats.byDate.sorted(by: { $0.date < $1.date }) {
                let model = daily.modelsUsed.first?.components(separatedBy: "-").prefix(2).joined(separator: "-") ?? ""
                let modelStr = "- \(model)"
                
                print(String(format: "│ %-10s │ %-18s │    $%7.2f │",
                            daily.date,
                            modelStr,
                            daily.totalCost))
            }
            
            print("├────────────┼────────────────────┼─────────────┤")
            print(String(format: "│ %-10s │ %-18s │    $%7.2f │",
                        "TOTAL",
                        "",
                        stats.totalCost))
            print("└────────────┴────────────────────┴─────────────┘")
            
            print("\n📊 Summary Statistics:")
            print("  • Total Cost: $\(String(format: "%.2f", stats.totalCost))")
            print("  • Total Sessions: \(stats.totalSessions)")
            print("  • Total Tokens: \(stats.totalTokens)")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    print("Exiting...")
    exit(0)
}

print("Starting RunLoop...")
RunLoop.main.run()
